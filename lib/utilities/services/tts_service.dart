import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

enum TtsState { playing, stopped, paused, continued }

class TtsService {
  //Singleton
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal() {
    _initTts();
  }

  //Flutter TTS
  final FlutterTts _flutterTts = FlutterTts();
  String? _newVoiceText;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.6;
  TtsState _ttsState = TtsState.stopped;
  TtsState get ttsState => _ttsState;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  //for listeners
  final StreamController<Map<String, dynamic>> _progressController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  final StreamController<TtsState> _ttsStateController =
      StreamController<TtsState>.broadcast();
  Stream<TtsState> get ttsStateStream => _ttsStateController.stream;
  ValueNotifier<bool> isCurrentLanguageInstalledNotifier =
      ValueNotifier<bool>(false);
  bool get isCurrentLanguageInstalled =>
      isCurrentLanguageInstalledNotifier.value;
  ValueNotifier<String?> languageNotifier = ValueNotifier<String?>(null);
  ValueNotifier<double> rateNotifier = ValueNotifier<double>(0.6);
  ValueNotifier<bool> hasSavedSettings = ValueNotifier<bool>(false);

  void _initTts() async {
    await _getDefaultVoice();
    await _loadSettings();

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      _ttsStateController.add(_ttsState);
    });

    _flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      //logger.t("Progress: $text, $startOffset, $endOffset, $word");
      _progressController.add({
        'text': text,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'word': word,
      });
    });

    if (kIsWeb) setRate(0.9);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('tts_rate')) {
      rate = prefs.getDouble('tts_rate')!;
      _flutterTts.setSpeechRate(rate);
      rateNotifier.value = rate;
      hasSavedSettings.value = true;
    }
    if (prefs.containsKey('tts_language')) {
      languageNotifier.value = prefs.getString('tts_language')!;
      logger.t("Language from prefs: ${languageNotifier.value}");
      hasSavedSettings.value = true;
      setLanguage(languageNotifier.value!, saveSettings: false);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('tts_rate', rate);
    if (languageNotifier != null && languageNotifier.value != null)
      prefs.setString('tts_language', languageNotifier.value!);
    hasSavedSettings.value = true;
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('tts_rate');
    prefs.remove('tts_language');
    hasSavedSettings.value = false;
    await _getDefaultVoice();
    double newRate = kIsWeb ? 0.9 : 0.6;
    rate = newRate;
    _flutterTts.setSpeechRate(rate);
    rateNotifier.value = rate;
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

  void dispose() {
    stop();
    _progressController.close();
    _ttsStateController.close();
  }

  // ----

  Future<void> _getDefaultVoice() async {
    if (isAndroid) {
      var voice = await _flutterTts.getDefaultVoice;
      if (voice != null) {
        //logger.t(voice);
        languageNotifier.value = voice['locale'];
        isCurrentLanguageInstalledNotifier.value =
            await _flutterTts.isLanguageInstalled(languageNotifier.value!);
        setLanguage(languageNotifier.value!, saveSettings: false);
      }
    } else {
      var defaultLanguages = await getLanguages();
      var defaultLanguageVoice = defaultLanguages[0] as String;
      logger.t(defaultLanguageVoice);
      languageNotifier.value = defaultLanguageVoice;
      setLanguage(languageNotifier.value!, saveSettings: false);
    }
  }

  void setLanguage(String selectedLanguage, {bool saveSettings = true}) {
    languageNotifier.value = selectedLanguage;
    _flutterTts.setLanguage(languageNotifier.value!);
    if (isAndroid) {
      _flutterTts.isLanguageInstalled(languageNotifier.value!).then((value) {
        isCurrentLanguageInstalledNotifier.value = (value as bool);
        logger.t(
            "Is language installed: $isCurrentLanguageInstalled, isCurrentLanguageInstalled=$isCurrentLanguageInstalled");
      });
    }
    if (saveSettings) _saveSettings();
  }

  void setRate(double newRate) {
    rate = newRate;
    _flutterTts.setSpeechRate(rate);
    rateNotifier.value = rate;
    _saveSettings();
  }

  Future<dynamic> getLanguages() async => await _flutterTts.getLanguages;
}
