import 'dart:convert';

import 'package:flutter/material.dart';

import 'ai_defaults.dart';
import 'ai_preferences.dart';
import 'ai_settings_store.dart';

String aiProviderLabel(AiProviderKind kind) => switch (kind) {
  AiProviderKind.offline => 'Offline · on this device',
  AiProviderKind.openai => 'OpenAI',
  AiProviderKind.gemini => 'Google Gemini',
  AiProviderKind.anthropic => 'Anthropic Claude',
  AiProviderKind.ollama => 'Ollama · self-hosted',
  AiProviderKind.compatible => 'Compatible API · custom server',
};

class AiDefaultsScreen extends StatefulWidget {
  const AiDefaultsScreen({super.key, required this.store});
  final AiSettingsStore store;
  @override
  State<AiDefaultsScreen> createState() => _AiDefaultsScreenState();
}

class _AiDefaultsScreenState extends State<AiDefaultsScreen> {
  late AiDefaults _defaults;
  AiProviderKind _kind = AiProviderKind.offline;
  final _models = TextEditingController(),
      _url = TextEditingController(),
      _output = TextEditingController(),
      _context = TextEditingController(),
      _catalogue = TextEditingController();
  double _temperature = .7;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    try {
      _defaults = widget.store.loadDefaults();
    } catch (_) {
      _defaults = AiDefaults.builtIn();
      _error = 'Saved defaults could not be read. Review and save the built-in defaults to repair them.';
    }
    _select();
  }

  void _select() {
    final d = _defaults.forKind(_kind);
    _models.text = d.models.join('\n');
    _url.text = d.baseUrl ?? '';
    _temperature = d.temperature
        .clamp(0, _kind == AiProviderKind.anthropic ? 1 : 2)
        .toDouble();
    _output.text = '${d.outputTokens}';
    _context.text = '${d.contextTokens}';
    _catalogue.text = const JsonEncoder.withIndent('  ')
        .convert(_defaults.catalogue.models.map(catalogueModelToJson).toList());
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = AiProviderDefaults(
        kind: _kind,
        models: _models.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        baseUrl: _kind == AiProviderKind.offline || _url.text.trim().isEmpty
            ? null
            : _url.text.trim(),
        temperature: _temperature,
        outputTokens: int.parse(_output.text),
        contextTokens: int.parse(_context.text),
      );
      final json = _defaults.toJson();
      json['providers'] = [
        ..._defaults.providers.where((p) => p.kind != _kind),
        d,
      ].map((p) => p.toJson()).toList();
      if (_kind == AiProviderKind.offline) {
        json['catalogue'] = jsonDecode(_catalogue.text);
      }
      final value = AiDefaults.fromJson(json);
      await widget.store.saveDefaults(value);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Defaults were not saved. Check model IDs, URL, positive token limits (output ≤ context), and catalogue metadata.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 18,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider and model defaults')),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Defaults prefill new profiles. Existing saved profiles change only when you edit and save them. No credentials are stored here.',
              ),
              const Text(
                'Built-in model list reviewed ${AiDefaults.reviewed}. Use Discover models in AI settings to check availability for your account.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              DropdownButtonFormField<AiProviderKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: AiProviderKind.values
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(aiProviderLabel(k)),
                      ),
                    )
                    .toList(),
                onChanged: (k) => setState(() {
                  _kind = k!;
                  _select();
                  _error = null;
                }),
              ),
              _field(
                _models,
                'Model IDs (one per line; first is the default)',
                lines: 3,
              ),
              if (_kind != AiProviderKind.offline)
                _field(_url, 'Default base URL'),
              Text('Default temperature: ${_temperature.toStringAsFixed(1)}'),
              Slider(
                value: _temperature,
                min: 0,
                max: _kind == AiProviderKind.anthropic ? 1 : 2,
                divisions: _kind == AiProviderKind.anthropic ? 10 : 20,
                onChanged: (v) => setState(() => _temperature = v),
              ),
              _field(_output, 'Default maximum output tokens'),
              _field(_context, 'Default local context tokens'),
              if (_kind == AiProviderKind.offline)
                ExpansionTile(
                  title: const Text('Advanced: downloadable model catalogue'),
                  subtitle: const Text(
                    'Update pinned downloads or add compatible GGUF models',
                  ),
                  children: [
                    const Text(
                      'Use metadata from a trusted publisher. Each downloadable artifact requires its exact HTTPS URL, SHA-256, byte size, revision, and approved redirect hosts. Editing does not start a download.',
                    ),
                    _field(_catalogue, 'Catalogue JSON', lines: 10),
                  ],
                ),
              FilledButton(
                onPressed: _save,
                child: const Text('Save defaults'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _defaults = AiDefaults.builtIn();
                  _select();
                }),
                child: const Text('Restore built-in defaults for editing'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    for (final c in [_models, _url, _output, _context, _catalogue]) {
      c.dispose();
    }
    super.dispose();
  }
}
