import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../rag/document_ingestion.dart';
import '../rag/embedding_provider.dart';
import 'memory_store.dart';
import 'memory_context_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, this.manager});
  final MemoryManager? manager;
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  MemoryManager? _memory;
  List<MemorySource> _sources = [];
  final _search = TextEditingController();
  bool _busy = true;
  String? _status;
  final _flags = <String, bool>{};
  String? _embedding;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final memory = widget.manager ?? await sharedMemoryManager();
      final sources = await memory.sources(query: _search.text);
      final flags = <String, bool>{};
      for (final key in ['rag', 'memory', 'summaries', 'indexChats']) {
        flags[key] = await memory.flag(key);
      }
      final embedding = await memory.setting('embeddingPath');
      if (mounted) {
        setState(() {
          _memory = memory;
          _sources = sources;
          _flags.addAll(flags);
          _embedding = embedding == '' ? null : embedding;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Unable to open knowledge storage.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _status = e is FormatException ? e.message : 'Operation failed. Check the file, embedding model and storage.',
        );
      }
    } finally {
      await _load();
    }
  }

  Future<void> _import([MemorySource? previous]) => _run(() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'markdown'],
    );
    if (files.isEmpty) return;
    final file = files.single;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Documents are limited to 8 MiB.');
    }
    final bytes = await file.readAsBytes();
    final text = await DocumentIngestion.extract(file.name, bytes);
    await _memory!.put(
      id: previous?.id ?? const Uuid().v4(),
      title: file.name,
      kind: 'document',
      text: text,
      original: bytes,
      embeddings: await configuredEmbeddings(_memory!),
    );
  });
  Future<void> _fact([MemorySource? source]) async {
    final input = TextEditingController(text: source?.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(source == null ? 'Approve a memory' : 'Review memory'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save only facts you want the assistant to retrieve. Memories stay on this device; private context sent online requires the separate AI privacy permission.',
            ),
            TextField(
              controller: input,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Fact or preference',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Approve and save'),
          ),
        ],
      ),
    );
    // Dialog routes finish their closing animation after their result resolves.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    await _run(
      () async => _memory!.put(
        id: source?.id ?? const Uuid().v4(),
        title: value.runes.take(60).map(String.fromCharCode).join(),
        kind: 'memory',
        text: value,
        approved: true,
        embeddings: await configuredEmbeddings(_memory!),
      ),
    );
  }

  Future<void> _chooseEmbedding() => _run(() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    if (files.isEmpty) return;
    final path = files.single.path;
    if (path == null) {
      throw const FormatException('Choose a local GGUF embedding model.');
    }
    final hash = (await sha256.bind(File(path).openRead()).first).toString();
    final provider = LocalEmbeddingProvider(path: path, modelId: hash);
    // Rebuild transaction preserves the previous index if embedding fails.
    await _memory!.rebuild(provider);
    await _memory!.setSetting('embeddingPath', path);
    await _memory!.setSetting('embeddingId', hash);
  });
  Future<void> _delete(MemorySource source) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this source?'),
        content: Text(
          'Remove ${source.title}, its chunks and search index from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(() => _memory!.delete(source.id, excludeChat: true));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Memory & knowledge')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Private AI knowledge. Only uploaded documents, approved memories and opted-in AI conversations are eligible. Existing DayArk records are excluded.',
        ),
        for (final setting in <String, String>{
          'rag': 'Retrieve uploaded documents',
          'memory': 'Retrieve approved memories',
          'summaries': 'Summarize older conversation context',
          'indexChats': 'Index AI conversation history',
        }.entries)
          SwitchListTile(
            title: Text(setting.value),
            value: _flags[setting.key] ?? false,
            onChanged: _busy || _memory == null
                ? null
                : (v) => _run(() async {
                    await _memory!.setSetting(setting.key, '$v');
                    if (setting.key == 'indexChats' && !v) {
                      for (final s in await _memory!.sources()) {
                        if (s.kind == 'chat') await _memory!.delete(s.id);
                      }
                    }
                  }),
          ),
        Text(
          _embedding == null
              ? 'Keyword search active. Select a compatible embedding GGUF to enable semantic search.'
              : 'Local semantic model: $_embedding',
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _chooseEmbedding,
              child: const Text('Select embedding model / rebuild'),
            ),
            if (_embedding != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _memory!.setSetting('embeddingPath', '');
                        await _memory!.setSetting('embeddingId', '');
                      }),
                child: const Text('Use keyword search'),
              ),
            FilledButton.icon(
              onPressed: _busy || _memory == null ? null : () => _import(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload document'),
            ),
            FilledButton.icon(
              onPressed: _busy || _memory == null ? null : () => _fact(),
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Approve memory'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_status != null)
          Text(
            _status!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Search sources',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (_) => _load(),
        ),
        for (final source in _sources)
          Card(
            child: ListTile(
              title: Text(source.title),
              subtitle: Text(
                '${source.kind} · ${source.text.runes.length} characters',
              ),
              onTap: () => showMemorySource(context, _memory!, source.id),
              leading: Checkbox(
                value: source.enabled,
                onChanged: _busy
                    ? null
                    : (v) => _run(() => _memory!.setEnabled(source.id, v!)),
              ),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (action) {
                  if (action == 'delete') _delete(source);
                  if (action == 'edit') {
                    if (source.kind == 'memory') {
                      _fact(source);
                    } else {
                      _import(source);
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (source.kind != 'chat')
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        source.kind == 'memory'
                            ? 'Edit memory'
                            : 'Replace document',
                      ),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
        if (!_busy && _sources.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No sources. Upload a document or approve a memory to begin.',
            ),
          ),
      ],
    ),
  );
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

Future<void> showMemorySource(
  BuildContext context,
  MemoryManager memory,
  String id, {
  String? hash,
  int? offset,
}) async {
  final source = await memory.get(id);
  if (!context.mounted) return;
  final text = source == null
      ? 'This source has been deleted.'
      : hash != null && hash != source.hash
      ? 'This source changed after the answer was generated. The cited version is no longer available.'
      : source.text;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(source?.title ?? 'Source unavailable'),
      scrollable: true,
      content: SizedBox(
        width: 650,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offset != null)
              Text('Cited excerpt starts at character $offset.'),
            SelectableText(text),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
