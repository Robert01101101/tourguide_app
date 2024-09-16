import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tourguide_app/utilities/services/tts_service.dart';

import '../main.dart';

class TtsText extends StatefulWidget {
  final String text;
  final TtsService ttsService;
  final bool currentlyPlayingItem;
  /// Callback function to be called when a word is tapped, returns remaining section (word plus text after)
  final void Function(String tappedWord)? onWordTapped;

  const TtsText({
    Key? key,
    required this.text,
    required this.ttsService,
    required this.currentlyPlayingItem,
    this.onWordTapped,
  }) : super(key: key);

  @override
  _TtsTextState createState() => _TtsTextState();
}

class _TtsTextState extends State<TtsText> {
  int startOffset = 0;
  int endOffset = 0;
  int tappedStringCharacterOffset = 0;
  final GlobalKey _richTextKey = GlobalKey();
  late final StreamSubscription<Map<String, dynamic>> _progressSubscription;
  StreamSubscription<TtsState>? _ttsSubscription;
  bool _ignoreStopEvent = false; //rly scrappy solution TODO: better fix

  @override
  void initState() {
    super.initState();

    _progressSubscription = widget.ttsService.progressStream.listen((progressData) {
      if (!widget.currentlyPlayingItem) {
        if (startOffset != 0 || endOffset != 0 || tappedStringCharacterOffset != 0) resetTtsViz();
        return;
      }

      setState(() {
        startOffset = progressData['startOffset'];
        endOffset = progressData['endOffset'];
      });
    });
    //Listen to tts state changes
    _ttsSubscription = widget.ttsService.ttsStateStream.listen((TtsState state) {
      if (_ignoreStopEvent) {
        _ignoreStopEvent = false;
        return;
      }
      if (state == TtsState.stopped) {
        resetTtsViz();
      }
    });
  }

  resetTtsViz() {
    logger.t('resetTtsViz()');
    setState(() {
      startOffset = 0;
      endOffset = 0;
      tappedStringCharacterOffset = 0;
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    _ttsSubscription?.cancel();
    super.dispose();
  }

  void _detectWordTapped(Offset tapPosition) {
    if (widget.onWordTapped == null) return;
    final renderBox = _richTextKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(tapPosition);

    final textPainter = _getTextPainter();
    textPainter.layout(maxWidth: renderBox.size.width);

    final textOffset = textPainter.getPositionForOffset(localPosition);
    final wordRange = _getWordBoundary(textPainter, textOffset);

    if (wordRange != null) {
      int fixedWordRangeStart = wordRange.start;
      while (fixedWordRangeStart > 0 && !RegExp(r'\s|,|\.|\n').hasMatch(widget.text[fixedWordRangeStart - 1])) {
        fixedWordRangeStart--;
      }
      tappedStringCharacterOffset = fixedWordRangeStart;
      final tappedWord = widget.text.substring(fixedWordRangeStart, wordRange.end);
      final remainingSubstring = widget.text.substring(fixedWordRangeStart,  widget.text.length-1);
      logger.t('Tapped word: $tappedWord\n remainingSubstring: $remainingSubstring');

      _ignoreStopEvent = true;
      widget.onWordTapped!(remainingSubstring);
    }
  }

  TextPainter _getTextPainter() {
    return TextPainter(
      text: TextSpan(
        text: widget.text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      textDirection: TextDirection.ltr,
    );
  }

  TextRange? _getWordBoundary(TextPainter textPainter, TextPosition position) {
    final text = widget.text;
    final startOffset = position.offset;
    final endOffset = text.indexOf(' ', startOffset);
    final endRange = endOffset == -1 ? text.length : endOffset;
    return TextRange(start: startOffset, end: endRange);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentlyPlayingItem) {
      startOffset = 0;
      endOffset = 0;
    }

    return MouseRegion(
      cursor: widget.currentlyPlayingItem ? SystemMouseCursors.click : SystemMouseCursors.text,
      child: GestureDetector(
        onTapUp: (details) {
          if (widget.currentlyPlayingItem) _detectWordTapped(details.globalPosition);
        },
        child: Container(
          key: _richTextKey,
          child: Text.rich(
                  softWrap: true,
                  TextSpan(
                    children:  _buildTextSpans(widget.text, startOffset + tappedStringCharacterOffset, endOffset + tappedStringCharacterOffset)
                  )
                )
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, int startOffset, int endOffset) {
    List<TextSpan> spans = [];
    if (startOffset > 0) startOffset--;
    if (endOffset < text.length - 1 && endOffset > 0) endOffset++;

    if (startOffset > 0) {
      spans.add(
        TextSpan(
          text: text.substring(0, startOffset),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(startOffset, endOffset),
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w900,
          background: Paint()..color = Theme.of(context).colorScheme.tertiaryContainer,
        ),
      ),
    );

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
