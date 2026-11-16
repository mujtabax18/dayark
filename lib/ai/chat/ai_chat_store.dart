import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'ai_conversation.dart';

class AiChatSyncLimit implements Exception {
  const AiChatSyncLimit();
}

class AiChatConflict implements Exception {
  const AiChatConflict();
}

class AiChatDatabase extends GeneratedDatabase {
  AiChatDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, folder TEXT NOT NULL, pinned INTEGER NOT NULL, archived INTEGER NOT NULL, deleted INTEGER NOT NULL, shared INTEGER NOT NULL, revision INTEGER NOT NULL, search_text TEXT NOT NULL, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE chat_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  );
}

/// Separate AI-only database; never queries DayArk feature records or credentials.
class AiChatStore {
  AiChatStore(this.database);
  final AiChatDatabase database;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Future<String> get deviceId async {
    await database.customStatement(
      'INSERT OR IGNORE INTO chat_settings(key,value) VALUES (?,?)',
      ['replica', const Uuid().v4()],
    );
    return (await database
            .customSelect("SELECT value FROM chat_settings WHERE key='replica'")
            .getSingle())
        .read<String>('value');
  }

  Future<bool> get syncEnabled async =>
      (await database
              .customSelect("SELECT value FROM chat_settings WHERE key='sync'")
              .getSingleOrNull())
          ?.read<String>('value') ==
      'true';
  Future<void> setSyncEnabled(bool value) async {
    await database.customStatement(
      'INSERT OR REPLACE INTO chat_settings(key,value) VALUES (?,?)',
      ['sync', '$value'],
    );
    _changes.add(null);
  }

  Future<AiConversation?> get(String id) async {
    final row = await database
        .customSelect(
          'SELECT payload FROM conversations WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : AiConversation.fromJson(
            jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
          );
  }

