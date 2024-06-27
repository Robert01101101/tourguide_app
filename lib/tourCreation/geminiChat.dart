import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'dart:io';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/locationProvider.dart';
import 'package:uuid/uuid.dart';
import 'package:tourguide_app/main.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer';

//_________________________________________________________________________ CREATE FORM
class GeminiChat extends StatefulWidget {
  const GeminiChat({super.key});

  @override
  State<GeminiChat> createState() => _GeminiChatState();
}

class _GeminiChatState extends State<GeminiChat> with WidgetsBindingObserver {
  var apiKey;
  String aiTourResponse = ''; // Variable to store the generated tour
  var uuid = Uuid();
  String geminiVersion = 'gemini-1.5-flash';
  types.User? _user, _bot;
  late ChatSession _chat;
  late GenerativeModel generativeModel;
  //CHAT from https://docs.flyer.chat/flutter/chat-ui/basic-usage
  final List<types.Message> _messages = [];
  //TODO: Set correct ID
  static String userId = '82091008-a484-4a89-ae75-a22bf8d6f3ac';
  static String geminiId = '82091008-a484-4a89-ae75-a22bf8d6f3ab';

  //do on page load
  @override
  void initState() {
    super.initState();

    //Register observer to detect app closed
    WidgetsBinding.instance.addObserver(this);

    // Access your API key as an environment variable (see "Set up your API key" above)
    // old approach with google_generative_ai
    /*const apiKeyStringFromEnv = String.fromEnvironment('API_KEY');
    final apiKeyFromPlatform = Platform.environment['API_KEY'];
    apiKey = apiKeyStringFromEnv ?? apiKeyFromPlatform;
    if (apiKey == null) {
      print('No \$API_KEY environment variable: apiKey=$apiKeyFromPlatform, apiKeyStringFromEnv=$apiKeyStringFromEnv');
      exit(1);
    }*/

    generativeModel = FirebaseVertexAI.instance.generativeModel(
        model: geminiVersion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_user == null) { // Check if already initialized to prevent multiple calls
      _user = types.User(
          id: userId,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
          firstName: FirebaseAuth.instance.currentUser!.displayName);
      _bot = types.User(
          id: geminiId,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
          firstName: 'AI Tourguide');

      _startNewChat();
    }
  }

  @override
  void dispose() {
    // Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  /// App detached (-> Clear messages)
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is detached (closed), clear the messages
      //_clearMessages();
    }
  }

  void _startNewChat(){
    // Initialize the chat
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    String initialPrompt = 'Please act as my friendly and knowledgeable tourguide, and respond in normal written English. Try to keep your response short unless I ask for detailed or longer responses. If I ask for an address, inform me that information like a specific address might be inaccurate.';
    if (locationProvider.currentCity != null){
      initialPrompt += " I am currently located in ${locationProvider.currentCity}, ${locationProvider.currentState}, ${locationProvider.currentCountry}";
    }
    print("geminiChat._startNewChat() - initialPrompt=$initialPrompt");

    _chat = generativeModel.startChat(history: [
      Content("user",Content.text(initialPrompt).parts),
      Content("model",Content.text("Okay, how can I help you?").parts)
    ]);
    _user = types.User(
        id: userId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        firstName: FirebaseAuth.instance.currentUser!.displayName);
    _bot = types.User(
        id: geminiId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        firstName: 'AI Tourguide');

    _loadMessages();
  }

  /// Clears messages from storage
  Future<void> _clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_messages');
    setState(() {
      _messages.clear();
    });
  }

  /// Saves messages so that when the user exits and returns to the screen, they don't disappear
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> messages = _messages.map((message) => jsonEncode(message.toJson())).toList();
    await prefs.setStringList('chat_messages', messages);
  }

  /// Loads saved messages so that when the user exits and returns to the screen, they don't disappear
  Future<void> _loadMessages() async {
    print("_loadMessages()");
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messages = prefs.getStringList('chat_messages');
    if (messages != null) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages.map((message) => types.Message.fromJson(jsonDecode(message))));
      });
    } else {
      print("_loadMessages() - init new");
      // Initialize with a welcome message if no messages are stored
      final m = types.TextMessage(
        author: _bot!,
        text: 'Hello ${FirebaseAuth.instance.currentUser!.displayName}, how can I help you today?',
        id: const Uuid().v4(),
        status: types.Status.delivered,
      );
      setState((){
        _messages.add(m);
        print("_loadMessages() - init new - set state ${m.text}");
      });

    }
  }

  /// Prompts Gemini for a response in a chat based system
  void _promptGemini(String message) async {
    // The Gemini 1.5 models are versatile and work with most use cases
    final content = Content.text(message);
    try {
      final response = await _chat.sendMessage(content);
      debugPrint(response.text!);

      setState(() {
        _handleGeminiResponse(_cleanUpAiResponseString(response.text!));
      });
    } catch (e) {
      setState(() {
        _handleGeminiResponse("Sorry, an error occurred. Try rephrasing your message.");
        print(e);
      });
    }

  }

  //TODO fix
  String _cleanUpAiResponseString(String responseString){
    return responseString.replaceAll("**", "*"); //for correct bolding of text
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Options'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text("Powered by Google's $geminiVersion \n\nAI Tourguide might provide inaccurate information, use with care.")),
                ),
                ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Clear Chat History'),
                  onTap: () async {
                    await _clearMessages();
                    Navigator.of(context).pop();
                    _startNewChat();
                  },
                ),
                // Add more options here if needed
              ],
            ),
          ),
        );
      },
    );
  }

  /// Add a [message] to the chat history.
  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
    _saveMessages();
  }

  /// Submits the [message] written by the user to the chat history and prompts Gemini.
  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: uuid.v4(),
      text: message.text,
    );

    _addMessage(textMessage);
    _promptGemini(message.text);
  }

  /// Submits the response [message] written by Gemini to the chat history .
  void _handleGeminiResponse(String responseMessage){
    final textMessage = types.TextMessage(
      author: _bot!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: uuid.v4(),
      text: responseMessage,
    );

    _addMessage(textMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gemini Chat'),
          actions: [
            IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
              _showOptionsDialog(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Chat(
          messages: _messages,
          onSendPressed: _handleSendPressed,
          user: _user!,
          theme: const DefaultChatTheme(
            primaryColor: Color(0xffec8c6f),
          ),
        ),
      ),
    );
  }
}