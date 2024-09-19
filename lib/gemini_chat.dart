import 'package:bubble/bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chatUI;
import 'dart:io';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
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

    MyGlobals.webRoutingFix(TourguideNavigation.geminiChatPath);

    //Register observer to detect app closed
    WidgetsBinding.instance.addObserver(this);

    generativeModel =
        FirebaseVertexAI.instance.generativeModel(model: geminiVersion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_user == null) {
      // Check if already initialized to prevent multiple calls
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

  void _startNewChat() {
    // Initialize the chat
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    String initialPrompt =
        'Please act as my friendly and knowledgeable tour guide, and respond in normal written English. Your name is AI Tourguide. Try to keep your response short unless I ask for detailed or longer responses, and avoid asking clarifying questions unless my question is extremely broad or requires clarification. If I ask for an address, inform me that information like a specific address might be inaccurate. If I ask for the location of something, say where you think it is, but suggest to confirm the location in Google Maps, and that your stated location might be inaccurate. Don\'t be shy to remind me of your limitations.';
    if (locationProvider.currentCity != null) {
      initialPrompt +=
          " I am currently located in ${locationProvider.currentCity}, ${locationProvider.currentState}, ${locationProvider.currentCountry}";
    }
    logger.t("geminiChat._startNewChat() - initialPrompt=$initialPrompt");

    _chat = generativeModel.startChat(history: [
      Content("user", Content.text(initialPrompt).parts),
      Content("model", Content.text("Okay, how can I help you?").parts)
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
    final List<String> messages =
        _messages.map((message) => jsonEncode(message.toJson())).toList();
    await prefs.setStringList('chat_messages', messages);
  }

  /// Loads saved messages so that when the user exits and returns to the screen, they don't disappear
  Future<void> _loadMessages() async {
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    logger.t("_loadMessages()");
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messages = prefs.getStringList('chat_messages');
    if (messages != null) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages
            .map((message) => types.Message.fromJson(jsonDecode(message))));
      });
    } else {
      logger.t("_loadMessages() - init new");
      // Initialize with a welcome message if no messages are stored
      final m = types.TextMessage(
        author: _bot!,
        text: userProvider.user?.displayName != null ? 'Hi ${userProvider.user?.displayName}, how can I help you today?' : 'Hi there, how can I help you today?',
        id: const Uuid().v4(),
        status: types.Status.delivered,
      );
      final mCustom = types.TextMessage(
          author: _user!,
          text: 'Scenic local tours',
          id: const Uuid().v4(),
          status: types.Status.delivered,
          metadata: const {'aiCustomPrompt': 'true', 'prompt': 'tours'},
          showStatus: false);
      final mCustom2 = types.TextMessage(
          author: _user!,
          text: 'Popular nearby parks',
          id: const Uuid().v4(),
          status: types.Status.delivered,
          metadata: const {'aiCustomPrompt': 'true', 'prompt': 'parks'},
          showStatus: false);
      final mCustom3 = types.TextMessage(
          author: _user!,
          text: 'Best spots in the city',
          id: const Uuid().v4(),
          status: types.Status.delivered,
          metadata: const {'aiCustomPrompt': 'true', 'prompt': 'city'},
          showStatus: false);
      setState(() {
        _messages.add(mCustom2);
        _messages.add(mCustom3);
        _messages.add(mCustom);
        _messages.add(m);
        logger.t("_loadMessages() - init new - set state ${m.text}");
      });
    }
  }

  /// Prompts Gemini for a response in a chat based system
  void _promptGemini(String message) async {
    // The Gemini 1.5 models are versatile and work with most use cases
    final content = Content.text(message);
    try {
      final response = await _chat.sendMessage(content);
      logger.t(response.text!);

      setState(() {
        _handleGeminiResponse(_cleanUpAiResponseString(response.text!));
      });
    } catch (e) {
      setState(() {
        _handleGeminiResponse(
            "Sorry, an error occurred. Try rephrasing your message.");
        logger.t(e);
      });
    }
  }

  //TODO fix
  String _cleanUpAiResponseString(String responseString) {
    String cleanedUpString = responseString
        .replaceAll("* **", "*")
        .replaceAll("**", "*")
        .trimRight();
    //correctly bold text (** -> * and special case for lists)
    //trim empty spaces at the end such as newline chars
    logger.t("cleanedUpString: $cleanedUpString");
    return cleanedUpString;
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
                  child: Center(
                      child: Text(
                          "Powered by Google's $geminiVersion.\n\nAI Tourguide might provide inaccurate information, use with care.")),
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Clear Chat History'),
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
    _handleSendPrompt(message.text);
  }

  void _handleSendPrompt(String prompt) {
    final textMessage = types.TextMessage(
        author: _user!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: uuid.v4(),
        text: prompt,
        status: types.Status.sending);

    _addMessage(textMessage);
    _promptGemini(prompt);
  }

  /// Submits the response [message] written by Gemini to the chat history .
  void _handleGeminiResponse(String responseMessage) {
    final textMessage = types.TextMessage(
      author: _bot!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: uuid.v4(),
      text: responseMessage,
    );

    for (var i = 0; i < _messages.length; i++) {
      _messages[i] = _messages[i].copyWith(status: types.Status.delivered);
    }
    _addMessage(textMessage);
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding =
        (kIsWeb && MediaQuery.of(context).size.width > 1280)
            ? MediaQuery.of(context).size.width / 5
            : 10;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Tourguide'),
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
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
        child: Chat(
          messages: _messages,
          onSendPressed: _handleSendPressed,
          user: _user!,
          theme: DefaultChatTheme(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            primaryColor: Theme.of(context).colorScheme.secondary,
            inputBackgroundColor: Color(0xff434949),
            //border radius 5 up 20 down
            inputBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(5),
            ),
          ),
          bubbleBuilder: _customBubbleBuilder,
          textMessageBuilder: _textMessageBuilder,
          scrollController: MyGlobals.scrollController,
        ),
      ),
    );
  }

  static const Radius radiusMessage = Radius.circular(20);

  /// Build bubble message widget
  Widget _customBubbleBuilder(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  }) {
    bool isUser = message.author.id == _user?.id;
    bool isAiCustomPrompt = message.metadata != null &&
        message.metadata!.isNotEmpty &&
        message.metadata!.containsKey("aiCustomPrompt");

    return isAiCustomPrompt
        ? Center(
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(36)),
                  color: Theme.of(context).colorScheme.secondary,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ElevatedButton(
                    onPressed: () {
                      //check if text in metadata contains "tour"
                      //log all metadata
                      logger.i("metadata: ${message.metadata}");
                      if (message.metadata!["prompt"] == "tours") {
                        _handleSendPrompt(
                            "What's a nice scenic local tour I can take?");
                      } else if (message.metadata!["prompt"] == "parks") {
                        _handleSendPrompt(
                            "What are the 5 most popular parks around here? I want a day out in nature!");
                      } else if (message.metadata!["prompt"] == "city") {
                        _handleSendPrompt(
                            "What are the best 5 urban spots around here? I want to explore the city!");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.lightbulb,
                          size: 24.0,
                        ),
                        IgnorePointer(
                          child: child,
                        ), //IgnorePointer ensures clicks pass through to button behind it
                      ],
                    ),
                  ),
                )),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: (isUser)
                  ? const BorderRadius.only(
                      topLeft: radiusMessage,
                      topRight: radiusMessage,
                      bottomLeft: radiusMessage,
                    )
                  : const BorderRadius.only(
                      topLeft: radiusMessage,
                      topRight: radiusMessage,
                      bottomRight: radiusMessage,
                    ),
              color: isUser
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: child);
  }

  Widget _textMessageBuilder(
    types.TextMessage textMessage, {
    required int messageWidth,
    required bool showName,
  }) {
    bool isAiCustomPrompt = textMessage.metadata != null &&
        textMessage.metadata!.isNotEmpty &&
        textMessage.metadata!.containsKey("aiCustomPrompt");

    return Container(
      padding: isAiCustomPrompt
          ? EdgeInsets.all(16)
          : EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: SelectableText.rich(
        TextSpan(
          children: _parseTextWithMarkdown(textMessage.text),
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: isAiCustomPrompt
                    ? Theme.of(context).colorScheme.primary
                    : textMessage.author.id == _user!.id
                        ? Theme.of(context).colorScheme.onSecondary
                        : Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
        ),
      ),
    );
  }

  List<TextSpan> _parseTextWithMarkdown(String text) {
    final boldRegex = RegExp(r'\*(.*?)\*');
    final spans = <TextSpan>[];

    int start = 0;
    for (final match in boldRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
          text: match.group(1), style: TextStyle(fontWeight: FontWeight.bold)));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  /// Build retry widget.
  Widget _customRetryBuilder() {
    return IconButton(
      onPressed: () {
        //_handleRetry();
      },
      icon: const Icon(
        Icons.refresh,
      ),
      iconSize: 25,
    );
  }
}
