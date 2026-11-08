import '../db/drift_database.dart';

import '../database_service.dart';

class GroceryService {
  GroceryService(this._databaseService);

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  Future<List<Map<String, dynamic>>> getGroceryTitles() async {
    final db = await _db;
    await refreshHouseholdAlerts();
    return db.rawQuery('''
      SELECT
        gt.*,
        COUNT(gi.id) AS item_count,
        COALESCE(SUM(CASE WHEN gi.status = 1 THEN 1 ELSE 0 END), 0) AS completed_count,
        COALESCE(SUM(CASE WHEN gi.status = 0 THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE
          WHEN gi.status = 0
           AND gi.due_at IS NOT NULL
           AND gi.due_at != ''
           AND datetime(gi.due_at) < datetime('now', 'localtime')
          THEN 1 ELSE 0 END), 0) AS overdue_count
      FROM grocery_titles gt
      LEFT JOIN grocery_items gi ON gi.grocery_id = gt.id
      WHERE COALESCE(gt.status, 'active') != 'archived'
      GROUP BY gt.id
      ORDER BY
        CASE WHEN COALESCE(gt.status, 'active') = 'active' THEN 0 ELSE 1 END,
        COALESCE(gt.plan_date, gt.created_at, '') DESC,
        gt.position ASC,
        gt.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getGroceryPlan(int groceryId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        gt.*,
        COUNT(gi.id) AS item_count,
        COALESCE(SUM(CASE WHEN gi.status = 1 THEN 1 ELSE 0 END), 0) AS completed_count,
        COALESCE(SUM(CASE WHEN gi.status = 0 THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE
          WHEN gi.status = 0
           AND gi.due_at IS NOT NULL
           AND gi.due_at != ''
           AND datetime(gi.due_at) < datetime('now', 'localtime')
          THEN 1 ELSE 0 END), 0) AS overdue_count
      FROM grocery_titles gt
      LEFT JOIN grocery_items gi ON gi.grocery_id = gt.id
      WHERE gt.id = ?
      GROUP BY gt.id
      LIMIT 1
    ''', [groceryId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> addGroceryTitle(String title) {
    return createGroceryPlan(
      title: title,
      description: '',
      planDate: DateTime.now(),
      planType: 'monthly',
      iconKey: 'basket-shopping',
      colorValue: 0xFF2E7D32,
      alertEnabled: false,
      alertMinutesBefore: 60,
    );
  }

  Future<int> createGroceryPlan({
    required String title,
    required String description,
    required DateTime planDate,
    DateTime? dueAt,
    required String planType,
    required String iconKey,
    required int colorValue,
    required bool alertEnabled,
    required int alertMinutesBefore,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt
            .subtract(Duration(minutes: alertMinutesBefore))
            .toIso8601String()
        : null;

    final id = await db.insert('grocery_titles', {
      'title': title.trim(),
      'description': description.trim(),
      'plan_date': _dateOnly(planDate),
      'due_at': dueAt?.toIso8601String(),
      'plan_type': planType,
      'icon_key': iconKey,
      'color_value': colorValue,
      'alert_enabled': alertEnabled ? 1 : 0,
      'alert_minutes_before': alertMinutesBefore,
      'reminder_at': reminderAt,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
      'position': 0,
    });

    await _logActivity(
      db,
      entityType: 'grocery_plan',
      entityId: id,
      action: 'created',
      newStatus: 'active',
      scheduledAt: dueAt,
      note: title.trim(),
    );
    await refreshHouseholdAlerts();
    return id;
  }

  Future<void> updateGroceryPlan({
    required int id,
    required String title,
    required String description,
    required DateTime planDate,
    DateTime? dueAt,
    required String planType,
    required String iconKey,
    required int colorValue,
    required bool alertEnabled,
    required int alertMinutesBefore,
  }) async {
    final db = await _db;
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt
            .subtract(Duration(minutes: alertMinutesBefore))
            .toIso8601String()
        : null;

    await db.update(
      'grocery_titles',
      {
        'title': title.trim(),
        'description': description.trim(),
        'plan_date': _dateOnly(planDate),
        'due_at': dueAt?.toIso8601String(),
        'plan_type': planType,
        'icon_key': iconKey,
        'color_value': colorValue,
        'alert_enabled': alertEnabled ? 1 : 0,
        'alert_minutes_before': alertMinutesBefore,
        'reminder_at': reminderAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logActivity(
      db,
      entityType: 'grocery_plan',
      entityId: id,
      action: 'updated',
      scheduledAt: dueAt,
      note: title.trim(),
    );
    await _deleteOpenAlertsForEntity(db, 'grocery_plan', id);
    await refreshHouseholdAlerts();
  }

  Future<void> archiveGroceryPlan(int id) async {
    final db = await _db;
    await db.update(
      'grocery_titles',
      {
        'status': 'archived',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _deleteOpenAlertsForEntity(db, 'grocery_plan', id);
    await _logActivity(
      db,
      entityType: 'grocery_plan',
      entityId: id,
      action: 'archived',
      newStatus: 'archived',
    );
  }

  Future<void> deleteGroceryTitle(int titleId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'household_alerts',
        where: "(entity_type = 'grocery_plan' AND entity_id = ?) OR "
            "(entity_type = 'grocery_item' AND entity_id IN "
            '(SELECT id FROM grocery_items WHERE grocery_id = ?))',
        whereArgs: [titleId, titleId],
      );
      await txn.delete(
        'household_activity_logs',
        where: "(entity_type = 'grocery_plan' AND entity_id = ?) OR "
            "(entity_type = 'grocery_item' AND entity_id IN "
            '(SELECT id FROM grocery_items WHERE grocery_id = ?))',
        whereArgs: [titleId, titleId],
      );
      await txn.delete('grocery_titles', where: 'id = ?', whereArgs: [titleId]);
    });
  }

  Future<List<Map<String, dynamic>>> getGroceryItems(int groceryId) async {
    final db = await _db;
    await refreshHouseholdAlerts();
    return db.query(
      'grocery_items',
      where: 'grocery_id = ?',
      whereArgs: [groceryId],
      orderBy: '''
        status ASC,
        CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
        CASE WHEN due_at IS NULL OR due_at = '' THEN 1 ELSE 0 END,
        due_at ASC,
        position ASC,
        id DESC
      ''',
    );
  }

  Future<List<Map<String, dynamic>>> getReusableGroceryItems(
    int targetGroceryId,
  ) async {
    final db = await _db;

    final currentRows = await db.query(
      'grocery_items',
      where: 'grocery_id = ?',
      whereArgs: [targetGroceryId],
    );
    final currentKeys = currentRows.map(_itemTemplateKey).toSet();

    final sourceRows = await db.rawQuery('''
      SELECT
        gi.*,
        gt.title AS source_plan_title,
        gt.plan_date AS source_plan_date
      FROM grocery_items gi
      LEFT JOIN grocery_titles gt ON gt.id = gi.grocery_id
      WHERE gi.grocery_id != ?
      ORDER BY
        COALESCE(gi.updated_at, gi.created_at, gi.date, '') DESC,
        gi.id DESC
    ''', [targetGroceryId]);

    // One reusable entry per item/type/unit combination. The most recently
    // updated record wins so edited quantity, notes and priority stay useful.
    final seenKeys = <String>{};
    final reusable = <Map<String, dynamic>>[];
    for (final row in sourceRows) {
      final key = _itemTemplateKey(row);
      if (key.isEmpty || !seenKeys.add(key)) continue;

      reusable.add({
        ...row,
        'source_item_id': _asInt(row['id']),
        'already_in_plan': currentKeys.contains(key) ? 1 : 0,
      });
    }

    return reusable;
  }

  Future<int> addExistingGroceryItemsToPlan({
    required int groceryId,
    required List<int> sourceItemIds,
  }) async {
    if (sourceItemIds.isEmpty) return 0;

    final db = await _db;
    final now = DateTime.now();
    var insertedCount = 0;

    await db.transaction((txn) async {
      final targetRows = await txn.query(
        'grocery_items',
        where: 'grocery_id = ?',
        whereArgs: [groceryId],
      );
      final existingKeys = targetRows.map(_itemTemplateKey).toSet();

      final positionRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) AS max_position '
        'FROM grocery_items WHERE grocery_id = ?',
        [groceryId],
      );
      var nextPosition = (_asInt(positionRows.first['max_position']) ?? -1) + 1;

      // Preserve the order selected by the user while avoiding duplicate IDs.
      final uniqueSourceIds = <int>[];
      final seenIds = <int>{};
      for (final id in sourceItemIds) {
        if (seenIds.add(id)) uniqueSourceIds.add(id);
      }

      for (final sourceItemId in uniqueSourceIds) {
        final rows = await txn.query(
          'grocery_items',
          where: 'id = ?',
          whereArgs: [sourceItemId],
          limit: 1,
        );
        if (rows.isEmpty) continue;

        final source = rows.first;
        final key = _itemTemplateKey(source);
        if (key.isEmpty || existingKeys.contains(key)) continue;

        await txn.insert('grocery_items', {
          // Copy reusable item details only.
          'name': source['name']?.toString().trim() ?? '',
          'item_type': source['item_type']?.toString() ?? 'general',
          'quantity': (source['quantity'] as num?)?.toDouble() ?? 1,
          'unit': source['unit']?.toString() ?? 'item',
          'notes': source['notes']?.toString().trim() ?? '',
          'priority': source['priority']?.toString() ?? 'normal',

          // Always create a fresh pending item for the destination plan.
          // Completion state, dates, alerts and activity history are not copied.
          'status': 0,
          'date': now.toIso8601String(),
          'grocery_id': groceryId,
          'due_at': null,
          'reminder_at': null,
          'alert_enabled': 0,
          'alert_minutes_before': 60,
          'completed_at': null,
          'completion_delay_minutes': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'position': nextPosition++,
          'closing_id': null,
        });

        // Intentionally do not call _logActivity here. The user asked for
        // item details only, without importing or generating item history.
        existingKeys.add(key);
        insertedCount++;
      }
    });

    if (insertedCount > 0) {
      await _syncPlanStatus(db, groceryId);
      await refreshHouseholdAlerts();
    }
    return insertedCount;
  }

  Future<int> addGroceryItem(
    int groceryId,
    String name,
    int status,
    String date,
  ) {
    return createGroceryItem(
      groceryId: groceryId,
      name: name,
      itemType: 'general',
      quantity: 1,
      unit: 'item',
      notes: '',
      priority: 'normal',
      dueAt: DateTime.tryParse(date),
      alertEnabled: false,
      alertMinutesBefore: 60,
      initialStatus: status,
    );
  }

  Future<int> createGroceryItem({
    required int groceryId,
    required String name,
    required String itemType,
    required double quantity,
    required String unit,
    required String notes,
    required String priority,
    DateTime? dueAt,
    required bool alertEnabled,
    required int alertMinutesBefore,
    int initialStatus = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt.subtract(Duration(minutes: alertMinutesBefore))
        : null;

    final id = await db.insert('grocery_items', {
      'name': name.trim(),
      'status': initialStatus,
      'date': now.toIso8601String(),
      'grocery_id': groceryId,
      'item_type': itemType,
      'quantity': quantity,
      'unit': unit,
      'notes': notes.trim(),
      'priority': priority,
      'due_at': dueAt?.toIso8601String(),
      'alert_enabled': alertEnabled ? 1 : 0,
      'alert_minutes_before': alertMinutesBefore,
      'reminder_at': reminderAt?.toIso8601String(),
      'completed_at': initialStatus == 1 ? now.toIso8601String() : null,
      'completion_delay_minutes':
          initialStatus == 1 ? _delayMinutes(dueAt, now) : 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'position': 0,
    });

    await _logActivity(
      db,
      entityType: 'grocery_item',
      entityId: id,
      action: 'created',
      newStatus: initialStatus == 1 ? 'completed' : 'pending',
      scheduledAt: dueAt,
      occurredAt: now,
      note: name.trim(),
    );
    await _syncPlanStatus(db, groceryId);
    await refreshHouseholdAlerts();
    return id;
  }

  Future<void> updateGroceryItem({
    required int id,
    required int groceryId,
    required String name,
    required String itemType,
    required double quantity,
    required String unit,
    required String notes,
    required String priority,
    DateTime? dueAt,
    required bool alertEnabled,
    required int alertMinutesBefore,
  }) async {
    final db = await _db;
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt
            .subtract(Duration(minutes: alertMinutesBefore))
            .toIso8601String()
        : null;

    await db.update(
      'grocery_items',
      {
        'name': name.trim(),
        'item_type': itemType,
        'quantity': quantity,
        'unit': unit,
        'notes': notes.trim(),
        'priority': priority,
        'due_at': dueAt?.toIso8601String(),
        'alert_enabled': alertEnabled ? 1 : 0,
        'alert_minutes_before': alertMinutesBefore,
        'reminder_at': reminderAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _deleteOpenAlertsForEntity(db, 'grocery_item', id);
    await _logActivity(
      db,
      entityType: 'grocery_item',
      entityId: id,
      action: 'updated',
      scheduledAt: dueAt,
      note: name.trim(),
    );
    await refreshHouseholdAlerts();
  }

  Future<void> updateGroceryItemStatus(
    int itemId,
    int newStatus,
    String date,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'grocery_items',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final item = rows.first;
    final groceryId = _asInt(item['grocery_id']) ?? 0;
    final previousStatus =
        _asInt(item['status']) == 1 ? 'completed' : 'pending';
    final now = DateTime.tryParse(date) ?? DateTime.now();
    final dueAt = DateTime.tryParse(item['due_at']?.toString() ?? '');
    final isCompleted = newStatus == 1;
    final delay = isCompleted ? _delayMinutes(dueAt, now) : 0;

    await db.update(
      'grocery_items',
      {
        'status': newStatus,
        'completed_at': isCompleted ? now.toIso8601String() : null,
        'completion_delay_minutes': delay,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (isCompleted) {
      await _deleteOpenAlertsForEntity(db, 'grocery_item', itemId);
    }
    await _logActivity(
      db,
      entityType: 'grocery_item',
      entityId: itemId,
      action: isCompleted ? 'completed' : 'reopened',
      oldStatus: previousStatus,
      newStatus: isCompleted ? 'completed' : 'pending',
      scheduledAt: dueAt,
      occurredAt: now,
      delayMinutes: delay,
      note: item['name']?.toString(),
    );
    await _syncPlanStatus(db, groceryId);
    await refreshHouseholdAlerts();
  }

  Future<void> deleteGroceryItem(int itemId) async {
    final db = await _db;
    final groceryId = await getGroceryIdForItem(itemId);
    await db.transaction((txn) async {
      await txn.delete(
        'household_alerts',
        where: "entity_type = 'grocery_item' AND entity_id = ?",
        whereArgs: [itemId],
      );
      await txn.delete(
        'household_activity_logs',
        where: "entity_type = 'grocery_item' AND entity_id = ?",
        whereArgs: [itemId],
      );
      await txn.delete('grocery_items', where: 'id = ?', whereArgs: [itemId]);
    });
    if (groceryId != null) await _syncPlanStatus(db, groceryId);
  }

  Future<int?> getGroceryIdForItem(int itemId) async {
    final db = await _db;
    final rows = await db.query(
      'grocery_items',
      columns: ['grocery_id'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    return rows.isEmpty ? null : _asInt(rows.first['grocery_id']);
  }

  Future<List<Map<String, dynamic>>> getHouseholdChores({
    bool includeCompleted = true,
  }) async {
    final db = await _db;
    await refreshHouseholdAlerts();
    return db.query(
      'household_chores',
      where: includeCompleted ? null : "status NOT IN ('completed', 'skipped')",
      orderBy: '''
        CASE status WHEN 'pending' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END,
        CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
        CASE WHEN due_at IS NULL OR due_at = '' THEN 1 ELSE 0 END,
        due_at ASC,
        id DESC
      ''',
    );
  }

  Future<int> createHouseholdChore({
    required String title,
    required String description,
    required String choreType,
    required String priority,
    required String iconKey,
    required int colorValue,
    DateTime? dueAt,
    required bool alertEnabled,
    required int alertMinutesBefore,
    required String recurrenceType,
    required int repeatInterval,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt.subtract(Duration(minutes: alertMinutesBefore))
        : null;

    final id = await db.insert('household_chores', {
      'title': title.trim(),
      'description': description.trim(),
      'chore_type': choreType,
      'priority': priority,
      'icon_key': iconKey,
      'color_value': colorValue,
      'due_at': dueAt?.toIso8601String(),
      'alert_enabled': alertEnabled ? 1 : 0,
      'alert_minutes_before': alertMinutesBefore,
      'reminder_at': reminderAt?.toIso8601String(),
      'recurrence_type': recurrenceType,
      'repeat_interval': repeatInterval,
      'status': 'pending',
      'completion_delay_minutes': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _logActivity(
      db,
      entityType: 'chore',
      entityId: id,
      action: 'created',
      newStatus: 'pending',
      scheduledAt: dueAt,
      occurredAt: now,
      note: title.trim(),
    );
    await refreshHouseholdAlerts();
    return id;
  }

  Future<void> updateHouseholdChore({
    required int id,
    required String title,
    required String description,
    required String choreType,
    required String priority,
    required String iconKey,
    required int colorValue,
    DateTime? dueAt,
    required bool alertEnabled,
    required int alertMinutesBefore,
    required String recurrenceType,
    required int repeatInterval,
  }) async {
    final db = await _db;
    final reminderAt = alertEnabled && dueAt != null
        ? dueAt
            .subtract(Duration(minutes: alertMinutesBefore))
            .toIso8601String()
        : null;

    await db.update(
      'household_chores',
      {
        'title': title.trim(),
        'description': description.trim(),
        'chore_type': choreType,
        'priority': priority,
        'icon_key': iconKey,
        'color_value': colorValue,
        'due_at': dueAt?.toIso8601String(),
        'alert_enabled': alertEnabled ? 1 : 0,
        'alert_minutes_before': alertMinutesBefore,
        'reminder_at': reminderAt,
        'recurrence_type': recurrenceType,
        'repeat_interval': repeatInterval,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _deleteOpenAlertsForEntity(db, 'chore', id);
    await _logActivity(
      db,
      entityType: 'chore',
      entityId: id,
      action: 'updated',
      scheduledAt: dueAt,
      note: title.trim(),
    );
    await refreshHouseholdAlerts();
  }

  Future<void> updateHouseholdChoreStatus(
    int choreId,
    String status,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'household_chores',
      where: 'id = ?',
      whereArgs: [choreId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final chore = rows.first;
    final oldStatus = chore['status']?.toString() ?? 'pending';
    final now = DateTime.now();
    final dueAt = DateTime.tryParse(chore['due_at']?.toString() ?? '');
    final isCompleted = status == 'completed';
    final delay = isCompleted ? _delayMinutes(dueAt, now) : 0;

    await db.update(
      'household_chores',
      {
        'status': status,
        'completed_at': isCompleted ? now.toIso8601String() : null,
        'completion_delay_minutes': delay,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [choreId],
    );

    if (status == 'completed' || status == 'skipped') {
      await _deleteOpenAlertsForEntity(db, 'chore', choreId);
    }
    await _logActivity(
      db,
      entityType: 'chore',
      entityId: choreId,
      action: status,
      oldStatus: oldStatus,
      newStatus: status,
      scheduledAt: dueAt,
      occurredAt: now,
      delayMinutes: delay,
      note: chore['title']?.toString(),
    );

    if (isCompleted) {
      await _createNextRecurringChore(db, chore, now);
    }
    await refreshHouseholdAlerts();
  }

  Future<void> deleteHouseholdChore(int choreId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'household_alerts',
        where: "entity_type = 'chore' AND entity_id = ?",
        whereArgs: [choreId],
      );
      await txn.delete(
        'household_activity_logs',
        where: "entity_type = 'chore' AND entity_id = ?",
        whereArgs: [choreId],
      );
      await txn
          .delete('household_chores', where: 'id = ?', whereArgs: [choreId]);
    });
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final db = await _db;
    await refreshHouseholdAlerts();

    final plans = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM grocery_titles
      WHERE COALESCE(status, 'active') != 'archived'
    ''')) ?? 0;
    final pendingItems = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM grocery_items WHERE status = 0
    ''')) ?? 0;
    final pendingChores = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM household_chores
      WHERE status NOT IN ('completed', 'skipped')
    ''')) ?? 0;
    final overdue = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM grocery_items
          WHERE status = 0 AND due_at IS NOT NULL AND due_at != ''
            AND datetime(due_at) < datetime('now', 'localtime'))
        +
        (SELECT COUNT(*) FROM household_chores
          WHERE status NOT IN ('completed', 'skipped')
            AND due_at IS NOT NULL AND due_at != ''
            AND datetime(due_at) < datetime('now', 'localtime'))
    ''')) ?? 0;
    final unreadAlerts = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM household_alerts
      WHERE is_read = 0 AND status = 'active'
    ''')) ?? 0;

    return {
      'plans': plans,
      'pending_items': pendingItems,
      'pending_chores': pendingChores,
      'overdue': overdue,
      'unread_alerts': unreadAlerts,
    };
  }

  Future<List<Map<String, dynamic>>> getHouseholdAlerts({
    bool includeRead = true,
  }) async {
    final db = await _db;
    await refreshHouseholdAlerts();
    return db.query(
      'household_alerts',
      where: includeRead
          ? "status = 'active'"
          : "status = 'active' AND is_read = 0",
      orderBy: '''
        is_read ASC,
        CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,
        alert_at DESC,
        id DESC
      ''',
    );
  }

  Future<void> markAlertRead(int alertId, {bool isRead = true}) async {
    final db = await _db;
    await db.update(
      'household_alerts',
      {
        'is_read': isRead ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<void> dismissAlert(int alertId) async {
    final db = await _db;
    await db.update(
      'household_alerts',
      {
        'status': 'dismissed',
        'is_read': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? entityType,
    int? entityId,
    int limit = 100,
  }) async {
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (entityType != null) {
      clauses.add('entity_type = ?');
      args.add(entityType);
    }
    if (entityId != null) {
      clauses.add('entity_id = ?');
      args.add(entityId);
    }
    args.add(limit);
    return db.rawQuery(
      'SELECT * FROM household_activity_logs '
      '${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')} '} '
      'ORDER BY occurred_at DESC, id DESC LIMIT ?',
      args,
    );
  }

  Future<void> refreshHouseholdAlerts() async {
    final db = await _db;
    final now = DateTime.now();

    final plans = await db.query(
      'grocery_titles',
      where: "COALESCE(status, 'active') = 'active' AND alert_enabled = 1 "
          "AND reminder_at IS NOT NULL AND reminder_at != '' "
          'AND datetime(reminder_at) <= datetime(?)',
      whereArgs: [now.toIso8601String()],
    );
    for (final plan in plans) {
      final dueAt = DateTime.tryParse(plan['due_at']?.toString() ?? '');
      final overdue = dueAt != null && dueAt.isBefore(now);
      await _upsertAlert(
        db,
        entityType: 'grocery_plan',
        entityId: _asInt(plan['id'])!,
        alertType: overdue ? 'overdue' : 'reminder',
        title: overdue ? 'Grocery plan overdue' : 'Grocery plan reminder',
        message: plan['title']?.toString() ?? 'Grocery plan',
        severity: overdue ? 'critical' : 'info',
        alertAt: overdue
            ? dueAt
            : DateTime.tryParse(plan['reminder_at']?.toString() ?? '') ?? now,
        dueAt: dueAt,
      );
    }

    final items = await db.query(
      'grocery_items',
      where: 'status = 0 AND alert_enabled = 1 '
          "AND reminder_at IS NOT NULL AND reminder_at != '' "
          'AND datetime(reminder_at) <= datetime(?)',
      whereArgs: [now.toIso8601String()],
    );
    for (final item in items) {
      final dueAt = DateTime.tryParse(item['due_at']?.toString() ?? '');
      final overdue = dueAt != null && dueAt.isBefore(now);
      await _upsertAlert(
        db,
        entityType: 'grocery_item',
        entityId: _asInt(item['id'])!,
        alertType: overdue ? 'overdue' : 'reminder',
        title: overdue ? 'Grocery item overdue' : 'Time to buy',
        message: item['name']?.toString() ?? 'Grocery item',
        severity: overdue ? 'critical' : 'warning',
        alertAt: overdue
            ? dueAt
            : DateTime.tryParse(item['reminder_at']?.toString() ?? '') ?? now,
        dueAt: dueAt,
      );
    }

    final chores = await db.query(
      'household_chores',
      where: "status NOT IN ('completed', 'skipped') AND alert_enabled = 1 "
          "AND reminder_at IS NOT NULL AND reminder_at != '' "
          'AND datetime(reminder_at) <= datetime(?)',
      whereArgs: [now.toIso8601String()],
    );
    for (final chore in chores) {
      final dueAt = DateTime.tryParse(chore['due_at']?.toString() ?? '');
      final overdue = dueAt != null && dueAt.isBefore(now);
      await _upsertAlert(
        db,
        entityType: 'chore',
        entityId: _asInt(chore['id'])!,
        alertType: overdue ? 'overdue' : 'reminder',
        title: overdue ? 'Chore delayed' : 'Chore reminder',
        message: chore['title']?.toString() ?? 'Household chore',
        severity: overdue ? 'critical' : 'warning',
        alertAt: overdue
            ? dueAt
            : DateTime.tryParse(chore['reminder_at']?.toString() ?? '') ?? now,
        dueAt: dueAt,
      );
    }
  }

  Future<void> _syncPlanStatus(Database db, int groceryId) async {
    if (groceryId <= 0) return;
    final counts = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END), 0) AS done
      FROM grocery_items WHERE grocery_id = ?
    ''', [groceryId]);
    final total = _asInt(counts.first['total']) ?? 0;
    final done = _asInt(counts.first['done']) ?? 0;
    final status = total > 0 && done == total ? 'completed' : 'active';
    await db.update(
      'grocery_titles',
      {
        'status': status,
        'completed_at':
            status == 'completed' ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND COALESCE(status, \'active\') != \'archived\'',
      whereArgs: [groceryId],
    );
    if (status == 'completed') {
      await _deleteOpenAlertsForEntity(db, 'grocery_plan', groceryId);
    }
  }

  Future<void> _createNextRecurringChore(
    Database db,
    Map<String, dynamic> chore,
    DateTime now,
  ) async {
    final recurrence = chore['recurrence_type']?.toString() ?? 'none';
    if (recurrence == 'none') return;
    final currentDue = DateTime.tryParse(chore['due_at']?.toString() ?? '');
    if (currentDue == null) return;
    final interval =
        (_asInt(chore['repeat_interval']) ?? 1).clamp(1, 365).toInt();
    DateTime nextDue;
    switch (recurrence) {
      case 'daily':
        nextDue = currentDue.add(Duration(days: interval));
        break;
      case 'weekly':
        nextDue = currentDue.add(Duration(days: 7 * interval));
        break;
      case 'monthly':
        nextDue = _addMonths(currentDue, interval);
        break;
      default:
        return;
    }
    while (!nextDue.isAfter(now)) {
      switch (recurrence) {
        case 'daily':
          nextDue = nextDue.add(Duration(days: interval));
          break;
        case 'weekly':
          nextDue = nextDue.add(Duration(days: 7 * interval));
          break;
        case 'monthly':
          nextDue = _addMonths(nextDue, interval);
          break;
      }
    }

    final rootId = _asInt(chore['series_root_id']) ?? _asInt(chore['id']);
    final existing = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM household_chores
      WHERE series_root_id = ? AND due_at = ?
    ''', [rootId, nextDue.toIso8601String()])) ?? 0;
    if (existing > 0) return;

    final alertEnabled = _asInt(chore['alert_enabled']) == 1;
    final alertMinutes = _asInt(chore['alert_minutes_before']) ?? 60;
    await db.insert('household_chores', {
      'series_root_id': rootId,
      'title': chore['title'],
      'description': chore['description'],
      'chore_type': chore['chore_type'],
      'priority': chore['priority'],
      'icon_key': chore['icon_key'],
      'color_value': chore['color_value'],
      'due_at': nextDue.toIso8601String(),
      'alert_enabled': alertEnabled ? 1 : 0,
      'alert_minutes_before': alertMinutes,
      'reminder_at': alertEnabled
          ? nextDue.subtract(Duration(minutes: alertMinutes)).toIso8601String()
          : null,
      'recurrence_type': recurrence,
      'repeat_interval': interval,
      'status': 'pending',
      'completion_delay_minutes': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> _upsertAlert(
    Database db, {
    required String entityType,
    required int entityId,
    required String alertType,
    required String title,
    required String message,
    required String severity,
    required DateTime alertAt,
    DateTime? dueAt,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT OR IGNORE INTO household_alerts (
        entity_type, entity_id, alert_type, title, message, severity,
        alert_at, due_at, is_read, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 'active', ?, ?)
    ''', [
      entityType,
      entityId,
      alertType,
      title,
      message,
      severity,
      alertAt.toIso8601String(),
      dueAt?.toIso8601String(),
      now,
      now,
    ]);
  }

  Future<void> _deleteOpenAlertsForEntity(
    Database db,
    String entityType,
    int entityId,
  ) {
    return db.delete(
      'household_alerts',
      where: 'entity_type = ? AND entity_id = ? AND status = ?',
      whereArgs: [entityType, entityId, 'active'],
    );
  }

  Future<void> _logActivity(
    Database db, {
    required String entityType,
    required int entityId,
    required String action,
    String? oldStatus,
    String? newStatus,
    DateTime? scheduledAt,
    DateTime? occurredAt,
    int? delayMinutes,
    String? note,
  }) async {
    final happenedAt = occurredAt ?? DateTime.now();
    await db.insert('household_activity_logs', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'old_status': oldStatus,
      'new_status': newStatus,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'occurred_at': happenedAt.toIso8601String(),
      'delay_minutes': delayMinutes ?? _delayMinutes(scheduledAt, happenedAt),
      'note': note,
      'created_at': happenedAt.toIso8601String(),
    });
  }

  static String _itemTemplateKey(Map<String, dynamic> item) {
    final name = (item['name']?.toString() ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return '';
    final itemType =
        (item['item_type']?.toString() ?? 'general').trim().toLowerCase();
    final unit = (item['unit']?.toString() ?? 'item').trim().toLowerCase();
    return '$name|$itemType|$unit';
  }

  static int _delayMinutes(DateTime? dueAt, DateTime completedAt) {
    if (dueAt == null || !completedAt.isAfter(dueAt)) return 0;
    return completedAt.difference(dueAt).inMinutes;
  }

  static String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime _addMonths(DateTime source, int months) {
    final targetMonthIndex = source.month - 1 + months;
    final year = source.year + targetMonthIndex ~/ 12;
    final month = targetMonthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = source.day > lastDay ? lastDay : source.day;
    return DateTime(
      year,
      month,
      day,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }
}
