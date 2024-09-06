import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tourguide_app/utilities/services/tts_service.dart';

import '../main.dart';

class TtsText extends StatefulWidget {
  final String text;
  final TtsService ttsService;
  final int index;
  final bool currentlyPlayingItem;

  const TtsText({
    Key? key,
    required this.text,
    required this.ttsService,
    required this.index,
    required this.currentlyPlayingItem,
  }) : super(key: key);

  @override
  _TtsTextState createState() => _TtsTextState();
}

class _TtsTextState extends State<TtsText> {
  //List<Map<String, dynamic>> wordOffsets = [];
  //int currentWordIndex = -1;
  int startOffset = 0;
  int endOffset = 0;
  late final StreamSubscription<Map<String, dynamic>> _progressSubscription;

  @override
  void initState() {
    super.initState();

    // Subscribe to the TTS progress stream
    _progressSubscription = widget.ttsService.progressStream.listen((progressData) {
      if (!widget.currentlyPlayingItem) {
        if (startOffset != 0 || endOffset != 0) resetTtsViz();
        return;
      }

      setState(() {
        startOffset = progressData['startOffset'];
        endOffset = progressData['endOffset'];
      });
    });
  }

  resetTtsViz(){
    logger.i('Resetting TTS visualization');
    setState(() {
      startOffset = 0;
      endOffset = 0;
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel(); // Clean up subscription when widget is destroyed
    super.dispose();
  }

  // Calculate start and end offsets for each word
  /*void _calculateWordOffsets(String text) {
    wordOffsets.clear();
    int offset = 0;
    text.split(' ').forEach((word) {
      final start = offset;
      final end = offset + word.length;
      wordOffsets.add({
        'word': word,
        'start': start,
        'end': end,
      });
      offset = end + 1; // Account for the space after each word
    });
  }

  // Get the index of the current word based on the TTS offsets
  int _getWordIndexFromOffsets(int startOffset, int endOffset) {
    return wordOffsets.indexWhere((entry) => entry['start'] == startOffset && entry['end'] == endOffset);
  }

  // Restart TTS from the tapped word
  void _onWordTapped(int tappedIndex) {
    String newText = wordOffsets.sublist(tappedIndex).map((e) => e['word']).join(' ');
    widget.ttsService.speak(newText);
  }

  // Detect the word tapped by the user (requires more complex detection logic)
  int _detectWordTapped(Offset tapPosition) {
    // Here you can use TextPainter to calculate the tapped position more accurately.
    // For now, it's a placeholder returning -1.
    return -1; // Replace with actual detection logic based on tapPosition
  }
  */

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        logger.t('Tapped at ${details.localPosition}');
        // Handle tap, if necessary
      },
      child: RichText(
        text: TextSpan(
          children: _buildTextSpans(widget.text, startOffset, endOffset),
        ),
      ),
    );
  }

  // Build text spans based on the current TTS progress (startOffset and endOffset)
  List<TextSpan> _buildTextSpans(String text, int startOffset, int endOffset) {
    //logger.t('Building text spans: $text, startOffset=$startOffset, endOffset=$endOffset');
    List<TextSpan> spans = [];

    if (startOffset > 0) {
      // Add the part of the text before the currently spoken word
      spans.add(
        TextSpan(
          text: text.substring(0, startOffset),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    // Add the currently spoken word
    spans.add(
      TextSpan(
        text: text.substring(startOffset, endOffset),
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Add the rest of the text after the currently spoken word
    if (endOffset < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(endOffset),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return spans;
  }
}
