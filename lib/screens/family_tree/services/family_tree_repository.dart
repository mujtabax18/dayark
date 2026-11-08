import '../../../services/db/drift_database.dart';

import '../../../services/database_service.dart';
import '../models/family_tree_models.dart';
import 'family_tree_media_service.dart';

class FamilyTreeRepository {
  FamilyTreeRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  Future<List<FamilyTree>> getTrees() async {
    final db = await _db;
    final rows = await db.query('family_trees', orderBy: 'updated_at DESC, name COLLATE NOCASE');
    return rows.map(FamilyTree.fromMap).toList();
  }

  Future<FamilyTree?> getTree(int treeId) async {
    final db = await _db;
    final rows = await db.query('family_trees', where: 'id = ?', whereArgs: [treeId], limit: 1);
    return rows.isEmpty ? null : FamilyTree.fromMap(rows.first);
  }

  Future<int> createTree({required String name, String description = ''}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return db.insert('family_trees', {
      'name': name.trim(),
      'description': description.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Creates a tree with its starting person in one transaction. The image is
  /// copied into the same private tree folder used by the existing member form.
  Future<int> createTreeWithFirstMember({
    required String name,
    required String firstMemberName,
    String description = '',
    String? imageSourcePath,
  }) async {
    final cleanedName = firstMemberName.trim();
    if (name.trim().isEmpty || cleanedName.isEmpty) {
      throw ArgumentError('A tree name and a starting person are required.');
    }
    final db = await _db;
    int? createdTreeId;
    try {
      return await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        final treeId = await txn.insert('family_trees', {
          'name': name.trim(),
          'description': description.trim(),
          'created_at': now,
          'updated_at': now,
        });
        createdTreeId = treeId;
        String? imagePath;
        if (imageSourcePath != null) {
          imagePath = await FamilyTreeMediaService.copyImage(
            treeId: treeId,
            sourcePath: imageSourcePath,
            category: 'members',
          );
        }
        final nameParts = _splitPersonName(cleanedName);
        await txn.insert('family_members', {
          'tree_id': treeId,
          'first_name': nameParts.$1,
          'last_name': nameParts.$2,
          'profile_image_path': imagePath,
          'created_at': now,
          'updated_at': now,
        });
        return treeId;
      });
    } catch (_) {
      if (createdTreeId != null) {
        await FamilyTreeMediaService.deleteTreeDirectory(createdTreeId!);
      }
      rethrow;
    }
  }

  /// Name-only creation is intentionally supported so no extra profile fields
  /// are required to grow a family tree. Member + link commit atomically.
  Future<int> createRelative({
    required int treeId,
    required int anchorMemberId,
    required String fullName,
    required String role,
    String? imageSourcePath,
    bool shareChildrenWithSpouses = true,
    bool shareParentsWithSiblings = true,
  }) async {
    if (fullName.trim().isEmpty) throw ArgumentError('Enter a name.');
    final db = await _db;
    String? copiedImagePath;
    try {
      if (imageSourcePath != null) {
        copiedImagePath = await FamilyTreeMediaService.copyImage(
          treeId: treeId,
          sourcePath: imageSourcePath,
          category: 'members',
        );
      }
      return await db.transaction((txn) async {
        final validAnchor = await txn.query('family_members',
            columns: ['id'], where: 'id = ? AND tree_id = ?',
            whereArgs: [anchorMemberId, treeId], limit: 1);
        if (validAnchor.isEmpty) throw StateError('The selected person is no longer available.');
        final nameParts = _splitPersonName(fullName);
        final now = DateTime.now().toIso8601String();
        final memberId = await txn.insert('family_members', {
          'tree_id': treeId,
          'first_name': nameParts.$1,
          'last_name': nameParts.$2,
          'profile_image_path': copiedImagePath,
          'created_at': now,
          'updated_at': now,
        });
        final link = relationshipForRole(
          anchorMemberId: anchorMemberId, relativeMemberId: memberId, role: role,
        );
        await _saveRelationshipInTransaction(
          txn, treeId: treeId, from: link.$1, to: link.$2,
          type: link.$3, shareChildrenWithSpouses: shareChildrenWithSpouses,
          shareParentsWithSiblings: shareParentsWithSiblings,
          siblingParentSourceMemberId: anchorMemberId,
          timestamp: now,
        );
        return memberId;
      });
    } catch (_) {
      await FamilyTreeMediaService.deleteFile(copiedImagePath);
      rethrow;
    }
  }

  /// The role is always described relative to the node the user clicked.
  /// Parent links remain directed parent -> child in the existing schema.
  static (int, int, String) relationshipForRole({
    required int anchorMemberId,
    required int relativeMemberId,
    required String role,
  }) {
    var from = anchorMemberId;
    var to = relativeMemberId;
    String type;
    switch (role) {
      case 'parent':
        from = relativeMemberId;
        to = anchorMemberId;
        type = 'parent';
        break;
      case 'child':
        type = 'parent';
        break;
      case 'guardian':
        from = relativeMemberId;
        to = anchorMemberId;
        type = 'guardian';
        break;
      case 'ward':
        type = 'guardian';
        break;
      case 'spouse':
      case 'partner':
      case 'sibling':
      case 'other':
        type = role;
        break;
      default:
        throw ArgumentError('Unsupported family relationship: $role');
    }
    if ((type == 'spouse' || type == 'partner' || type == 'sibling' || type == 'other') && from > to) {
      final swap = from;
      from = to;
      to = swap;
    }
    return (from, to, type);
  }

  static (String, String) _splitPersonName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.skip(1).join(' '));
  }

  Future<void> updateTree({
    required int treeId,
    required String name,
    required String description,
    String? coverImagePath,
  }) async {
    final db = await _db;
    await db.update(
      'family_trees',
      {
        'name': name.trim(),
        'description': description.trim(),
        'cover_image_path': coverImagePath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [treeId],
    );
  }

  Future<void> deleteTree(FamilyTree tree) async {
    final db = await _db;
    await db.delete('family_trees', where: 'id = ?', whereArgs: [tree.id]);
    await FamilyTreeMediaService.deleteTreeDirectory(tree.id);
  }

  Future<List<FamilyMember>> getMembers(int treeId) async {
    final db = await _db;
    final rows = await db.query(
      'family_members',
      where: 'tree_id = ?',
      whereArgs: [treeId],
      orderBy: 'first_name COLLATE NOCASE, last_name COLLATE NOCASE, id',
    );
    final photoRows = await db.query('family_member_photos',
        where: 'tree_id = ?', whereArgs: [treeId], orderBy: 'id');
    final photos = <int, List<FamilyPhoto>>{};
    for (final row in photoRows) {
      photos.putIfAbsent(row['member_id'] as int, () => []).add(FamilyPhoto.fromMap(row));
    }
    return rows.map((row) => FamilyMember.fromMap(row,
        photos: photos[row['id'] as int] ?? const [])).toList();
  }

  Future<List<FamilyPhoto>> getMemberPhotos(int memberId) async {
    final db = await _db;
    final rows = await db.query('family_member_photos',
        where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id');
    return rows.map(FamilyPhoto.fromMap).toList();
  }

  /// Copy first, then record all gallery images in one database transaction.
  /// If any step fails, don't leave half-imported photos in the database.
  Future<void> addMemberPhotos({
    required int treeId,
    required int memberId,
    required List<String> sourcePaths,
  }) async {
    if (sourcePaths.isEmpty) return;
    final db = await _db;
    final copied = <String>[];
    try {
      for (final path in sourcePaths.toSet()) {
        copied.add(await FamilyTreeMediaService.copyImage(
          treeId: treeId, sourcePath: path, category: 'members',
        ));
      }
      await db.transaction((txn) async {
        final rows = await txn.query('family_members', columns: ['id'],
          where: 'id = ? AND tree_id = ?', whereArgs: [memberId, treeId]);
        if (rows.isEmpty) throw StateError('Person no longer exists.');
        final now = DateTime.now().toIso8601String();
        for (final path in copied) {
          await txn.insert('family_member_photos', {
            'tree_id': treeId, 'member_id': memberId,
            'image_path': path, 'created_at': now,
          });
        }
        await txn.update('family_members', {'updated_at': now},
            where: 'id = ?', whereArgs: [memberId]);
      });
    } catch (_) {
      for (final path in copied) { await FamilyTreeMediaService.deleteFile(path); }
      rethrow;
    }
  }

  Future<void> setMemberCoverPhoto({required int memberId, required String path}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('family_members',
          where: 'id = ?', whereArgs: [memberId], limit: 1);
      if (rows.isEmpty) throw StateError('Person no longer exists.');
      final old = rows.first['profile_image_path'] as String?;
      if (old == path) return;
      // Preserve the previous cover in the gallery unless it was already there.
      if (old != null && old.isNotEmpty) {
        final found = await txn.query('family_member_photos', columns: ['id'],
          where: 'member_id = ? AND image_path = ?',
          whereArgs: [memberId, old], limit: 1);
        if (found.isEmpty) {
          await txn.insert('family_member_photos', {
            'tree_id': rows.first['tree_id'], 'member_id': memberId,
            'image_path': old, 'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
      await txn.update('family_members', {
        'profile_image_path': path,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [memberId]);
    });
  }

  Future<void> deleteMemberPhoto({required int memberId, required FamilyPhoto photo}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('family_member_photos', columns: ['id'],
          where: 'id = ? AND member_id = ?', whereArgs: [photo.id, memberId]);
      if (rows.isEmpty) return;
      await txn.delete('family_member_photos',
          where: 'id = ? AND member_id = ?', whereArgs: [photo.id, memberId]);
      await txn.update('family_members', {
        'profile_image_path': null,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ? AND profile_image_path = ?',
         whereArgs: [memberId, photo.path]);
    });
    await FamilyTreeMediaService.deleteFile(photo.path);
  }

  Future<int> createMember({
    required int treeId,
    required Map<String, Object?> values,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return db.insert('family_members', {
      ...values,
      'tree_id': treeId,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateMember({
    required int memberId,
    required Map<String, Object?> values,
  }) async {
    final db = await _db;
    await db.update(
      'family_members',
      {...values, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [memberId],
    );
  }

  Future<void> deleteMember(FamilyMember member) async {
    final db = await _db;
    final deletedPaths = <String>{...member.imagePaths};
    await db.transaction((txn) async {
      // Keep shared albums: transfer their primary link to another tagged
      // person before deleting this member (legacy FK is ON DELETE CASCADE).
      final primaryMemories = await txn.query('family_memories',
          where: 'member_id = ?', whereArgs: [member.id]);
      for (final row in primaryMemories) {
        final memoryId = row['id'] as int;
        final others = await txn.query('family_memory_people',
          columns: ['member_id'], where: 'memory_id = ? AND member_id != ?',
          whereArgs: [memoryId, member.id], limit: 1);
        if (others.isNotEmpty) {
          await txn.update('family_memories',
              {'member_id': others.first['member_id']},
              where: 'id = ?', whereArgs: [memoryId]);
        } else {
          final cover = row['media_path'] as String?;
          if (cover != null) deletedPaths.add(cover);
          final photos = await txn.query('family_memory_photos',
              columns: ['image_path'], where: 'memory_id = ?', whereArgs: [memoryId]);
          deletedPaths.addAll(photos.map((photo) => photo['image_path'] as String));
          await txn.delete('family_memories', where: 'id = ?', whereArgs: [memoryId]);
        }
      }
      await txn.delete('family_members', where: 'id = ?', whereArgs: [member.id]);
    });
    for (final path in deletedPaths) {
      await FamilyTreeMediaService.deleteFile(path);
    }
  }

  Future<List<FamilyRelationship>> getRelationships(int treeId) async {
    final db = await _db;
    final rows = await db.query(
      'family_relationships',
      where: 'tree_id = ?',
      whereArgs: [treeId],
      orderBy: 'id',
    );
    return rows.map(FamilyRelationship.fromMap).toList();
  }

  /// Add a relationship without duplicating member records. When enabled,
  /// spouse connections share both partners' existing children, a parent
  /// connection connects a child to that parent's existing spouse(s), and a
  /// sibling connection can share the selected person's existing parents.
  /// All affected links are committed atomically (including existing people).
  Future<void> addRelationship({
    required int treeId,
    required int fromMemberId,
    required int toMemberId,
    required String type,
    bool shareChildrenWithSpouses = true,
    bool shareParentsWithSiblings = true,
    int? siblingParentSourceMemberId,
  }) async {
    if (fromMemberId == toMemberId) {
      throw ArgumentError('A person cannot be related to themselves.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final participants = await txn.query('family_members',
        columns: ['id'], where: 'tree_id = ? AND id IN (?, ?)',
        whereArgs: [treeId, fromMemberId, toMemberId]);
      if (participants.length != 2) {
        throw StateError('Both people must belong to this family tree.');
      }
      await _saveRelationshipInTransaction(
        txn, treeId: treeId, from: fromMemberId, to: toMemberId,
        type: type, shareChildrenWithSpouses: shareChildrenWithSpouses,
        shareParentsWithSiblings: shareParentsWithSiblings,
        siblingParentSourceMemberId: siblingParentSourceMemberId ?? fromMemberId,
        timestamp: DateTime.now().toIso8601String(),
      );
    });
  }

  /// A single transaction with one relationship read also guards against
  /// duplicate parent links and cycles introduced by shared relatives.
  Future<void> _saveRelationshipInTransaction(
    Database txn, {
    required int treeId,
    required int from,
    required int to,
    required String type,
    required bool shareChildrenWithSpouses,
    required bool shareParentsWithSiblings,
    required int siblingParentSourceMemberId,
    required String timestamp,
  }) async {
    if (from == to) throw ArgumentError('A person cannot be related to themselves.');
    // Keep the selected sibling as the source even when the undirected link
    // must be sorted for storage (i.e. anchor ID > sibling ID).
    if (type == 'sibling' && shareParentsWithSiblings &&
        siblingParentSourceMemberId != from && siblingParentSourceMemberId != to) {
      throw ArgumentError('The source sibling must be one of the connected people.');
    }
    if (type == 'spouse' || type == 'partner' ||
        type == 'sibling' || type == 'other') {
      if (from > to) {
        final old = from;
        from = to;
        to = old;
      }
    }

    // Query once and operate on integer IDs, never create another person.
    final existing = await txn.query('family_relationships',
      columns: ['from_member_id', 'to_member_id', 'relationship_type'],
      where: 'tree_id = ?', whereArgs: [treeId]);
    final keys = <String>{};
    final childrenByParent = <int, Set<int>>{};
    final parentsByChild = <int, Set<int>>{};
    final spouses = <int, Set<int>>{};
    for (final record in existing) {
      final a = record['from_member_id'] as int;
      final b = record['to_member_id'] as int;
      final relationship = record['relationship_type'] as String;
      keys.add('$relationship:$a:$b');
      if (relationship == 'parent') {
        childrenByParent.putIfAbsent(a, () => <int>{}).add(b);
        parentsByChild.putIfAbsent(b, () => <int>{}).add(a);
      } else if (relationship == 'spouse') {
        spouses.putIfAbsent(a, () => <int>{}).add(b);
        spouses.putIfAbsent(b, () => <int>{}).add(a);
      }
    }

    bool hasPath(int first, int target) {
      final seen = <int>{};
      final pending = <int>[first];
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        if (current == target) return true;
        if (seen.add(current)) {
          pending.addAll(childrenByParent[current] ?? const <int>{});
        }
      }
      return false;
    }

    Future<void> writeLink(int a, int b, String relationship) async {
      if (a == b) {
        throw StateError('A person cannot be their own relative.');
      }
      final key = '$relationship:$a:$b';
      if (keys.contains(key)) return;
      if (relationship == 'parent') {
        if (hasPath(b, a)) {
          throw StateError('This connection would create a parent cycle. '
              'Turn off automatic parent/child sharing or review the existing links.');
        }
      }
      await txn.insert('family_relationships', {
        'tree_id': treeId,
        'from_member_id': a,
        'to_member_id': b,
        'relationship_type': relationship,
        'created_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      keys.add(key);
      if (relationship == 'parent') {
        childrenByParent.putIfAbsent(a, () => <int>{}).add(b);
        parentsByChild.putIfAbsent(b, () => <int>{}).add(a);
      }
    }

    await writeLink(from, to, type);
    if (type == 'sibling' && shareParentsWithSiblings) {
      // Reuse the existing parent IDs of the person whose node was selected.
      // Never create or clone a parent/member. The graph can have one child
      // with multiple parent links. Duplicate links and ancestry cycles are
      // handled by writeLink, and the complete operation is transactional.
      final siblingId = siblingParentSourceMemberId == from ? to : from;
      final parentIds = <int>{
        ...(parentsByChild[siblingParentSourceMemberId] ?? const <int>{}),
      };
      for (final parentId in parentIds) {
        await writeLink(parentId, siblingId, 'parent');
      }
    }
    if (shareChildrenWithSpouses) {
      if (type == 'spouse') {
        // The new spouse shares existing children from BOTH sides by default.
        final sharedChildren = <int>{
          ...(childrenByParent[from] ?? const <int>{}),
          ...(childrenByParent[to] ?? const <int>{}),
        };
        for (final childId in sharedChildren) {
          await writeLink(from, childId, 'parent');
          await writeLink(to, childId, 'parent');
        }
      } else if (type == 'parent') {
        // Adding a child to either partner links the SAME child to the other
        // spouse(s), not a duplicate member or a second child node.
        for (final spouseId in spouses[from] ?? const <int>{}) {
          await writeLink(spouseId, to, 'parent');
        }
      }
    }
    await txn.update('family_trees', {'updated_at': timestamp},
      where: 'id = ?', whereArgs: [treeId]);
  }

  Future<void> deleteRelationship(int relationshipId) async {
    final db = await _db;
    await db.delete('family_relationships', where: 'id = ?', whereArgs: [relationshipId]);
  }

  Future<List<FamilyMemory>> getMemories(int treeId) async {
    final db = await _db;
    final rows = await db.query('family_memories', where: 'tree_id = ?',
      whereArgs: [treeId], orderBy: 'COALESCE(memory_date, created_at) DESC, id DESC');
    final photoRows = await db.query('family_memory_photos',
        where: 'tree_id = ?', whereArgs: [treeId], orderBy: 'id');
    final participants = await db.rawQuery('''
SELECT p.memory_id, p.member_id FROM family_memory_people p
JOIN family_memories m ON m.id = p.memory_id WHERE m.tree_id = ?
''', [treeId]);
    final photos = <int, List<FamilyPhoto>>{};
    final byMemory = <int, List<int>>{};
    for (final row in photoRows) {
      photos.putIfAbsent(row['memory_id'] as int, () => []).add(FamilyPhoto.fromMap(row));
    }
    for (final row in participants) {
      byMemory.putIfAbsent(row['memory_id'] as int, () => []).add(row['member_id'] as int);
    }
    return rows.map((row) => FamilyMemory.fromMap(row,
      photos: photos[row['id'] as int] ?? const [],
      participantIds: byMemory[row['id'] as int] ?? const [],
    )).toList();
  }

  /// Creates a dated, titled album with optional photo set and tagged people.
  /// The first image becomes the backwards-compatible cover image.
  Future<int> createMemory({
    required int treeId,
    required int? memberId,
    required String title,
    required String description,
    DateTime? memoryDate,
    String? mediaPath,
    List<String> imageSourcePaths = const [],
    List<int> participantIds = const [],
    int? eventId,
  }) async {
    final db = await _db;
    final copied = await _copyMemoryImages(treeId, imageSourcePaths);
    try {
      return await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        if (eventId != null) {
          final events = await txn.query('life_events', columns: ['id'],
              where: 'id = ? AND tree_id = ?', whereArgs: [eventId, treeId], limit: 1);
          if (events.isEmpty) throw StateError('The selected event does not belong to this archive.');
        }
        final cover = mediaPath ?? (copied.isNotEmpty ? copied.first : null);
        final id = await txn.insert('family_memories', {
          'tree_id': treeId,
          'member_id': memberId,
          'title': title.trim(),
          'description': description.trim(),
          'memory_date': memoryDate?.toIso8601String(),
          'event_id': eventId,
          'media_type': cover == null && copied.isEmpty ? 'text' : 'image',
          'media_path': cover,
          'created_at': now,
          'updated_at': now,
        });
        for (final path in (mediaPath == null && copied.isNotEmpty)
            ? copied.skip(1) : copied) {
          await txn.insert('family_memory_photos', {
            'tree_id': treeId, 'memory_id': id,
            'image_path': path, 'created_at': now,
          });
        }
        await _saveMemoryPeople(txn, treeId, id, memberId, participantIds);
        return id;
      });
    } catch (_) {
      for (final path in copied) { await FamilyTreeMediaService.deleteFile(path); }
      rethrow;
    }
  }

  Future<void> updateMemory({
    required int memoryId,
    required int? memberId,
    required String title,
    required String description,
    DateTime? memoryDate,
    String? mediaPath,
    List<String> imageSourcePaths = const [],
    List<int> removedPhotoIds = const [],
    List<int> participantIds = const [],
    int? eventId,
  }) async {
    final db = await _db;
    final existing = await db.query('family_memories',
      where: 'id = ?', whereArgs: [memoryId], limit: 1);
    if (existing.isEmpty) throw StateError('Album no longer exists.');
    final treeId = existing.first['tree_id'] as int;
    final oldCover = existing.first['media_path'] as String?;
    final copied = await _copyMemoryImages(treeId, imageSourcePaths);
    final removedPaths = <String>[];
    try {
      await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        if (eventId != null) {
          final events = await txn.query('life_events', columns: ['id'],
              where: 'id = ? AND tree_id = ?', whereArgs: [eventId, treeId], limit: 1);
          if (events.isEmpty) throw StateError('The selected event does not belong to this archive.');
        }
        // Remove only belonging-to-this-album entries. Promote one remaining
        // photo to the cover if its previous cover was removed.
        final existingPhotos = await txn.query('family_memory_photos',
          where: 'memory_id = ?', whereArgs: [memoryId], orderBy: 'id');
        final removed = removedPhotoIds.toSet();
        final retained = existingPhotos.where((row) => !removed.contains(row['id'] as int)).toList();
        for (final row in existingPhotos.where((row) => removed.contains(row['id'] as int))) {
          await txn.delete('family_memory_photos', where: 'id = ?', whereArgs: [row['id']]);
          removedPaths.add(row['image_path'] as String);
        }
        var cover = mediaPath;
        if (cover == null) {
          if (retained.isNotEmpty) {
            final promoted = retained.first;
            cover = promoted['image_path'] as String;
            await txn.delete('family_memory_photos',
                where: 'id = ?', whereArgs: [promoted['id']]);
          } else if (copied.isNotEmpty) {
            cover = copied.first;
          }
        }
        final photosToInsert = copied.isNotEmpty && cover == copied.first ? copied.skip(1) : copied;
        for (final path in photosToInsert) {
          await txn.insert('family_memory_photos', {
            'tree_id': treeId, 'memory_id': memoryId,
            'image_path': path, 'created_at': now,
          });
        }
        await txn.update('family_memories', {
          'member_id': memberId,
          'title': title.trim(),
          'description': description.trim(),
          'memory_date': memoryDate?.toIso8601String(),
          'event_id': eventId,
          'media_type': cover == null ? 'text' : 'image',
          'media_path': cover,
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [memoryId]);
        await _saveMemoryPeople(txn, treeId, memoryId, memberId, participantIds);
      });
    } catch (_) {
      for (final path in copied) { await FamilyTreeMediaService.deleteFile(path); }
      rethrow;
    }
    if (oldCover != null && oldCover != mediaPath &&
        !removedPaths.contains(oldCover)) {
      // Check the final cover: the legacy image is no longer referenced.
      final after = await db.query('family_memories', columns: ['media_path'],
          where: 'id = ?', whereArgs: [memoryId], limit: 1);
      if (after.isNotEmpty && after.first['media_path'] != oldCover) {
        await FamilyTreeMediaService.deleteFile(oldCover);
      }
    }
    for (final path in removedPaths) {
      await FamilyTreeMediaService.deleteFile(path);
    }
  }

  Future<List<String>> _copyMemoryImages(int treeId, List<String> sources) async {
    final copied = <String>[];
    try {
      for (final path in sources.toSet()) {
        copied.add(await FamilyTreeMediaService.copyImage(
          treeId: treeId, sourcePath: path, category: 'memories',
        ));
      }
      return copied;
    } catch (_) {
      for (final path in copied) { await FamilyTreeMediaService.deleteFile(path); }
      rethrow;
    }
  }

  Future<void> _saveMemoryPeople(Database txn, int treeId, int memoryId,
      int? memberId, List<int> participantIds) async {
    final otherIds = participantIds.toSet()..remove(memberId);
    // Never allow people from another tree to be associated with this album.
    if (memberId != null) otherIds.add(memberId);
    if (otherIds.isNotEmpty) {
      final existing = await txn.query('family_members', columns: ['id'],
        where: 'tree_id = ? AND id IN (${List.filled(otherIds.length, '?').join(',')})',
        whereArgs: [treeId, ...otherIds]);
      if (existing.length != otherIds.length) {
        throw StateError('A tagged family member no longer exists.');
      }
    }
    otherIds.remove(memberId);
    await txn.delete('family_memory_people', where: 'memory_id = ?', whereArgs: [memoryId]);
    for (final id in otherIds) {
      await txn.insert('family_memory_people', {'memory_id': memoryId, 'member_id': id});
    }
  }

  Future<void> deleteMemory(FamilyMemory memory) async {
    final db = await _db;
    await db.delete('family_memories', where: 'id = ?', whereArgs: [memory.id]);
    for (final path in memory.imagePaths.toSet()) {
      await FamilyTreeMediaService.deleteFile(path);
    }
  }
}
