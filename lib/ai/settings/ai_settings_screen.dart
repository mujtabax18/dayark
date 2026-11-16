import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/ai_capabilities.dart';
import '../core/ai_gateway.dart';
import '../providers/http/http_ai_provider.dart';
import 'ai_preferences.dart';
import 'ai_settings.dart';
import 'ai_settings_store.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, this.store});
  final AiSettingsStore? store;
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiSettingsStore? _store;
  AiPreferences _preferences = AiPreferences();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _model = TextEditingController(),
      _url = TextEditingController(),
      _secret = TextEditingController(),
      _temperature = TextEditingController(),
      _output = TextEditingController(),
      _context = TextEditingController(),
      _instructions = TextEditingController(),
      _inputLanguage = TextEditingController(),
      _customLanguage = TextEditingController();
  String? _id;
  String _language = 'Automatic';
  AiProviderKind _kind = AiProviderKind.offline;
  bool _online = false, _private = false, _busy = true, _clearSecret = false;
  String? _status;
  static const _languages = [
    'Automatic',
    'English',
    'Urdu',
    'Roman Urdu',
    'Custom',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store =
          widget.store ??
          AiSettingsStore(preferences: await SharedPreferences.getInstance());
      final value = store.load();
      if (!mounted) return;
      setState(() {
        _store = store;
        _preferences = value;
        _online = value.allowOnlineProcessing;
        _private = value.allowPrivateContextOnline;
        final s = value.settings;
        _temperature.text = s.temperature?.toString() ?? '';
        _output.text = s.maxOutputTokens?.toString() ?? '';
        _context.text = s.contextWindowTokens?.toString() ?? '';
        _instructions.text = s.customInstructions;
        _inputLanguage.text = s.inputLanguage ?? '';
        _language = s.responseLanguage == null
            ? 'Automatic'
            : _languages.contains(s.responseLanguage)
            ? s.responseLanguage!
            : 'Custom';
        _customLanguage.text = _language == 'Custom' ? s.responseLanguage! : '';
        _select(value.selectedProfile);
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status =
              'Unable to load AI settings. Check local storage availability.';
        });
      }
    }
  }

  void _select(AiProviderProfile? p) {
    _id = p?.id;
    _name.text = p?.name ?? '';
    _model.text = p?.modelId ?? '';
    _url.text = p?.baseUrl ?? '';
    _kind = p?.kind ?? AiProviderKind.offline;
    _secret.clear();
    _clearSecret = false;
  }

  AiProviderProfile _profile() => AiProviderProfile(
    id: _id ?? const Uuid().v4(),
    name: _name.text.trim(),
    kind: _kind,
    modelId: _model.text.trim(),
    baseUrl: _kind == AiProviderKind.offline || _url.text.trim().isEmpty
        ? null
        : _url.text.trim(),
  );
  AiCapabilities get _capabilities {
    if (_kind == AiProviderKind.offline) {
      return AiCapabilities(contextWindow: true);
    }
    try {
      final p = _profile().createProvider(credentials: () async => null);
      final c = p.capabilitiesFor(_model.text.trim());
      if (p is HttpAiProvider) p.close();
      return c;
    } catch (_) {
      return AiCapabilities(contextWindow: _kind == AiProviderKind.ollama);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Unable to complete operation. Check the profile, credentials and storage.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _destinationChanged(AiProviderProfile profile) {
    final previous = _preferences.profiles
        .where((p) => p.id == profile.id)
        .firstOrNull;
    return previous != null &&
        (previous.kind != profile.kind || previous.baseUrl != profile.baseUrl);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final p = _profile();
      final settings = AiSettings(
        temperature: double.tryParse(_temperature.text),
        maxOutputTokens: int.tryParse(_output.text),
        contextWindowTokens: int.tryParse(_context.text),
        customInstructions: _instructions.text,
        inputLanguage: _inputLanguage.text.trim().isEmpty
            ? null
            : _inputLanguage.text.trim(),
        responseLanguage: _language == 'Automatic'
            ? null
            : _language == 'Custom'
            ? _customLanguage.text.trim()
            : _language,
      );
      // Validate logical settings before changing any persisted state.
      final value = AiPreferences(
        profiles: [..._preferences.profiles.where((v) => v.id != p.id), p],
        selectedProfileId: p.id,
        settings: settings,
        allowOnlineProcessing: _online,
        allowPrivateContextOnline: _private,
      );
      if (_kind == AiProviderKind.offline || _clearSecret) {
        await _store!.deleteCredential(p.id);
      } else if (_secret.text.isNotEmpty) {
        await _store!.setCredential(p.id, _secret.text);
      } else if (_destinationChanged(p)) {
        await _store!.deleteCredential(p.id);
      }
      await _store!.save(value);
      if (mounted) {
        setState(() {
          _preferences = value;
          _id = p.id;
          _secret.clear();
          _clearSecret = false;
          _status = 'AI settings saved.';
        });
      }
    });
  }

  Future<void> _check(bool discover) async {
    if (!_form.currentState!.validate()) return;
    if (!_online) {
      setState(
        () => _status = 'Enable online processing to contact this provider.',
      );
      return;
    }
    await _run(() async {
      final profile = _profile();
      final provider = profile.createProvider(
        credentials: () async => _clearSecret
            ? null
            : _secret.text.isNotEmpty
            ? _secret.text
            : _destinationChanged(profile)
            ? null
            : _store!.credential(profile.id),
      );
      try {
        final gateway = AiGateway(providers: [provider]);
        final String status;
        if (discover) {
          final page = await gateway.listModels(
            providerId: profile.id,
            allowRemoteProcessing: true,
          );
          status = page.models.isEmpty
              ? 'No models returned.'
              : 'Available models: ${page.models.map((m) => m.selection.modelId).join(', ')}${page.nextCursor == null ? '' : ' (more available)'}';
        } else {
          final result = await gateway.testConnection(
            providerId: profile.id,
            modelId: profile.modelId,
            allowRemoteProcessing: true,
          );
          status = result.isConnected
              ? 'Connection successful.'
              : 'Connection failed: ${result.error!.code.name}';
        }
        if (mounted) setState(() => _status = status);
      } finally {
        if (provider is HttpAiProvider) provider.close();
      }
    });
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int lines = 1,
    bool secret = false,
    String? Function(String?)? validator,
    bool rebuild = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      onChanged: rebuild ? (_) => setState(() {}) : null,
      validator:
          validator ??
          (v) => required && (v?.trim().isEmpty ?? true) ? 'Required' : null,
    ),
  );
  String? _number(String? v, {bool integer = false}) {
    if (v == null || v.trim().isEmpty) return null;
    final n = num.tryParse(v);
    return n == null ||
            !n.isFinite ||
            (integer
                ? int.tryParse(v) == null || n <= 0
                : n < 0 || n > (_capabilities.maxTemperature ?? 2))
        ? 'Enter a supported ${integer ? 'positive integer' : 'temperature'}.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final caps = _capabilities;
    return Scaffold(
      appBar: AppBar(title: const Text('AI settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_status!, semanticsLabel: _status),
                    ),
                  if (_store == null && !_busy)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry loading'),
                    ),
                  const Text('Provider profiles'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_id),
                    initialValue: _id ?? '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('New profile'),
                      ),
                      ..._preferences.profiles.map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ),
                    ],
                    onChanged: (id) => setState(
                      () => _select(
                        _preferences.profiles
                            .where((p) => p.id == id)
                            .firstOrNull,
                      ),
                    ),
                  ),
                  _field(_name, 'Profile name', required: true),
                  DropdownButtonFormField<AiProviderKind>(
                    key: ValueKey(_kind),
                    initialValue: _kind,
                    items: AiProviderKind.values
                        .map(
                          (k) =>
                              DropdownMenuItem(value: k, child: Text(k.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _kind = v!;
                      _url.clear();
                      _secret.clear();
                    }),
                  ),
                  _field(
                    _model,
                    _kind == AiProviderKind.offline
                        ? 'Installed local model ID'
                        : 'Model ID',
                    required: true,
                    rebuild: true,
                  ),
                  if (_kind == AiProviderKind.offline)
                    const Text(
                      'Use a model installed with the local model manager. No model is loaded by this screen.',
                    ),
                  if (_kind != AiProviderKind.offline) ...[
                    _field(
                      _url,
                      'Base URL (blank uses provider default)',
                      rebuild: true,
                      validator: (_) {
                        try {
                          _profile();
                          return null;
                        } catch (_) {
                          return 'Enter a valid HTTPS URL (localhost may use HTTP). Compatible APIs require a URL.';
                        }
                      },
                    ),
                    _field(
                      _secret,
                      'API key / bearer token (blank keeps saved credential)',
                      secret: true,
                    ),
                    const Text(
                      'Changing provider or URL clears the old credential. Enter a new key for the new destination.',
                    ),
                    CheckboxListTile(
                      value: _clearSecret,
                      onChanged: (v) => setState(() => _clearSecret = v!),
                      title: const Text('Remove saved credential'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _check(false),
                          child: const Text('Test connection'),
                        ),
                        OutlinedButton(
                          onPressed: () => _check(true),
                          child: const Text('Discover models'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Behavior'),
                  if (caps.temperature)
                    _field(
                      _temperature,
                      'Temperature (blank uses model default)',
                      validator: _number,
                    ),
                  if (caps.outputTokenLimit)
                    _field(
                      _output,
                      'Maximum output tokens',
                      validator: (v) => _number(v, integer: true),
                    ),
                  if (caps.contextWindow)
                    _field(
                      _context,
                      'Context window tokens',
                      validator: (v) => _number(v, integer: true),
                    ),
                  _field(_instructions, 'Custom instructions', lines: 4),
                  const Text(
                    'Custom instructions remain subject to DayArk permissions.',
                  ),
                  _field(
                    _inputLanguage,
                    'Preferred input language (blank = automatic)',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_language),
                    initialValue: _language,
                    decoration: const InputDecoration(
                      labelText: 'Response language',
                    ),
                    items: _languages
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                  if (_language == 'Custom')
                    _field(
                      _customLanguage,
                      'Custom response language',
                      required: true,
                    ),
                  const SizedBox(height: 24),
                  const Text('Privacy'),
                  SwitchListTile(
                    value: _online,
                    onChanged: (v) => setState(() => _online = v),
                    title: const Text('Allow online processing'),
                    subtitle: const Text(
                      'Authorize sending conversation content to the selected online or self-hosted provider.',
                    ),
                  ),
                  SwitchListTile(
                    value: _private,
                    onChanged: (v) => setState(() => _private = v),
                    title: const Text('Allow private context online'),
                    subtitle: const Text(
                      'Also authorize private retrieved content when online processing is enabled. Off by default.',
                    ),
                  ),
                  FilledButton(
                    onPressed: _store == null ? null : _save,
                    child: const Text('Save settings'),
                  ),
                  if (_id != null)
                    TextButton(
                      onPressed: () => _run(() async {
                        final id = _id!;
                        final value = AiPreferences(
                          profiles: _preferences.profiles.where(
                            (p) => p.id != id,
                          ),
                          settings: _preferences.settings,
                          allowOnlineProcessing: _online,
                          allowPrivateContextOnline: _private,
                        );
                        await _store!.save(value);
                        await _store!.deleteCredential(id);
                        if (mounted) {
                          setState(() {
                            _preferences = value;
                            _select(null);
                            _status = 'Profile deleted.';
                          });
                        }
                      }),
                      child: const Text('Delete profile'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _model,
      _url,
      _secret,
      _temperature,
      _output,
      _context,
      _instructions,
      _inputLanguage,
      _customLanguage,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
