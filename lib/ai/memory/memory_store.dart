import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../rag/document_ingestion.dart';
import '../rag/embedding_provider.dart';

class AiMemoryDatabase extends GeneratedDatabase {
  AiMemoryDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, hash TEXT NOT NULL, original BLOB, enabled INTEGER NOT NULL DEFAULT 1)',
      );
      await customStatement(
        'CREATE TABLE chunks(id TEXT PRIMARY KEY, source_id TEXT NOT NULL, ordinal INTEGER NOT NULL, offset INTEGER NOT NULL, text TEXT NOT NULL)',
      );
      await customStatement('CREATE INDEX chunks_source ON chunks(source_id)');
      await customStatement(
        'CREATE VIRTUAL TABLE chunk_fts USING fts5(chunk_id UNINDEXED, text, tokenize="unicode61")',
      );
      await customStatement(
        'CREATE TABLE vectors(chunk_id TEXT PRIMARY KEY, model TEXT NOT NULL, vector TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE memory_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  );
}

class MemorySource {
  const MemorySource({
    required this.id,
    required this.title,
    required this.kind,
    required this.text,
    required this.hash,
    this.enabled = true,
  });
  final String id, title, kind, text, hash;
  final bool enabled;
}

class RetrievalHit {
  const RetrievalHit(
    this.source,
    this.chunk,
    this.offset,
    this.text,
    this.score,
  );
  final MemorySource source;
  final int chunk, offset;
  final String text;
  final double score;
  String get uri => Uri(
    scheme: 'dayark-source',
    path: source.id,
    queryParameters: {
      'hash': source.hash,
      'chunk': '$chunk',
      'offset': '$offset',
    },
  ).toString();
}

