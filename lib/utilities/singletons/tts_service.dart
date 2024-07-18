import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class TtsService {
  static final TtsService _instance = TtsService._internal();

  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  String? _newVoiceText;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;

  TtsService._internal() {
    _initTts();
  }

  TtsState get ttsState => _ttsState;

  bool get isPlaying => _ttsState == TtsState.playing;
  bool get isStopped => _ttsState == TtsState.stopped;
  bool get isPaused => _ttsState == TtsState.paused;
  bool get isContinued => _ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
    });
  }

  Future<void> speak(String text) async {
    _newVoiceText = text;
    await _flutterTts.setVolume(volume);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    if (_newVoiceText != null && _newVoiceText!.isNotEmpty) {
      await _flutterTts.speak(_newVoiceText!);
    }
  }

  Future<void> stop() async {
    var result = await _flutterTts.stop();
    if (result == 1) _ttsState = TtsState.stopped;
  }

  Future<void> pause() async {
    var result = await _flutterTts.pause();
    if (result == 1) _ttsState = TtsState.paused;
  }
}
