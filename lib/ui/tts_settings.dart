import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tourguide_app/ui/tts_text.dart';
import 'package:tourguide_app/utilities/services/tts_service.dart';

import '../main.dart';

class TtsSettings extends StatefulWidget {
  const TtsSettings({super.key});

  @override
  State<TtsSettings> createState() => _TtsSettingsState();
}

class _TtsSettingsState extends State<TtsSettings> {
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsState>? _ttsSubscription;
  bool _currentlyPlaying = false;

  @override
  void initState() {
    super.initState();

    //Listen to tts state changes
    _ttsSubscription = _ttsService.ttsStateStream.listen((TtsState state) {
      if (state == TtsState.stopped) {
        setState(() {
          _currentlyPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _ttsSubscription?.cancel();
    super.dispose();
  }

  Widget _languageDropDownSection(List<dynamic> languages) => Container(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
          children: [
        ValueListenableBuilder<String?>(
        valueListenable: _ttsService.languageNotifier,
        builder: (context, language, child) {
          logger.t('TtsSettings._languageDropDownSection() - language=$language');
          return DropdownMenu<String>(
            initialSelection: language ?? languages.first,
            dropdownMenuEntries: getLanguageDropDownMenuItems(languages),
            onSelected: changedLanguageDropDownItem,
          );
        }),
      ]));

  List<DropdownMenuEntry<String>> getLanguageDropDownMenuItems(
      List<dynamic> languages) {
    var items = <DropdownMenuEntry<String>>[];
    for (dynamic type in languages) {
      items.add(DropdownMenuEntry(
          value: type, label: type));
    }
    return items;
  }


  void changedLanguageDropDownItem(String? selectedType) {
    setState(() {
      if (_currentlyPlaying) _ttsService.stop();
      _ttsService.setLanguage(selectedType!);
    });
  }


  void _toggleTTS(String description) {
    if (_currentlyPlaying) {
      _ttsService.stop(); // Stop the TTS service if the same button is pressed
      setState(() {
        _currentlyPlaying = false; // Reset the index
      });
    } else {
      _ttsService.speak(description); // Start speaking
      setState(() {
        _currentlyPlaying = true; // Set the currently playing index
      });
    }
  }

  openTtsSettings() async{
    AndroidIntent intent = const AndroidIntent(
      action: 'com.android.settings.TTS_SETTINGS',
    );
    await intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TtsText(text: "Text to Speech is provided by your device.", ttsService: _ttsService, currentlyPlayingItem: _currentlyPlaying),
            IconButton(
              onPressed: () => _toggleTTS("Text to Speech is provided by your device."),
              icon: Icon(_currentlyPlaying ? Icons.stop : Icons.play_circle),
            ),
          ],
        ),
        SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Voice", style: Theme.of(context).textTheme.titleSmall),
                FutureBuilder<dynamic>(
                    future: _ttsService.getLanguages(),
                    builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                      if (snapshot.hasData) {
                        return _languageDropDownSection(snapshot.data as List<dynamic>);
                      } else if (snapshot.hasError) {
                        return Text('Error loading languages...');
                      } else
                        return Text('Loading Languages...');
                    }),
                ValueListenableBuilder<bool>(
                  valueListenable: _ttsService.isCurrentLanguageInstalledNotifier,
                  builder: (context, isInstalled, child) {
                    return Visibility(
                      visible: (_ttsService.isAndroid && !isInstalled),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 4.0),
                            Icon(Icons.error, size: 16.0, color: Theme.of(context).colorScheme.error),
                            SizedBox(width: 4.0),
                            Text("Not installed", style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
            SizedBox(width: 16.0),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Speed", style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: 14.0),
                ValueListenableBuilder<double>(
                    valueListenable: _ttsService.rateNotifier,
                    builder: (context, rate, child) {
                    return Slider(
                      value: rate,
                      onChanged: (newRate) {
                        if (_currentlyPlaying) _ttsService.stop();
                        setState(() => _ttsService.setRate(newRate));
                      },
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: "${rate}",
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  }
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16.0),
        Wrap(
          children: [
            if (!kIsWeb)
            ElevatedButton.icon(
              onPressed: openTtsSettings,
              label: const Text('Open System TTS Settings'),
              icon: const Icon(Icons.settings, size: 20,),
            ),
            ValueListenableBuilder<bool>(
                valueListenable: _ttsService.hasSavedSettings,
                builder: (context, hasSavedSettings, child) {
                return Visibility(
                  visible: hasSavedSettings,
                  child: ElevatedButton.icon(
                    onPressed: _ttsService.clearSettings,
                    label: const Text('Clear App TTS Preferences'),
                    icon: const Icon(Icons.restart_alt, size: 20,),
                  ),
                );
              }
            ),
          ],
        ),
      ],
    );
  }
}