/// Private AI-only store. Originals survive vector-model changes. No application
/// database handles, generated SQL, remote embedding calls or automatic memories.
class MemoryManager {
  MemoryManager(this.database);
  final AiMemoryDatabase database;
  Future<void> _pending = Future.value();
  Future<T> _write<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> flag(String key) async => (await setting(key)) == 'true';
  Future<String?> setting(String key) async =>
      (await database
              .customSelect(
                'SELECT value FROM memory_settings WHERE key=?',
                variables: [Variable(key)],
              )
              .getSingleOrNull())
          ?.read<String>('value');
  Future<void> setSetting(String key, String value) => _write(
    () => database.customStatement(
      'INSERT OR REPLACE INTO memory_settings VALUES (?,?)',
      [key, value],
    ),
  );
  MemorySource _source(QueryRow row) => MemorySource(
    id: row.read('id'),
    title: row.read('title'),
    kind: row.read('kind'),
    text: row.read('text'),
    hash: row.read('hash'),
    enabled: row.read<int>('enabled') == 1,
  );
  Future<List<MemorySource>> sources({String query = ''}) async =>
      (await database
              .customSelect(
                'SELECT * FROM sources WHERE instr(lower(title || text),lower(?))>0 ORDER BY kind,title',
                variables: [Variable(query)],
              )
              .get())
          .map(_source)
          .toList();
  Future<MemorySource?> get(String id) async {
    final row = await database
        .customSelect(
          'SELECT * FROM sources WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _source(row);
  }

  Future<void> put({
    required String id,
    required String title,
    required String kind,
    required String text,
    Uint8List? original,
    bool approved = false,
    EmbeddingProvider? embeddings,
  }) => _write(() async {
    if (!['document', 'memory', 'chat'].contains(kind) ||
        (kind == 'memory' && !approved)) {
      throw ArgumentError('A memory requires explicit user approval.');
    }
    if (id.isEmpty ||
        title.trim().isEmpty ||
        title.length > 300 ||
        text.trim().isEmpty ||
        text.length > 1024 * 1024) {
      throw ArgumentError('Invalid source.');
    }
    final hash = sha256.convert(utf8.encode(text)).toString();
    final previous = await get(id);
    if (previous?.hash == hash && previous?.title == title) return;
    final chunks = const ChunkingService().split(text);
    final vectors = embeddings == null
        ? null
        : await embeddings.embed(chunks.map((c) => c.text).toList());
    _validateVectors(vectors, chunks.length);
    await database.transaction(() async {
      await _removeChunks(id);
      await database.customStatement(
        'INSERT OR REPLACE INTO sources VALUES (?,?,?,?,?,?,?)',
        [
          id,
          title,
          kind,
          text,
          hash,
          original,
          (previous?.enabled ?? true) ? 1 : 0,
        ],
      );
      for (final c in chunks) {
        final key = '$id:${c.index}';
        await database.customStatement(
          'INSERT INTO chunks VALUES (?,?,?,?,?)',
          [key, id, c.index, c.offset, c.text],
        );
        await database.customStatement('INSERT INTO chunk_fts VALUES (?,?)', [
          key,
          c.text,
        ]);
        if (vectors != null) {
          await database.customStatement('INSERT INTO vectors VALUES (?,?,?)', [
            key,
            embeddings!.modelId,
            jsonEncode(vectors[c.index]),
          ]);
        }
      }
    });
  });
  static void _validateVectors(List<List<double>>? vectors, int count) {
    if (vectors == null) return;
    if (vectors.length != count ||
        vectors.any(
          (v) =>
              v.isEmpty ||
              v.length != vectors.first.length ||
              v.any((n) => !n.isFinite) ||
              v.every((n) => n == 0),
        )) {
      throw StateError('Invalid embedding dimensions or values.');
    }
  }

  Future<void> _removeChunks(String id) async {
    await database.customStatement(
      'DELETE FROM vectors WHERE chunk_id IN (SELECT id FROM chunks WHERE source_id=?)',
      [id],
    );
    await database.customStatement(
      'DELETE FROM chunk_fts WHERE chunk_id IN (SELECT id FROM chunks WHERE source_id=?)',
      [id],
    );
    await database.customStatement('DELETE FROM chunks WHERE source_id=?', [
      id,
    ]);
  }

  Future<void> delete(String id, {bool excludeChat = false}) => _write(
    () => database.transaction(() async {
      final source = await get(id);
      if (excludeChat && source?.kind == 'chat') {
        await database.customStatement(
          'INSERT OR REPLACE INTO memory_settings VALUES (?,?)',
          ['excluded_$id', 'true'],
        );
      }
      await _removeChunks(id);
      await database.customStatement('DELETE FROM sources WHERE id=?', [id]);
    }),
  );
  Future<void> setEnabled(String id, bool enabled) => _write(
    () => database.customStatement('UPDATE sources SET enabled=? WHERE id=?', [
      enabled ? 1 : 0,
      id,
    ]),
  );
  Future<void> rebuild(EmbeddingProvider embeddings) => _write(() async {
    final rows = await database
        .customSelect('SELECT id,text FROM chunks ORDER BY id')
        .get();
    final vectors = await embeddings.embed(
      rows.map((r) => r.read<String>('text')).toList(),
    );
    _validateVectors(vectors, rows.length);
    await database.transaction(() async {
      await database.customStatement('DELETE FROM vectors');
      for (var i = 0; i < rows.length; i++) {
        await database.customStatement('INSERT INTO vectors VALUES (?,?,?)', [
          rows[i].read<String>('id'),
          embeddings.modelId,
          jsonEncode(vectors[i]),
        ]);
      }
    });
  });
  Future<List<RetrievalHit>> search(
    String query, {
    EmbeddingProvider? embeddings,
    Set<String> kinds = const {'document', 'memory'},
    int limit = 6,
  }) async {
    await _pending;
    if (query.trim().isEmpty || kinds.isEmpty) return [];
    final kindFilter = kinds.map((_) => '?').join(',');
    final kindVariables = kinds.map((kind) => Variable<String>(kind)).toList();
    final scores = <String, double>{};
    final words = RegExp(
      r'[\p{L}\p{N}_]+',
      unicode: true,
    ).allMatches(query).take(32).map((m) => '"${m.group(0)}"').join(' OR ');
    if (words.isNotEmpty) {
      final rows = await database
          .customSelect(
            'SELECT chunk_id FROM chunk_fts JOIN chunks ON chunks.id=chunk_fts.chunk_id '
            'JOIN sources ON sources.id=chunks.source_id WHERE chunk_fts MATCH ? AND sources.enabled=1 '
            'AND sources.kind IN ($kindFilter) ORDER BY bm25(chunk_fts) LIMIT 100',
            variables: [Variable(words), ...kindVariables],
          )
          .get();
      var rank = 0;
      for (final row in rows) {
        scores[row.read<String>('chunk_id')] = 1 / (60 + ++rank);
      }
    }
    if (embeddings != null) {
      final vector = (await embeddings.embed([query])).single;
      _validateVectors([vector], 1);
      final rows = await database
          .customSelect(
            'SELECT vectors.chunk_id, vectors.vector FROM vectors JOIN chunks ON chunks.id=vectors.chunk_id '
            'JOIN sources ON sources.id=chunks.source_id WHERE model=? AND sources.enabled=1 AND sources.kind IN ($kindFilter)',
            variables: [Variable(embeddings.modelId), ...kindVariables],
          )
          .get();
      final ranked = <({String id, double score})>[];
      for (final row in rows) {
        final v = (jsonDecode(row.read<String>('vector')) as List)
            .cast<num>()
            .map((n) => n.toDouble())
            .toList();
        if (v.length != vector.length) continue;
        final score = cosine(vector, v);
        if (score > .15) {
          ranked.add((id: row.read<String>('chunk_id'), score: score));
        }
      }
      ranked.sort((a, b) => b.score.compareTo(a.score));
      for (var i = 0; i < ranked.length.clamp(0, 100); i++) {
        scores.update(
          ranked[i].id,
          (v) => v + 1 / (61 + i),
          ifAbsent: () => 1 / (61 + i),
        );
      }
    }
    final hits = <RetrievalHit>[];
    for (final entry in scores.entries) {
      final row = await database
          .customSelect(
            'SELECT chunks.ordinal,chunks.offset,chunks.text AS excerpt,sources.* '
            'FROM chunks JOIN sources ON sources.id=chunks.source_id WHERE chunks.id=? AND sources.enabled=1',
            variables: [Variable(entry.key)],
          )
          .getSingleOrNull();
      if (row == null || !kinds.contains(row.read<String>('kind'))) continue;
      hits.add(
        RetrievalHit(
          _source(row),
          row.read('ordinal'),
          row.read('offset'),
          row.read('excerpt'),
          entry.value,
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit.clamp(0, 20)).toList();
  }

  static double cosine(List<double> a, List<double> b) {
    var dot = 0.0, aa = 0.0, bb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      aa += a[i] * a[i];
      bb += b[i] * b[i];
    }
    return aa == 0 || bb == 0 ? 0 : dot / math.sqrt(aa * bb);
  }

  Future<void> close() async {
    await _pending;
    await database.close();
  }
}

Future<MemoryManager>? _sharedMemory;
Future<MemoryManager> sharedMemoryManager() => _sharedMemory ??= Future.value(
  MemoryManager(AiMemoryDatabase(driftDatabase(name: 'dayark_ai_memory_v1'))),
);