  Future<List<AiConversation>> list({
    String query = '',
    bool archived = false,
    String? folder,
    bool summaries = false,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT ${summaries ? 'id,title,folder,pinned,archived,shared,revision' : 'payload'} FROM conversations WHERE deleted=0 AND archived=? AND instr(lower(search_text),lower(?))>0 ${folder == null ? '' : 'AND folder=?'} ORDER BY pinned DESC, revision DESC',
          variables: [
            Variable(archived ? 1 : 0),
            Variable(query),
            if (folder != null) Variable(folder),
          ],
        )
        .get();
    if (summaries) {
      return rows
          .map(
            (r) => AiConversation(
              id: r.read<String>('id'),
              title: r.read<String>('title'),
              folder: r.read<String>('folder'),
              pinned: r.read<int>('pinned') == 1,
              archived: r.read<int>('archived') == 1,
              shareWithDevices: r.read<int>('shared') == 1,
              revision: r.read<int>('revision'),
              updatedAt: DateTime.fromMicrosecondsSinceEpoch(
                r.read<int>('revision'),
                isUtc: true,
              ),
            ),
          )
          .toList();
    }
    return rows
        .map(
          (r) => AiConversation.fromJson(
            jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> _write(AiConversation c) async {
    final encoded = jsonEncode(c.toJson());
    if (utf8.encode(encoded).length > 24 * 1024 * 1024) {
      throw const FormatException(
        'Conversation exceeds 24 MiB. Start a new chat.',
      );
    }
    await database.customStatement(
      'INSERT OR REPLACE INTO conversations VALUES (?,?,?,?,?,?,?,?,?,?)',
      [
        c.id,
        c.title,
        c.folder,
        c.pinned ? 1 : 0,
        c.archived ? 1 : 0,
        c.deleted ? 1 : 0,
        c.shareWithDevices ? 1 : 0,
        c.revision,
        '${c.title}\n${c.messages.map((m) => m.message.text).join('\n')}',
        encoded,
      ],
    );
  }

  Future<AiConversation> save(AiConversation c, {int? expectedRevision}) async {
    final origin = await deviceId;
    final saved = await database.transaction(() async {
      final previous = await get(c.id);
      if (expectedRevision != null &&
          (previous?.revision ?? 0) != expectedRevision) {
        throw const AiChatConflict();
      }
      final now = DateTime.now().toUtc();
      final revision = now.microsecondsSinceEpoch > (previous?.revision ?? 0)
          ? now.microsecondsSinceEpoch
          : previous!.revision + 1;
      final clock = {...?previous?.clock, ...c.clock};
      clock[origin] = (clock[origin] ?? 0) + 1;
      final value = c.copyWith(
        revision: revision,
        origin: origin,
        updatedAt: now,
        clock: clock,
      );
      await _write(value);
      return value;
    });
    _changes.add(null);
    return saved;
  }

  Future<void> delete(AiConversation c) async {
    await save(
      c.copyWith(deleted: true, title: '', folder: '', messages: []),
      expectedRevision: c.revision,
    );
  }

  Future<Map<String, dynamic>> syncSnapshot() async {
    if (!await syncEnabled) throw StateError('Chat sync is disabled.');
    final size = await database
        .customSelect(
          'SELECT count(*) AS n, coalesce(sum(length(CAST(payload AS BLOB))),0) AS bytes FROM conversations WHERE shared=1',
        )
        .getSingle();
    if (size.read<int>('n') > 1000 ||
        size.read<int>('bytes') > 32 * 1024 * 1024 - 4096) {
      throw const AiChatSyncLimit();
    }
    final rows = await database
        .customSelect('SELECT payload FROM conversations WHERE shared=1')
        .get();
    return {
      'version': 1,
      'conversations': rows
          .map(
            (r) => AiConversation.fromJson(
              jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
            ).toJson(sync: true),
          )
          .toList(),
    };
  }

  bool _dominates(Map<String, int> a, Map<String, int> b) =>
      b.entries.every((e) => (a[e.key] ?? 0) >= e.value);

  /// Vector clocks distinguish stale snapshots from concurrent offline edits.
  /// Concurrent versions keep a deterministic conflict copy; deletions take precedence.
  Future<void> mergeSync(Map<String, dynamic> snapshot) async {
    if (!await syncEnabled) throw StateError('Chat sync is disabled.');
    if (snapshot['version'] != 1 ||
        (snapshot['conversations'] as List).length > 1000 ||
        utf8.encode(jsonEncode(snapshot)).length > 32 * 1024 * 1024) {
      throw const FormatException('Invalid chat sync batch.');
    }
    final incoming = (snapshot['conversations'] as List)
        .map(
          (j) => AiConversation.fromJson(
            Map<String, dynamic>.from(j as Map)..remove('profileId'),
          ),
        )
        .toList();
    await database.transaction(() async {
      for (final remote in incoming) {
        if (!remote.shareWithDevices || remote.clock.isEmpty) {
          throw const FormatException('Invalid shared conversation.');
        }
        final local = await get(remote.id);
        if (local == null) {
          await _write(remote);
          continue;
        }
        if (!local.shareWithDevices || _dominates(local.clock, remote.clock)) {
          continue;
        }
        if (_dominates(remote.clock, local.clock)) {
          await _write(remote.copyWith(profileId: local.profileId));
          continue;
        }
        final remoteWins = remote.deleted != local.deleted
            ? remote.deleted
            : remote.revision != local.revision
            ? remote.revision > local.revision
            : remote.origin.compareTo(local.origin) > 0;
        final winner = remoteWins ? remote : local;
        final loser = remoteWins ? local : remote;
        final clock = {...local.clock};
        for (final e in remote.clock.entries) {
          if (e.value > (clock[e.key] ?? 0)) clock[e.key] = e.value;
        }
        if (!winner.deleted) {
          final conflictId = sha256
              .convert(
                utf8.encode('${remote.id}:${loser.revision}:${loser.origin}'),
              )
              .toString();
          await _write(
            loser.copyWith(
              id: conflictId,
              title:
                  '${loser.title.substring(0, loser.title.length.clamp(0, 175))} (conflict copy)',
            ),
          );
        }
        await _write(winner.copyWith(clock: clock, profileId: local.profileId));
      }
    });
    _changes.add(null);
  }

  String export(AiConversation c, String format) {
    if (format == 'json') {
      return const JsonEncoder.withIndent('  ').convert(c.toJson());
    }
    if (!['md', 'txt'].contains(format)) {
      throw ArgumentError('Unsupported chat export format.');
    }
    final out = StringBuffer(
      format == 'md' ? '# ${c.title}\n\n' : '${c.title}\n\n',
    );
    for (final m in c.messages) {
      out.writeln(
        '${format == 'md' ? '## ' : ''}${m.message.role.name} (${m.state.name})',
      );
      out.writeln(m.message.text);
      for (final a in m.message.attachments) {
        out.writeln('[Attachment: ${a.name ?? a.id} · ${a.mimeType}]');
      }
      out.writeln();
    }
    return out.toString();
  }

  Future<void> close() async {
    await _changes.close();
    await database.close();
  }
}

Future<AiChatStore>? _shared;
Future<AiChatStore> sharedAiChatStore() => _shared ??= Future.value(
  AiChatStore(AiChatDatabase(driftDatabase(name: 'dayark_ai_chat_v1'))),
);
