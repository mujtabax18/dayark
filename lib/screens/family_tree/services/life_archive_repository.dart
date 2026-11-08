import '../../../services/database_service.dart';
import '../../../services/db/drift_database.dart';
import '../models/life_archive_models.dart';

/// Local-first life connections and events. All writes validate their tree,
/// keeping two different archives from accidentally sharing people or albums.
class LifeArchiveRepository {
  LifeArchiveRepository({DatabaseService? databaseService})
      : _service = databaseService ?? DatabaseService();
  final DatabaseService _service;
  Future<Database> get _db => _service.database;

  Future<void> _validatePeople(Database db, int treeId, Set<int> ids) async {
    if (ids.isEmpty) return;
    final rows = await db.query('family_members', columns: ['id'],
      where: 'tree_id = ? AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: [treeId, ...ids]);
    if (rows.length != ids.length) throw StateError('One or more people do not belong to this archive.');
  }

  Future<List<LifeConnection>> getConnections(int treeId) async {
    final db = await _db;
    final rows = await db.query('life_connections', where: 'tree_id = ?',
      whereArgs: [treeId], orderBy: 'created_at DESC, id DESC');
    return rows.map(LifeConnection.fromMap).toList();
  }

  Future<int> saveConnection({required int treeId, required int fromMemberId,
    required int toMemberId, required String type, String label = '',
    String notes = '', DateTime? startedAt, DateTime? endedAt, int? id}) async {
    if (fromMemberId == toMemberId) throw ArgumentError('Choose two different people.');
    if (!LifeConnection.types.containsKey(type)) throw ArgumentError('Unsupported connection type.');
    if (type == 'custom' && label.trim().isEmpty) throw ArgumentError('Enter a custom connection name.');
    if (startedAt != null && endedAt != null && endedAt.isBefore(startedAt)) {
      throw ArgumentError('The end date cannot precede the start date.');
    }
    final db = await _db;
    await _validatePeople(db, treeId, {fromMemberId, toMemberId});
    var from = fromMemberId, to = toMemberId;
    if (!LifeConnection.directedTypes.contains(type) && from > to) {
      from = toMemberId;
      to = fromMemberId;
    }
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'tree_id': treeId, 'from_member_id': from, 'to_member_id': to,
      'connection_type': type, 'custom_label': type == 'custom' ? label.trim() : '',
      'notes': notes.trim(), 'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(), 'updated_at': now,
    };
    if (id == null) {
      return db.insert('life_connections', {...values, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.abort);
    }
    final changed = await db.update('life_connections', values,
      where: 'id = ? AND tree_id = ?', whereArgs: [id, treeId]);
    if (changed == 0) throw StateError('Connection no longer exists.');
    return id;
  }

  Future<void> deleteConnection(int treeId, int id) async {
    final db = await _db;
    await db.delete('life_connections', where: 'tree_id = ? AND id = ?',
      whereArgs: [treeId, id]);
  }

  Future<List<LifeEvent>> getEvents(int treeId) async {
    final db = await _db;
    final rows = await db.query('life_events', where: 'tree_id = ?',
      whereArgs: [treeId], orderBy: 'COALESCE(event_date, created_at) DESC, id DESC');
    final attendees = await db.rawQuery('''
SELECT ep.event_id, ep.member_id FROM life_event_people ep
JOIN life_events e ON e.id = ep.event_id WHERE e.tree_id = ?
''', [treeId]);
    final linkedAlbums = await db.rawQuery('''
SELECT event_id, COUNT(*) AS count FROM family_memories
WHERE tree_id = ? AND event_id IS NOT NULL GROUP BY event_id
''', [treeId]);
    final people = <int, List<int>>{};
    for (final row in attendees) {
      people.putIfAbsent(row['event_id'] as int, () => []).add(row['member_id'] as int);
    }
    final counts = {for (final row in linkedAlbums)
      row['event_id'] as int: (row['count'] as int?) ?? 0};
    return rows.map((row) => LifeEvent.fromMap(row,
      participantIds: people[row['id'] as int] ?? const [],
      albumCount: counts[row['id'] as int] ?? 0)).toList();
  }

  Future<int> saveEvent({required int treeId, required String title,
    required String type, required String location, required String description,
    DateTime? eventDate, List<int> participantIds = const [], int? id}) async {
    if (title.trim().isEmpty) throw ArgumentError('Event title is required.');
    if (!LifeEvent.types.containsKey(type)) throw ArgumentError('Unsupported event type.');
    final db = await _db;
    await _validatePeople(db, treeId, participantIds.toSet());
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final fields = <String, Object?>{
        'tree_id': treeId, 'title': title.trim(), 'event_type': type,
        'location': location.trim(), 'description': description.trim(),
        'event_date': eventDate?.toIso8601String(), 'updated_at': now,
      };
      final eventId = id == null
          ? await txn.insert('life_events', {...fields, 'created_at': now})
          : id;
      if (id != null) {
        final updated = await txn.update('life_events', fields,
          where: 'id = ? AND tree_id = ?', whereArgs: [id, treeId]);
        if (updated == 0) throw StateError('Event no longer exists.');
      }
      await txn.delete('life_event_people', where: 'event_id = ?', whereArgs: [eventId]);
      for (final memberId in participantIds.toSet()) {
        await txn.insert('life_event_people', {'event_id': eventId, 'member_id': memberId});
      }
      return eventId;
    });
  }

  Future<void> deleteEvent(int treeId, int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Clear album links explicitly: old database migrations add event_id
      // without a foreign-key clause, even though new installs have one.
      await txn.update('family_memories', {'event_id': null},
        where: 'tree_id = ? AND event_id = ?', whereArgs: [treeId, id]);
      await txn.delete('life_event_people', where: 'event_id = ?', whereArgs: [id]);
      await txn.delete('life_events', where: 'tree_id = ? AND id = ?', whereArgs: [treeId, id]);
    });
  }
}
