import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/ai_settings_store.dart';
import '../settings/ai_preferences.dart';
import 'speech_provider.dart';
import 'speech_models.dart';

class VoiceInputDialog extends StatefulWidget {
  const VoiceInputDialog({super.key, required this.settings});
  final AiSettingsStore settings;
  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog> {
  final _recorder = AudioRecorder();
  final _text = TextEditingController();
  final _model = TextEditingController(text: 'whisper-1');
  StreamSubscription<Amplitude>? _amplitude;
  Timer? _limit;
  String _language = '', _provider = 'offline', _directory = '';
  String? _path, _status;
  bool _recording = false, _busy = false, _installed = false;
  double _level = 0;
  SharedPreferences? _prefs;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final root = await getApplicationSupportDirectory();
    final directory = '${root.path}/ai_speech/whisper';
    final installed = await SpeechModels(Directory(directory)).installed;
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _directory = directory;
      _installed = installed;
      _language = prefs.getString('ai.voice.language') ?? '';
      final id = prefs.getString('ai.voice.provider') ?? 'offline';
      _provider = _profiles.any((p) => p.id == id) ? id : 'offline';
      _model.text = prefs.getString('ai.voice.model') ?? 'whisper-1';
    });
  }

  List<AiProviderProfile> get _profiles => widget.settings
      .load()
      .profiles
      .where(
        (p) =>
            p.kind == AiProviderKind.openai ||
            p.kind == AiProviderKind.compatible,
      )
      .toList();
  Future<void> _install() async {
    setState(() {
      _busy = true;
      _status =
          'Select a JSON model manifest with HTTPS URLs and SHA-256 checksums.';
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked.isEmpty) return;
      final manifest = jsonDecode(
        utf8.decode(await picked.single.readAsBytes()),
      ) as Map<String, dynamic>;
      await SpeechModels(Directory(_directory)).install(
        manifest.map(
          (name, value) => MapEntry(name, (
            url: Uri.parse(value['url'] as String),
            sha256: value['sha256'] as String,
          )),
        ),
      );
      if (mounted) {
        setState(() {
          _installed = true;
          _status = 'Whisper model installed.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Model installation failed. Check the manifest, network and checksums.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('Microphone permission is required.');
      }
      final temp = await getTemporaryDirectory();
      _path =
          '${temp.path}/dayark_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
      _amplitude = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            if (mounted) {
              setState(() => _level = ((a.current + 60) / 60).clamp(0, 1));
            }
          });
      _limit = Timer(const Duration(minutes: 2), () => unawaited(_stop()));
      if (mounted) {
        setState(() {
          _recording = true;
          _status = 'Recording · maximum 2 minutes';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Unable to record. Check microphone permissions and device support.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy || !_recording) return;
    setState(() {
      _busy = true;
      _recording = false;
      _status = 'Transcribing…';
    });
    _limit?.cancel();
    await _amplitude?.cancel();
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('No recording.');
      SpeechProvider provider;
      OnlineSpeechProvider? online;
      if (_provider == 'offline') {
        provider = WhisperSpeechProvider(_directory);
      } else {
        final profile = _profiles.firstWhere((p) => p.id == _provider);
        online = OnlineSpeechProvider(
          baseUrl: Uri.parse(profile.baseUrl ?? 'https://api.openai.com/v1'),
          model: _model.text.trim(),
          credential: () => widget.settings.credential(profile.id),
          allowOnline: widget.settings.load().allowOnlineProcessing,
        );
        provider = online;
      }
      try {
        final result = await provider.transcribe(path, language: _language);
        if (mounted) {
          setState(() {
            _text.text = result.text;
            _status = 'Review the transcript before adding it to your message.';
          });
        }
      } finally {
        online?.client.close();
      }
      await _prefs?.setString('ai.voice.language', _language);
      await _prefs?.setString('ai.voice.provider', _provider);
      await _prefs?.setString('ai.voice.model', _model.text.trim());
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Transcription failed. Check the speech model, credentials and online permission.',
        );
      }
    } finally {
      final path = _path;
      if (path != null && await File(path).exists()) await File(path).delete();
      _path = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Voice input'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('provider_$_provider'),
              initialValue: _provider,
              decoration: const InputDecoration(labelText: 'Speech provider'),
              items: [
                const DropdownMenuItem(
                  value: 'offline',
                  child: Text('Offline Whisper'),
                ),
                ..._profiles.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                ),
              ],
              onChanged: _busy || _recording
                  ? null
                  : (v) => setState(() => _provider = v!),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('language_$_language'),
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Speech language'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Automatic')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ur', child: Text('Urdu')),
              ],
              onChanged: _busy || _recording
                  ? null
                  : (v) => setState(() => _language = v!),
            ),
            if (_provider == 'offline')
              Wrap(
                children: [
                  Text(
                    _installed
                        ? 'Whisper installed'
                        : 'No Whisper model installed',
                  ),
                  TextButton(
                    onPressed: _busy || _recording || _prefs == null
                        ? null
                        : _install,
                    child: const Text('Install / update from manifest'),
                  ),
                  if (_installed)
                    TextButton(
                      onPressed: _busy || _recording
                          ? null
                          : () async {
                              await SpeechModels(Directory(_directory))
                                  .delete();
                              if (mounted) setState(() => _installed = false);
                            },
                      child: const Text('Delete model'),
                    ),
                ],
              )
            else ...[
              TextField(
                controller: _model,
                enabled: !_busy && !_recording,
                decoration: const InputDecoration(
                  labelText: 'Transcription model ID',
                ),
              ),
              const Text(
                'Recording audio will be sent to this provider. Online processing must be enabled in AI settings.',
              ),
            ],
            if (_status != null) Text(_status!),
            if (_recording)
              Row(
                children: List.generate(
                  16,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        height: 8 + 40 * _level * ((i % 4 + 1) / 4),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            FilledButton.icon(
              onPressed:
                  _busy ||
                      _prefs == null ||
                      (_provider == 'offline' && !_installed)
                  ? null
                  : _recording
                  ? _stop
                  : _start,
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(
                _recording ? 'Stop and transcribe' : 'Start recording',
              ),
            ),
            TextField(
              controller: _text,
              enabled: !_busy && !_recording,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Editable transcript',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _recording || _text.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _text.text.trim()),
          child: const Text('Use transcript'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    _limit?.cancel();
    _amplitude?.cancel();
    final path = _path;
    unawaited(
      _recorder.dispose().whenComplete(() async {
        if (path != null && await File(path).exists()) {
          await File(path).delete();
        }
      }),
    );
    _text.dispose();
    _model.dispose();
    super.dispose();
  }
}
