// lib/screens/Multimedia/OfflineTtsScreen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../controller/mediaController.dart';

class OfflineTtsScreen extends ConsumerStatefulWidget {
  const OfflineTtsScreen({super.key});

  @override
  ConsumerState<OfflineTtsScreen> createState() => _OfflineTtsScreenState();
}

class _OfflineTtsScreenState extends ConsumerState<OfflineTtsScreen> {
  final FlutterTts _tts = FlutterTts();

  final TextEditingController _textController = TextEditingController();

  final TextEditingController _titleController = TextEditingController(
    text: 'Generated speech',
  );

  double _rate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  bool _busy = false;

  String? _language;
  List<String> _languages = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.awaitSynthCompletion(true);

      final dynamic rawLanguages = await _tts.getLanguages;

      final List<String> languages;

      if (rawLanguages is List) {
        languages = rawLanguages
            .map((item) => item.toString())
            .where((language) => language.trim().isNotEmpty)
            .toSet()
            .toList();

        languages.sort();
      } else {
        languages = <String>[];
      }

      final String? defaultLanguage;

      if (languages.contains('en-US')) {
        defaultLanguage = 'en-US';
      } else if (languages.isNotEmpty) {
        defaultLanguage = languages.first;
      } else {
        defaultLanguage = null;
      }

      if (defaultLanguage != null) {
        await _tts.setLanguage(defaultLanguage);
      }

      if (!mounted) return;

      setState(() {
        _languages = languages;
        _language = defaultLanguage;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _languages = const [];
        _language = null;
      });

      _message(
        'Could not load installed TTS languages: $error',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: const Text('Offline text to speech'),
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Speech uses a voice engine already installed on the device. '
              'No text is uploaded by this feature.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Audio title',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 7,
            maxLines: 15,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Text to speak',
              alignLabelWithHint: true,
              hintText: 'Type or paste text here…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_languages.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(
                labelText: 'Installed language',
                prefixIcon: Icon(Icons.language),
              ),
              items: _languages
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) async {
                      if (value == null) return;

                      await _tts.setLanguage(value);

                      if (!mounted) return;

                      setState(() {
                        _language = value;
                      });
                    },
            ),
          const SizedBox(height: 18),
          _SliderSetting(
            label: 'Speech rate',
            value: _rate,
            min: 0.2,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _rate = value;
              });
            },
          ),
          _SliderSetting(
            label: 'Pitch',
            value: _pitch,
            min: 0.5,
            max: 2.0,
            onChanged: (value) {
              setState(() {
                _pitch = value;
              });
            },
          ),
          _SliderSetting(
            label: 'Volume',
            value: _volume,
            min: 0.0,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _volume = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _speak,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _saveAudio,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_alt),
            label: Text(
              _busy ? 'Generating…' : 'Generate and save to history',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applySettings() async {
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);

    final language = _language;

    if (language != null && language.isNotEmpty) {
      await _tts.setLanguage(language);
    }
  }

  Future<void> _speak() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      _message('Enter text first.');
      return;
    }

    try {
      await _tts.stop();
      await _applySettings();
      await _tts.speak(text);
    } catch (error) {
      if (!mounted) return;

      _message(
        'Could not play speech: $error',
        isError: true,
      );
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
  }

  Future<void> _saveAudio() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      _message('Enter text first.');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _tts.stop();
      await _applySettings();

      final extension = Platform.isIOS || Platform.isMacOS ? 'caf' : 'wav';

      final provisional = await ref
          .read(mediaStorageServiceProvider)
          .createTtsOutput(extension: extension);

      final dynamic result = await _tts.synthesizeToFile(
        text,
        provisional.path,
        true,
      );

      final generated = File(provisional.path);

      final fileExists = await generated.exists();
      final fileLength = fileExists ? await generated.length() : 0;

      final generationSucceeded =
          result == 1 || result == true || result?.toString() == '1';

      if (!generationSucceeded || !fileExists || fileLength == 0) {
        throw StateError(
          'The installed TTS engine did not create an audio file. '
          'Try another installed voice or language.',
        );
      }

      final enteredTitle = _titleController.text.trim();

      await ref.read(mediaServiceProvider).addGeneratedAudio(
            file: generated,
            title: enteredTitle.isEmpty ? 'Generated speech' : enteredTitle,
          );

      refreshMediaLibrary(ref);

      if (!mounted) return;

      _message(
        'Speech audio saved in the media library and history.',
      );
    } catch (error) {
      if (!mounted) return;

      _message(
        'Could not generate audio: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _message(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
          ),
        ),
      ],
    );
  }
}
