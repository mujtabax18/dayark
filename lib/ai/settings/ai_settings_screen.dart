import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/ai_capabilities.dart';
import '../core/ai_gateway.dart';
import '../providers/http/http_ai_provider.dart';
import 'ai_preferences.dart';
import 'ai_defaults.dart';
import 'ai_defaults_screen.dart';
import 'ai_local_models.dart';
import 'ai_local_models_factory.dart';
import 'ai_local_models_screen.dart';
import 'ai_settings.dart';
import 'ai_settings_store.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, this.store, this.localModels});
  final AiSettingsStore? store;
  final Future<AiLocalModels> Function()? localModels;
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiSettingsStore? _store;
  AiPreferences _preferences = AiPreferences();
  AiDefaults _defaults = AiDefaults.builtIn();
  AiLocalModels? _local;
  final Set<String> _discovered = {};
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
      AiDefaults defaults;
      String? defaultsNotice;
      try {
        defaults = store.loadDefaults();
      } catch (_) {
        defaults = AiDefaults.builtIn();
        defaultsNotice = 'Saved model defaults could not be read. Built-in choices are shown; save new defaults in Provider and model defaults.';
      }
      AiLocalModels? local;
      if ((value.selectedProfile?.kind ?? AiProviderKind.offline) ==
          AiProviderKind.offline) {
        try {
          local = await (widget.localModels ?? sharedAiLocalModels)();
        } catch (_) {
          defaultsNotice = 'Local model storage is unavailable. Retry Local model manager or choose an online provider.';
        }
      }
      if (!mounted) return;
      setState(() {
        _local = local;
        _store = store;
        _defaults = defaults;
        _status = defaultsNotice;
        _preferences = value;
        _online = value.allowOnlineProcessing;
        _private = value.allowPrivateContextOnline;
        final s = value.settings;
        final d = defaults.forKind(
          value.selectedProfile?.kind ?? AiProviderKind.offline,
        );
        _temperature.text = s.temperature?.toString() ?? '${d.temperature}';
        _output.text = s.maxOutputTokens?.toString() ?? '${d.outputTokens}';
        _context.text =
            s.contextWindowTokens?.toString() ?? '${d.contextTokens}';
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
    _kind = p?.kind ?? AiProviderKind.offline;
    final defaults = _defaults.forKind(_kind);
    _name.text = p?.name ?? aiProviderLabel(_kind);
    _model.text = p?.modelId ?? defaults.models.first;
    _url.text = p?.baseUrl ?? defaults.baseUrl ?? '';
    _discovered.clear();
    if (p == null && _preferences.profiles.isEmpty) _behaviorDefaults();
    _secret.clear();
    _clearSecret = false;
  }

  void _behaviorDefaults() {
    final d = _defaults.forKind(_kind);
    _temperature.text = '${d.temperature}';
    _output.text = '${d.outputTokens}';
    _context.text = '${d.contextTokens}';
  }

  void _changeKind(AiProviderKind kind) {
    _kind = kind;
    final d = _defaults.forKind(kind);
    _name.text = aiProviderLabel(kind);
    _model.text = d.models.first;
    _url.text = d.baseUrl ?? '';
    _secret.clear();
    _discovered.clear();
    _behaviorDefaults();
  }

  Future<AiLocalModels> _ensureLocal() async =>
      _local ??= await (widget.localModels ?? sharedAiLocalModels)();
  Future<void> _openManager() => _run(() async {
    final models = await _ensureLocal();
    if (!mounted) return;
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AiLocalModelsScreen(models: models, defaults: _defaults),
      ),
    );
    if (id != null && mounted) {
      setState(() {
        if (_kind != AiProviderKind.offline) {
          _id = null;
          _changeKind(AiProviderKind.offline);
        }
        _model.text = id;
        _status = 'Local model selected. Save settings to use it.';
      });
    }
  });
  Future<void> _openDefaults() async {
    if (_store == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AiDefaultsScreen(store: _store!)),
    );
    if (!mounted || saved != true) return;
    setState(() {
      _defaults = _store!.loadDefaults();
    });
  }

  List<String> get _modelChoices => {
    ...(_kind == AiProviderKind.offline
        ? _defaults.catalogue.models.map((m) => m.id)
        : _defaults.forKind(_kind).models),
    if (_kind == AiProviderKind.offline && _local != null)
      ..._local!.installed.map((m) => m.id),
    ..._discovered,
    if (_model.text.isNotEmpty) _model.text,
  }.toList();
  String _modelLabel(String id) {
    if (_kind != AiProviderKind.offline) return id;
    final model = _defaults.catalogue.models
        .where((m) => m.id == id)
        .firstOrNull;
    final installed = _local?.installed.any((m) => m.id == id) ?? false;
    return '${model?.name ?? id} · ${installed
        ? 'installed'
        : model?.artifact != null
        ? 'download available'
        : 'not installed'}';
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
        (previous.kind != profile.kind ||
            (previous.baseUrl ??
                    AiDefaults.builtIn().forKind(previous.kind).baseUrl) !=
                profile.baseUrl);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final p = _profile();
      if (_kind == AiProviderKind.offline) {
        final local = await _ensureLocal();
        if (!local.installed.any((m) => m.id == p.modelId)) {
          if (mounted) {
            setState(
              () => _status = 'Install this model in Local model manager before saving an offline profile.',
            );
          }
          return;
        }
      }
      final settings = AiSettings(
        temperature: double.tryParse(_temperature.text),
        maxOutputTokens: int.tryParse(_output.text),
        contextWindowTokens: _capabilities.contextWindow
            ? int.tryParse(_context.text)
            : null,
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
          final ids = <String>{};
          final cursors = <String>{};
          String? cursor;
          do {
            final page = await gateway.listModels(
              providerId: profile.id,
              cursor: cursor,
              allowRemoteProcessing: true,
            );
            ids.addAll(
              page.models.map(
                (m) =>
                    m.selection.modelId.replaceFirst(RegExp(r'^models/'), ''),
              ),
            );
            cursor = page.nextCursor;
          } while (cursor != null &&
              cursors.add(cursor) &&
              cursors.length < 100);
          if (mounted) {
            setState(() {
              _discovered.addAll(ids);
            });
          }
          status = ids.isEmpty
              ? 'No models returned.'
              : '${ids.length} models added to the model picker${cursor == null ? '.' : ' (provider has more pages).'}';
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
  Widget _tokenPicker(
    TextEditingController controller,
    String label,
    List<int> presets,
  ) {
    final selected = int.tryParse(controller.text) ?? presets[2];
    final values = {...presets, selected}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$label:$selected'),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text('$v tokens')))
            .toList(),
        onChanged: (v) => setState(() {
          controller.text = '$v';
          if (controller == _output &&
              _capabilities.contextWindow &&
              v! > (int.tryParse(_context.text) ?? 4096)) {
            _context.text = '${v * 2}';
          }
        }),
        validator: (v) => v == null || v <= 0
            ? 'Select a positive token limit.'
            : controller == _context && v < (int.tryParse(_output.text) ?? 0)
            ? 'Context must include the output token limit.'
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI settings')),
        body: Center(
          child: _busy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_status ?? 'Unable to load AI settings.'),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry loading'),
                    ),
                  ],
                ),
        ),
      );
    }
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
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.download_for_offline_outlined,
                          ),
                          title: const Text('Local model manager'),
                          subtitle: const Text(
                            'Hardware recommendations, downloads and installed models',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openManager,
                        ),
                        ListTile(
                          leading: const Icon(Icons.tune),
                          title: const Text('Provider and model defaults'),
                          subtitle: const Text(
                            'Update model choices, URLs and generation defaults',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openDefaults,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(aiProviderLabel(k)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _changeKind(v!));
                      if (v == AiProviderKind.offline) {
                        _run(() async {
                          await _ensureLocal();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${_kind.name}:${_model.text}:${_discovered.length}:${_defaults.hashCode}',
                    ),
                    initialValue: _model.text,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    items: _modelChoices
                        .map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text(
                              _modelLabel(id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setState(() => _model.text = id!),
                  ),
                  if (_kind == AiProviderKind.offline)
                    TextButton.icon(
                      onPressed: _openManager,
                      icon: const Icon(Icons.download),
                      label: const Text('Browse and download local models'),
                    ),
                  if (_kind == AiProviderKind.compatible)
                    const Text(
                      'Compatible servers choose their own model IDs. Discover models or edit the defaults for your server.',
                    ),
                  if (_kind != AiProviderKind.offline) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Server endpoint'),
                      subtitle: Text(_url.text),
                    ),
                    ExpansionTile(
                      title: const Text('Advanced profile configuration'),
                      children: [
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
                          _model,
                          'Custom model ID',
                          required: true,
                          rebuild: true,
                        ),
                      ],
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
                  if (caps.temperature) ...[
                    Text(
                      'Temperature: ${(double.tryParse(_temperature.text) ?? .7).clamp(0, caps.maxTemperature ?? 2).toStringAsFixed(1)}',
                    ),
                    Slider(
                      value: (double.tryParse(_temperature.text) ?? .7)
                          .clamp(0, caps.maxTemperature ?? 2)
                          .toDouble(),
                      min: 0,
                      max: caps.maxTemperature ?? 2,
                      divisions: 20,
                      onChanged: (value) => setState(
                        () => _temperature.text = value.toStringAsFixed(2),
                      ),
                    ),
                  ],
                  if (caps.outputTokenLimit)
                    _tokenPicker(_output, 'Maximum output tokens', [
                      512,
                      1024,
                      2048,
                      4096,
                      8192,
                      16384,
                    ]),
                  if (caps.contextWindow)
                    _tokenPicker(_context, 'Context window tokens', [
                      2048,
                      4096,
                      8192,
                      16384,
                      32768,
                    ]),
                  TextButton(
                    onPressed: () => setState(_behaviorDefaults),
                    child: const Text('Apply provider defaults'),
                  ),
                  _field(_instructions, 'Custom instructions', lines: 4),
                  const Text(
                    'Custom instructions remain subject to DayArk permissions.',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('input:${_inputLanguage.text}'),
                    initialValue: _inputLanguage.text,
                    decoration: const InputDecoration(
                      labelText: 'Input language',
                    ),
                    items:
                        {
                              '': 'Automatic',
                              'English': 'English',
                              'Urdu': 'Urdu',
                              'Roman Urdu': 'Roman Urdu',
                              if (_inputLanguage.text.isNotEmpty)
                                _inputLanguage.text: _inputLanguage.text,
                            }.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _inputLanguage.text = v!),
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
