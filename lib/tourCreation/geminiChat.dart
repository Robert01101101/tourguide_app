import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/uiElements/CityAutocomplete.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'package:tourguide_app/main.dart';

//_________________________________________________________________________ CREATE FORM
class GeminiChat extends StatefulWidget {
  const GeminiChat({super.key});

  @override
  State<GeminiChat> createState() => _GeminiChatState();
}

class _GeminiChatState extends State<GeminiChat> {
  var apiKey;
  String aiTourResponse = ''; // Variable to store the generated tour

  //do on page load
  @override
  void initState() {
    super.initState();

    // Access your API key as an environment variable (see "Set up your API key" above)
    const apiKeyStringFromEnv = String.fromEnvironment('API_KEY');
    final apiKeyFromPlatform = Platform.environment['API_KEY'];
    apiKey = apiKeyStringFromEnv ?? apiKeyFromPlatform;
    if (apiKey == null) {
      print('No \$API_KEY environment variable: apiKey=$apiKeyFromPlatform, apiKeyStringFromEnv=$apiKeyStringFromEnv');
      exit(1);
    }

    geminiMagicStuff();
  }

  void geminiMagicStuff() async {
    // The Gemini 1.5 models are versatile and work with most use cases
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final content = [Content.text('Please act as my tourguide. I want to do a tour of Vancouver downtown, lead me along a route that geographically makes sense and is easy to walk or use public transport along, and leads me by some of the best tourist attractions here.')];
    final response = await model.generateContent(content);
    setState(() {
      aiTourResponse = response.text!; // Update the story variable with the response text
    });
  }


  //________________________________________________________________________________________ MapSample StatefulWidget - BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gemini Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: geminiMagicStuff, // Trigger the function on button press
              child: Text('Generate Tour for Vancouver Downtown'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  aiTourResponse,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}