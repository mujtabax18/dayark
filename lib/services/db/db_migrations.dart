import 'drift_database.dart';

import 'db_alter_helpers.dart';
import 'db_tables.dart';

class DbMigrations {
  static Future<void> createAll(Database db) async {
    await DbTables.createAll(db);
  }

  static Future<void> checkAndUpdateSchema(Database db) async {
    // Create missing tables first, but deliberately create no indexes yet.
    // Existing tables may still be missing columns introduced by newer app
    // versions. Those columns must be added before an index can reference them.
    await DbTables.createAll(db);
    await _dropRemovedShopTables(db);
    await DbAlterHelpers.addMissingColumns(db, 'family_memories', {
      'event_id': 'INTEGER',
    });

    await DbAlterHelpers.addMissingColumns(db, 'meters', {
      'baseline': 'REAL',
      'meter_type': "TEXT NOT NULL DEFAULT 'electricity'",
      'provider': "TEXT NOT NULL DEFAULT ''",
      'location': "TEXT NOT NULL DEFAULT ''",
      'consumer_name': "TEXT NOT NULL DEFAULT ''",
      'reference_number': "TEXT NOT NULL DEFAULT ''",
      'tariff_category': "TEXT NOT NULL DEFAULT 'residential'",
      'unit_label': "TEXT NOT NULL DEFAULT 'kWh'",
      'icon_key': "TEXT NOT NULL DEFAULT 'electricity'",
      'color_value': 'INTEGER NOT NULL DEFAULT 4284246976',
      'reading_frequency': "TEXT NOT NULL DEFAULT 'weekly'",
      'custom_interval_days': 'INTEGER NOT NULL DEFAULT 7',
      'billing_cycle_day': 'INTEGER NOT NULL DEFAULT 1',
      'target_units': 'REAL',
      'target_budget': 'REAL',
      'unit_rate': 'REAL NOT NULL DEFAULT 0',
      'fixed_charges': 'REAL NOT NULL DEFAULT 0',
      'notes': "TEXT NOT NULL DEFAULT ''",
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
    });
    await DbAlterHelpers.addMissingColumns(db, 'invoices', {
      'businessId': 'TEXT',
      'customerId': 'TEXT',
      'businessName': "TEXT NOT NULL DEFAULT ''",
      'businessAddress': "TEXT NOT NULL DEFAULT ''",
      'businessEmail': 'TEXT',
      'businessPhone': 'TEXT',
      'businessTaxId': 'TEXT',
      'purchaseOrderNumber': 'TEXT',
      'currencySymbol': "TEXT NOT NULL DEFAULT 'PKR'",
      'discountType': "TEXT NOT NULL DEFAULT 'percentage'",
      'discountValue': 'REAL NOT NULL DEFAULT 0',
      'shippingAmount': 'REAL NOT NULL DEFAULT 0',
      'paidAmount': 'REAL NOT NULL DEFAULT 0',
      'status': "TEXT NOT NULL DEFAULT 'draft'",
      'terms': 'TEXT',
      'footerText': 'TEXT',
      'logoPath': 'TEXT',
      'backgroundImagePath': 'TEXT',
      'templateStyle': "TEXT NOT NULL DEFAULT 'modern'",
      'accentColorValue': 'INTEGER NOT NULL DEFAULT 4280640491',
      'backgroundOpacity': 'REAL NOT NULL DEFAULT 0.06',
    });

    await DbAlterHelpers.addMissingColumns(db, 'invoice_items', {
      'sku': 'TEXT',
      'unit': "TEXT NOT NULL DEFAULT 'item'",
      'discountPercent': 'REAL NOT NULL DEFAULT 0',
    });

    await DbAlterHelpers.addMissingColumns(db, 'invoice_business_profiles', {
      'name': "TEXT NOT NULL DEFAULT ''",
      'address': "TEXT NOT NULL DEFAULT ''",
      'email': 'TEXT',
      'phone': 'TEXT',
      'taxId': 'TEXT',
      'logoPath': 'TEXT',
      'backgroundImagePath': 'TEXT',
      'templateStyle': "TEXT NOT NULL DEFAULT 'modern'",
      'accentColorValue': 'INTEGER NOT NULL DEFAULT 4280640491',
      'backgroundOpacity': 'REAL NOT NULL DEFAULT 0.06',
      'currencySymbol': "TEXT NOT NULL DEFAULT 'PKR'",
      'defaultTaxRate': 'REAL NOT NULL DEFAULT 0',
      'paymentInfo': "TEXT NOT NULL DEFAULT ''",
      'terms': 'TEXT',
      'customerNote': 'TEXT',
      'footerText': 'TEXT',
      'isDefault': 'INTEGER NOT NULL DEFAULT 0',
      'createdAt': "TEXT NOT NULL DEFAULT ''",
      'updatedAt': "TEXT NOT NULL DEFAULT ''",
    });

    await DbAlterHelpers.addMissingColumns(db, 'invoice_customers', {
      'name': "TEXT NOT NULL DEFAULT ''",
      'company': 'TEXT',
      'address': "TEXT NOT NULL DEFAULT ''",
      'email': 'TEXT',
      'phone': 'TEXT',
      'taxId': 'TEXT',
      'notes': 'TEXT',
      'usageCount': 'INTEGER NOT NULL DEFAULT 0',
      'createdAt': "TEXT NOT NULL DEFAULT ''",
      'updatedAt': "TEXT NOT NULL DEFAULT ''",
      'lastUsedAt': 'TEXT',
    });

    await DbAlterHelpers.addMissingColumns(db, 'invoice_preferences', {
      'defaultDueDays': 'INTEGER NOT NULL DEFAULT 7',
      'defaultStatus': "TEXT NOT NULL DEFAULT 'draft'",
      'autoSaveBusinesses': 'INTEGER NOT NULL DEFAULT 1',
      'autoSaveCustomers': 'INTEGER NOT NULL DEFAULT 1',
      'legacyProfilesMigrated': 'INTEGER NOT NULL DEFAULT 0',
      'updatedAt': "TEXT NOT NULL DEFAULT ''",
    });

    await db.insert(
      'invoice_preferences',
      {
        'id': 1,
        'defaultDueDays': 7,
        'defaultStatus': 'draft',
        'autoSaveBusinesses': 1,
        'autoSaveCustomers': 1,
        'legacyProfilesMigrated': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.execute("""
UPDATE invoice_business_profiles
SET templateStyle = COALESCE(NULLIF(templateStyle, ''), 'modern'),
    accentColorValue = COALESCE(accentColorValue, 4280640491),
    backgroundOpacity = COALESCE(backgroundOpacity, 0.06),
    currencySymbol = COALESCE(NULLIF(currencySymbol, ''), 'PKR'),
    defaultTaxRate = COALESCE(defaultTaxRate, 0),
    paymentInfo = COALESCE(paymentInfo, ''),
    isDefault = COALESCE(isDefault, 0),
    createdAt = COALESCE(NULLIF(createdAt, ''), datetime('now')),
    updatedAt = COALESCE(NULLIF(updatedAt, ''), datetime('now'))
""");

    await db.execute("""
UPDATE invoice_customers
SET address = COALESCE(address, ''),
    usageCount = COALESCE(usageCount, 0),
    createdAt = COALESCE(NULLIF(createdAt, ''), datetime('now')),
    updatedAt = COALESCE(NULLIF(updatedAt, ''), datetime('now'))
""");


    // Make details from older invoices reusable without changing the historic
    // invoice snapshots. Deterministic IDs keep this migration idempotent.
    await db.execute("""
INSERT OR IGNORE INTO invoice_business_profiles(
  id, name, address, email, phone, taxId, logoPath, backgroundImagePath,
  templateStyle, accentColorValue, backgroundOpacity, currencySymbol,
  defaultTaxRate, paymentInfo, terms, customerNote, footerText, isDefault,
  createdAt, updatedAt
)
SELECT
  'migrated-business-' || MIN(id),
  TRIM(businessName),
  COALESCE(businessAddress, ''),
  businessEmail,
  businessPhone,
  businessTaxId,
  logoPath,
  backgroundImagePath,
  COALESCE(NULLIF(templateStyle, ''), 'modern'),
  COALESCE(accentColorValue, 4280640491),
  COALESCE(backgroundOpacity, 0.06),
  COALESCE(NULLIF(currencySymbol, ''), 'PKR'),
  COALESCE(taxRate, 0),
  COALESCE(paymentInfo, ''),
  terms,
  notes,
  footerText,
  0,
  datetime('now'),
  datetime('now')
FROM invoices
WHERE TRIM(COALESCE(businessName, '')) <> ''
  AND COALESCE((SELECT legacyProfilesMigrated FROM invoice_preferences WHERE id = 1), 0) = 0
GROUP BY LOWER(TRIM(businessName)), LOWER(TRIM(COALESCE(businessAddress, '')))
""");

    await db.execute("""
INSERT OR IGNORE INTO invoice_customers(
  id, name, address, email, phone, usageCount, createdAt, updatedAt, lastUsedAt
)
SELECT
  'migrated-customer-' || MIN(id),
  TRIM(customerName),
  COALESCE(customerAddress, ''),
  customerEmail,
  customerPhone,
  COUNT(*),
  datetime('now'),
  datetime('now'),
  datetime(MAX(date) / 1000, 'unixepoch')
FROM invoices
WHERE TRIM(COALESCE(customerName, '')) <> ''
  AND COALESCE((SELECT legacyProfilesMigrated FROM invoice_preferences WHERE id = 1), 0) = 0
GROUP BY LOWER(TRIM(customerName)), LOWER(TRIM(COALESCE(customerAddress, '')))
""");

    await db.execute("""
UPDATE invoices
SET businessId = COALESCE(
  businessId,
  (
    SELECT id FROM invoice_business_profiles b
    WHERE LOWER(TRIM(b.name)) = LOWER(TRIM(invoices.businessName))
      AND LOWER(TRIM(b.address)) = LOWER(TRIM(COALESCE(invoices.businessAddress, '')))
    ORDER BY b.updatedAt DESC
    LIMIT 1
  )
)
WHERE TRIM(COALESCE(businessName, '')) <> ''
""");

    await db.execute("""
UPDATE invoices
SET customerId = COALESCE(
  customerId,
  (
    SELECT id FROM invoice_customers c
    WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(invoices.customerName))
      AND LOWER(TRIM(c.address)) = LOWER(TRIM(COALESCE(invoices.customerAddress, '')))
    ORDER BY c.updatedAt DESC
    LIMIT 1
  )
)
WHERE TRIM(COALESCE(customerName, '')) <> ''
""");

    await db.execute("""
UPDATE invoice_business_profiles
SET isDefault = 1
WHERE id = (
  SELECT id FROM invoice_business_profiles
  ORDER BY isDefault DESC, updatedAt DESC
  LIMIT 1
)
AND NOT EXISTS (
  SELECT 1 FROM invoice_business_profiles WHERE isDefault = 1
)
""");

    await db.execute("""
UPDATE invoice_preferences
SET legacyProfilesMigrated = 1,
    updatedAt = datetime('now')
WHERE id = 1 AND legacyProfilesMigrated = 0
""");

    await DbAlterHelpers.addMissingColumns(db, 'readings', {
      'value': 'REAL NOT NULL',
      'date': 'TEXT NOT NULL',
      'meter_id': 'INTEGER NOT NULL',
      'closing_id': 'INTEGER',
      'note': "TEXT NOT NULL DEFAULT ''",
      'bill_amount': 'REAL',
      'estimated_cost': 'REAL',
      'source': "TEXT NOT NULL DEFAULT 'manual'",
      'reading_kind': "TEXT NOT NULL DEFAULT 'normal'",
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
    });

    await DbAlterHelpers.addMissingColumns(db, 'meter_tariff_slabs', {
      'meter_id': 'INTEGER NOT NULL',
      'from_unit': 'REAL NOT NULL DEFAULT 0',
      'to_unit': 'REAL',
      'rate': 'REAL NOT NULL DEFAULT 0',
      'label': "TEXT NOT NULL DEFAULT ''",
      'position': 'INTEGER NOT NULL DEFAULT 0',
    });

    await db.execute("""
UPDATE meters
SET meter_type = COALESCE(NULLIF(meter_type, ''), 'electricity'),
    provider = COALESCE(provider, ''),
    location = COALESCE(location, ''),
    consumer_name = COALESCE(consumer_name, ''),
    reference_number = COALESCE(reference_number, ''),
    tariff_category = COALESCE(NULLIF(tariff_category, ''), 'residential'),
    unit_label = COALESCE(NULLIF(unit_label, ''), 'kWh'),
    icon_key = COALESCE(NULLIF(icon_key, ''), 'electricity'),
    color_value = COALESCE(color_value, 4284246976),
    reading_frequency = COALESCE(NULLIF(reading_frequency, ''), 'weekly'),
    custom_interval_days = CASE
      WHEN custom_interval_days IS NULL OR custom_interval_days < 1 THEN 7
      ELSE custom_interval_days
    END,
    billing_cycle_day = CASE
      WHEN billing_cycle_day IS NULL OR billing_cycle_day < 1 OR billing_cycle_day > 28 THEN 1
      ELSE billing_cycle_day
    END,
    unit_rate = COALESCE(unit_rate, 0),
    fixed_charges = COALESCE(fixed_charges, 0),
    notes = COALESCE(notes, ''),
    is_active = COALESCE(is_active, 1),
    created_at = COALESCE(created_at, datetime('now')),
    updated_at = COALESCE(updated_at, datetime('now'))
""");

    await db.execute("""
UPDATE readings
SET note = COALESCE(note, ''),
    source = COALESCE(NULLIF(source, ''), 'manual'),
    reading_kind = COALESCE(NULLIF(reading_kind, ''), 'normal'),
    created_at = COALESCE(created_at, date, datetime('now')),
    updated_at = COALESCE(updated_at, date, datetime('now'))
""");

    // Backfill the exact bill-cycle anchor for existing meter data. When a
    // reading matches the saved baseline, its date becomes the cycle start.
    // Otherwise the date when the meter was last updated is used.
    await db.execute("""
INSERT OR IGNORE INTO meter_baseline_anchors (
  meter_id,
  reading_id,
  value,
  date,
  updated_at
)
SELECT
  m.id,
  (
    SELECT r.id
    FROM readings r
    WHERE r.meter_id = m.id
      AND ABS(r.value - m.baseline) <= 0.000001
    ORDER BY r.date DESC, r.id DESC
    LIMIT 1
  ),
  m.baseline,
  COALESCE(
    (
      SELECT r.date
      FROM readings r
      WHERE r.meter_id = m.id
        AND ABS(r.value - m.baseline) <= 0.000001
      ORDER BY r.date DESC, r.id DESC
      LIMIT 1
    ),
    m.updated_at,
    datetime('now')
  ),
  COALESCE(m.updated_at, datetime('now'))
FROM meters m
WHERE m.baseline IS NOT NULL
""");

    await DbAlterHelpers.addMissingColumns(db, 'grocery_titles', {
      'title': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'plan_date': 'TEXT',
      'due_at': 'TEXT',
      'reminder_at': 'TEXT',
      'plan_type': "TEXT NOT NULL DEFAULT 'monthly'",
      'icon_key': "TEXT NOT NULL DEFAULT 'basket-shopping'",
      'color_value': 'INTEGER NOT NULL DEFAULT 4281236786',
      'alert_enabled': 'INTEGER NOT NULL DEFAULT 0',
      'alert_minutes_before': 'INTEGER NOT NULL DEFAULT 60',
      'status': "TEXT NOT NULL DEFAULT 'active'",
      'completed_at': 'TEXT',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
      'position': 'INTEGER NOT NULL DEFAULT 0',
    });

    await DbAlterHelpers.addMissingColumns(db, 'grocery_items', {
      'name': 'TEXT NOT NULL',
      'status': 'INTEGER NOT NULL DEFAULT 0',
      'date': 'TEXT NOT NULL',
      'grocery_id': 'INTEGER NOT NULL',
      'item_type': "TEXT NOT NULL DEFAULT 'general'",
      'quantity': 'REAL NOT NULL DEFAULT 1',
      'unit': "TEXT NOT NULL DEFAULT 'item'",
      'notes': "TEXT NOT NULL DEFAULT ''",
      'priority': "TEXT NOT NULL DEFAULT 'normal'",
      'due_at': 'TEXT',
      'reminder_at': 'TEXT',
      'alert_enabled': 'INTEGER NOT NULL DEFAULT 0',
      'alert_minutes_before': 'INTEGER NOT NULL DEFAULT 60',
      'completed_at': 'TEXT',
      'completion_delay_minutes': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
      'position': 'INTEGER NOT NULL DEFAULT 0',
      'closing_id': 'INTEGER',
    });

    await DbAlterHelpers.addMissingColumns(db, 'household_chores', {
      'series_root_id': 'INTEGER',
      'title': 'TEXT NOT NULL',
      'description': "TEXT NOT NULL DEFAULT ''",
      'chore_type': "TEXT NOT NULL DEFAULT 'general'",
      'priority': "TEXT NOT NULL DEFAULT 'normal'",
      'icon_key': "TEXT NOT NULL DEFAULT 'broom'",
      'color_value': 'INTEGER NOT NULL DEFAULT 4279592384',
      'due_at': 'TEXT',
      'reminder_at': 'TEXT',
      'alert_enabled': 'INTEGER NOT NULL DEFAULT 0',
      'alert_minutes_before': 'INTEGER NOT NULL DEFAULT 60',
      'recurrence_type': "TEXT NOT NULL DEFAULT 'none'",
      'repeat_interval': 'INTEGER NOT NULL DEFAULT 1',
      'status': "TEXT NOT NULL DEFAULT 'pending'",
      'completed_at': 'TEXT',
      'completion_delay_minutes': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    });

    await DbAlterHelpers.addMissingColumns(db, 'household_alerts', {
      'entity_type': 'TEXT NOT NULL',
      'entity_id': 'INTEGER NOT NULL',
      'alert_type': 'TEXT NOT NULL',
      'title': 'TEXT NOT NULL',
      'message': 'TEXT NOT NULL',
      'severity': "TEXT NOT NULL DEFAULT 'info'",
      'alert_at': 'TEXT NOT NULL',
      'due_at': 'TEXT',
      'is_read': 'INTEGER NOT NULL DEFAULT 0',
      'status': "TEXT NOT NULL DEFAULT 'active'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': 'TEXT NOT NULL',
    });

    await DbAlterHelpers.addMissingColumns(db, 'household_activity_logs', {
      'entity_type': 'TEXT NOT NULL',
      'entity_id': 'INTEGER NOT NULL',
      'action': 'TEXT NOT NULL',
      'old_status': 'TEXT',
      'new_status': 'TEXT',
      'scheduled_at': 'TEXT',
      'occurred_at': 'TEXT NOT NULL',
      'delay_minutes': 'INTEGER NOT NULL DEFAULT 0',
      'note': 'TEXT',
      'created_at': 'TEXT NOT NULL',
    });

    await db.execute("""
UPDATE grocery_titles
SET description = COALESCE(description, ''),
    plan_date = COALESCE(NULLIF(plan_date, ''), substr(COALESCE(created_at, datetime('now')), 1, 10)),
    plan_type = COALESCE(NULLIF(plan_type, ''), 'monthly'),
    icon_key = COALESCE(NULLIF(icon_key, ''), 'basket-shopping'),
    color_value = COALESCE(color_value, 4281236786),
    alert_enabled = COALESCE(alert_enabled, 0),
    alert_minutes_before = CASE
      WHEN alert_minutes_before IS NULL OR alert_minutes_before < 0 THEN 60
      ELSE alert_minutes_before
    END,
    status = COALESCE(NULLIF(status, ''), 'active'),
    position = COALESCE(position, 0),
    created_at = COALESCE(created_at, datetime('now')),
    updated_at = COALESCE(updated_at, created_at, datetime('now'))
""");

    await db.execute("""
UPDATE grocery_items
SET status = COALESCE(status, 0),
    item_type = COALESCE(NULLIF(item_type, ''), 'general'),
    quantity = CASE WHEN quantity IS NULL OR quantity <= 0 THEN 1 ELSE quantity END,
    unit = COALESCE(NULLIF(unit, ''), 'item'),
    notes = COALESCE(notes, ''),
    priority = COALESCE(NULLIF(priority, ''), 'normal'),
    alert_enabled = COALESCE(alert_enabled, 0),
    alert_minutes_before = CASE
      WHEN alert_minutes_before IS NULL OR alert_minutes_before < 0 THEN 60
      ELSE alert_minutes_before
    END,
    completion_delay_minutes = COALESCE(completion_delay_minutes, 0),
    position = COALESCE(position, 0),
    created_at = COALESCE(created_at, date, datetime('now')),
    updated_at = COALESCE(updated_at, date, created_at, datetime('now')),
    completed_at = CASE
      WHEN status = 1 THEN COALESCE(completed_at, updated_at, date, datetime('now'))
      ELSE NULL
    END
""");

    await DbAlterHelpers.addMissingColumns(db, 'expense_titles', {
      'title': 'TEXT NOT NULL',
      'position': 'INTEGER DEFAULT 0',
      'description': 'TEXT',
      'color': "TEXT DEFAULT '#5C6BC0'",
      'icon_code': 'INTEGER',
      'icon_font_family': "TEXT DEFAULT 'MaterialIcons'",
      'hidden': 'INTEGER NOT NULL DEFAULT 0',
      'creation_date': 'TEXT',
      'updatation_date': 'TEXT',
      'uuid': 'TEXT',
      'deleted_at': 'TEXT',
    });

    await DbAlterHelpers.addMissingColumns(db, 'expense_items', {
      'name': 'TEXT NOT NULL',
      'date': 'TEXT NOT NULL',
      'expense_id': 'INTEGER NOT NULL',
      'price': 'REAL',
      'in_or_out': 'TEXT',
      'notes': 'TEXT',
      'closing_id': 'INTEGER',
      'uuid': 'TEXT',
      'creation_date': 'TEXT',
      'updatation_date': 'TEXT',
      'deleted_at': 'TEXT',
    });
    await DbAlterHelpers.addMissingColumns(db, 'month_closing', {
      'title': 'TEXT',
      'description': 'TEXT',
      'start_date': 'TEXT',
      'end_date': 'TEXT',
      'uuid': 'TEXT',
      'creation_date': 'TEXT',
      'updatation_date': 'TEXT',
      'deleted_at': 'TEXT',
      'item_count': 'INTEGER NOT NULL DEFAULT 0',
      'total_in': 'REAL NOT NULL DEFAULT 0',
      'total_out': 'REAL NOT NULL DEFAULT 0',
      'closed_at': 'TEXT',
      'is_locked': 'INTEGER NOT NULL DEFAULT 1',
    });

    await DbAlterHelpers.addMissingColumns(db, 'home_features', {
      'title': 'TEXT',
      'route': 'TEXT',
      'iconCode': 'INTEGER',
      'position': 'INTEGER',
      'colorCode': 'INTEGER',
    });

    // NOTE: your original addMissingColumns used wrong types for mood_entries
    // (trigger/notes were marked INTEGER). Fix to TEXT to match CREATE TABLE.
    await DbAlterHelpers.addMissingColumns(db, 'mood_entries', {
      'dateTime': 'TEXT',
      'moodEmoji': "TEXT NOT NULL DEFAULT '😊'",
      'trigger': 'TEXT',
      'notes': 'TEXT',
      'title': "TEXT NOT NULL DEFAULT 'Untitled diary page'",
      'gratitude': 'TEXT',
      'tags': "TEXT NOT NULL DEFAULT '[]'",
      'imagePaths': "TEXT NOT NULL DEFAULT '[]'",
      'drawingPath': 'TEXT',
      'reminderAt': 'TEXT',
      'reminderEnabled': 'INTEGER NOT NULL DEFAULT 0',
      'isFavorite': 'INTEGER NOT NULL DEFAULT 0',
      'accentColorValue': 'INTEGER NOT NULL DEFAULT 4285293567',
      'createdAt': 'TEXT',
      'updatedAt': 'TEXT',
    });

    await db.execute("""
UPDATE mood_entries
SET title = COALESCE(NULLIF(TRIM(title), ''), 'Untitled diary page'),
    tags = COALESCE(NULLIF(tags, ''), '[]'),
    imagePaths = COALESCE(NULLIF(imagePaths, ''), '[]'),
    reminderEnabled = COALESCE(reminderEnabled, 0),
    isFavorite = COALESCE(isFavorite, 0),
    accentColorValue = COALESCE(accentColorValue, 4285293567),
    createdAt = COALESCE(createdAt, datetime('now')),
    updatedAt = COALESCE(updatedAt, datetime('now'))
""");

    await DbAlterHelpers.addMissingColumns(db, 'habits', {
      'title': 'TEXT NOT NULL',
      'description': 'TEXT',
      'created_at': 'TEXT NOT NULL',
      'notification_time': 'TEXT',
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'category': "TEXT NOT NULL DEFAULT 'Personal growth'",
      'reason': "TEXT NOT NULL DEFAULT ''",
      'cue': "TEXT NOT NULL DEFAULT ''",
      'reward': "TEXT NOT NULL DEFAULT ''",
      'difficulty': "TEXT NOT NULL DEFAULT 'medium'",
      'color_value': 'INTEGER NOT NULL DEFAULT 4280391411',
      'icon_code': 'INTEGER NOT NULL DEFAULT 59517',
      'target_value': 'INTEGER NOT NULL DEFAULT 1',
      'target_unit': "TEXT NOT NULL DEFAULT 'time'",
      'deadline_hour': 'INTEGER NOT NULL DEFAULT 23',
      'deadline_minute': 'INTEGER NOT NULL DEFAULT 59',
      'grace_minutes': 'INTEGER NOT NULL DEFAULT 0',
      'repeat_days': "TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7'",
      'archived_at': 'TEXT',
      'updated_at': 'TEXT',
    });

    await DbAlterHelpers.addMissingColumns(db, 'habit_progress', {
      'habit_id': 'INTEGER NOT NULL',
      'date': 'TEXT NOT NULL',
      'is_completed': 'INTEGER NOT NULL DEFAULT 0',
      'notes': 'TEXT',
      'value': 'REAL NOT NULL DEFAULT 1',
      'mood': "TEXT NOT NULL DEFAULT 'neutral'",
      'status': "TEXT NOT NULL DEFAULT 'completed'",
      'updated_at': 'TEXT',
    });

    await db.execute("""
UPDATE habits
SET category = COALESCE(NULLIF(category, ''), 'Personal growth'),
    reason = COALESCE(reason, ''),
    cue = COALESCE(cue, ''),
    reward = COALESCE(reward, ''),
    difficulty = COALESCE(NULLIF(difficulty, ''), 'medium'),
    color_value = COALESCE(color_value, 4280391411),
    icon_code = COALESCE(icon_code, 59517),
    target_value = CASE WHEN target_value IS NULL OR target_value < 1 THEN 1 ELSE target_value END,
    target_unit = COALESCE(NULLIF(target_unit, ''), 'time'),
    deadline_hour = CASE WHEN deadline_hour IS NULL OR deadline_hour < 0 OR deadline_hour > 23 THEN 23 ELSE deadline_hour END,
    deadline_minute = CASE WHEN deadline_minute IS NULL OR deadline_minute < 0 OR deadline_minute > 59 THEN 59 ELSE deadline_minute END,
    grace_minutes = COALESCE(grace_minutes, 0),
    repeat_days = COALESCE(NULLIF(repeat_days, ''), '1,2,3,4,5,6,7'),
    updated_at = COALESCE(updated_at, created_at, datetime('now'))
""");

    await db.execute("""
UPDATE habit_progress
SET value = COALESCE(value, 1),
    mood = COALESCE(NULLIF(mood, ''), 'neutral'),
    status = COALESCE(NULLIF(status, ''), CASE WHEN is_completed = 1 THEN 'completed' ELSE 'skipped' END),
    updated_at = COALESCE(updated_at, date, datetime('now'))
""");

    await DbAlterHelpers.addMissingColumns(db, 'quotations', {
      'text': 'TEXT NOT NULL',
      'author': "TEXT NOT NULL DEFAULT ''",
      'category': "TEXT NOT NULL DEFAULT 'General'",
      'source': "TEXT NOT NULL DEFAULT 'manual'",
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'is_used': 'INTEGER NOT NULL DEFAULT 0',
      'usage_count': 'INTEGER NOT NULL DEFAULT 0',
      'background_style': "TEXT NOT NULL DEFAULT 'sunrise'",
      'text_align': "TEXT NOT NULL DEFAULT 'center'",
      'font_size': 'REAL NOT NULL DEFAULT 30',
      'show_author': 'INTEGER NOT NULL DEFAULT 1',
      'remote_uid': 'TEXT',
      'remote_category_id': 'TEXT',
      'remote_catalog_version': 'TEXT',
      'remote_updated_at': 'TEXT',
      'imported_at': 'TEXT',
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    });


    await db.execute("""
UPDATE quotations
SET author = COALESCE(author, ''),
    category = COALESCE(NULLIF(TRIM(category), ''), 'General'),
    source = COALESCE(NULLIF(source, ''), 'manual'),
    is_favorite = COALESCE(is_favorite, 0),
    is_used = COALESCE(is_used, 0),
    usage_count = COALESCE(usage_count, 0),
    background_style = COALESCE(NULLIF(background_style, ''), 'sunrise'),
    text_align = COALESCE(NULLIF(text_align, ''), 'center'),
    font_size = CASE WHEN font_size IS NULL OR font_size < 20 THEN 30 ELSE font_size END,
    show_author = COALESCE(show_author, 1),
    created_at = COALESCE(NULLIF(created_at, ''), datetime('now')),
    updated_at = COALESCE(NULLIF(updated_at, ''), created_at, datetime('now'))
""");

    // Keep one local row for exact case-insensitive duplicates that may have
    // been introduced by older JSON imports. Preserve favorite/use history on
    // the surviving row before removing duplicate copies.
    await db.execute("""
UPDATE quotations AS keeper
SET is_favorite = (
      SELECT MAX(COALESCE(q2.is_favorite, 0))
      FROM quotations q2
      WHERE LOWER(TRIM(q2.text)) = LOWER(TRIM(keeper.text))
        AND LOWER(TRIM(COALESCE(q2.author, ''))) = LOWER(TRIM(COALESCE(keeper.author, '')))
        AND LOWER(TRIM(q2.category)) = LOWER(TRIM(keeper.category))
    ),
    is_used = (
      SELECT MAX(COALESCE(q2.is_used, 0))
      FROM quotations q2
      WHERE LOWER(TRIM(q2.text)) = LOWER(TRIM(keeper.text))
        AND LOWER(TRIM(COALESCE(q2.author, ''))) = LOWER(TRIM(COALESCE(keeper.author, '')))
        AND LOWER(TRIM(q2.category)) = LOWER(TRIM(keeper.category))
    ),
    usage_count = (
      SELECT SUM(COALESCE(q2.usage_count, 0))
      FROM quotations q2
      WHERE LOWER(TRIM(q2.text)) = LOWER(TRIM(keeper.text))
        AND LOWER(TRIM(COALESCE(q2.author, ''))) = LOWER(TRIM(COALESCE(keeper.author, '')))
        AND LOWER(TRIM(q2.category)) = LOWER(TRIM(keeper.category))
    )
WHERE keeper.id IN (
  SELECT MIN(id)
  FROM quotations
  GROUP BY LOWER(TRIM(text)), LOWER(TRIM(COALESCE(author, ''))), LOWER(TRIM(category))
)
""");

    await db.execute("""
DELETE FROM quotations
WHERE id NOT IN (
  SELECT MIN(id)
  FROM quotations
  GROUP BY LOWER(TRIM(text)), LOWER(TRIM(COALESCE(author, ''))), LOWER(TRIM(category))
)
""");

    // Version 13 stored obsolete AI-provider credentials. The current online
    // library only downloads public JSON and never stores API credentials.
    await db.execute('DROP TABLE IF EXISTS quotation_ai_settings');


    await DbAlterHelpers.addMissingColumns(db, 'loans', {
      'entity_name': "TEXT NOT NULL DEFAULT ''",
      'loan_type': 'INTEGER NOT NULL DEFAULT 0',
      'amount': 'REAL NOT NULL DEFAULT 0',
      'interest_amount': 'REAL NOT NULL DEFAULT 0',
      'start_date': "TEXT NOT NULL DEFAULT ''",
      'due_date': 'TEXT',
      'status': 'INTEGER NOT NULL DEFAULT 0',
      'notes': "TEXT NOT NULL DEFAULT ''",
      'phone': "TEXT NOT NULL DEFAULT ''",
      'address': "TEXT NOT NULL DEFAULT ''",
      'category': "TEXT NOT NULL DEFAULT 'General'",
      'reference_number': "TEXT NOT NULL DEFAULT ''",
      'currency_code': "TEXT NOT NULL DEFAULT 'PKR'",
      'installment_frequency': "TEXT NOT NULL DEFAULT 'none'",
      'installment_amount': 'REAL NOT NULL DEFAULT 0',
      'reminder_enabled': 'INTEGER NOT NULL DEFAULT 1',
      'reminder_days_before': 'INTEGER NOT NULL DEFAULT 3',
      'last_reminder_at': 'TEXT',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
      'archived_at': 'TEXT',
    });

    await DbAlterHelpers.addMissingColumns(db, 'loan_transactions', {
      'loan_id': 'INTEGER NOT NULL DEFAULT 0',
      'amount': 'REAL NOT NULL DEFAULT 0',
      'date': "TEXT NOT NULL DEFAULT ''",
      'note': "TEXT NOT NULL DEFAULT ''",
      'transaction_type': "TEXT NOT NULL DEFAULT 'payment'",
      'payment_method': "TEXT NOT NULL DEFAULT 'cash'",
      'reference_number': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'TEXT',
    });

    await db.execute("""
UPDATE loans
SET entity_name = COALESCE(entity_name, ''),
    loan_type = COALESCE(loan_type, 0),
    amount = COALESCE(amount, 0),
    interest_amount = COALESCE(interest_amount, 0),
    start_date = COALESCE(NULLIF(start_date, ''), datetime('now')),
    status = COALESCE(status, 0),
    notes = COALESCE(notes, ''),
    phone = COALESCE(phone, ''),
    address = COALESCE(address, ''),
    category = COALESCE(NULLIF(category, ''), 'General'),
    reference_number = COALESCE(reference_number, ''),
    currency_code = COALESCE(NULLIF(currency_code, ''), 'PKR'),
    installment_frequency = COALESCE(NULLIF(installment_frequency, ''), 'none'),
    installment_amount = COALESCE(installment_amount, 0),
    reminder_enabled = COALESCE(reminder_enabled, 1),
    reminder_days_before = CASE
      WHEN reminder_days_before IS NULL OR reminder_days_before < 0 THEN 3
      ELSE reminder_days_before
    END,
    created_at = COALESCE(created_at, start_date, datetime('now')),
    updated_at = COALESCE(updated_at, created_at, start_date, datetime('now'))
""");

    await db.execute("""
UPDATE loan_transactions
SET amount = COALESCE(amount, 0),
    date = COALESCE(NULLIF(date, ''), datetime('now')),
    note = COALESCE(note, ''),
    transaction_type = COALESCE(NULLIF(transaction_type, ''), 'payment'),
    payment_method = COALESCE(NULLIF(payment_method, ''), 'cash'),
    reference_number = COALESCE(reference_number, ''),
    created_at = COALESCE(created_at, date, datetime('now'))
""");

    await DbAlterHelpers.addMissingColumns(db, 'media_files', {
      'file_path': 'TEXT NOT NULL',
      'original_path': "TEXT NOT NULL DEFAULT ''",
      'edited_path': 'TEXT',
      'media_type': "TEXT NOT NULL DEFAULT 'image'",
      'title': "TEXT NOT NULL DEFAULT ''",
      'mime_type': 'TEXT',
      'extension': 'TEXT',
      'file_size': 'INTEGER NOT NULL DEFAULT 0',
      'checksum': 'TEXT',
      'version': 'INTEGER NOT NULL DEFAULT 1',
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    });

    await DbAlterHelpers.addMissingColumns(db, 'media_edit_history', {
      'media_id': 'INTEGER NOT NULL',
      'action': 'TEXT NOT NULL',
      'version': 'INTEGER NOT NULL DEFAULT 1',
      'source_path': 'TEXT NOT NULL',
      'output_path': 'TEXT NOT NULL',
      'metadata_json': 'TEXT',
      'created_at': 'TEXT NOT NULL',
    });

    await DbAlterHelpers.addMissingColumns(db, 'backup_restore_history', {
      'operation': 'TEXT NOT NULL',
      'scope': 'TEXT NOT NULL',
      'file_name': 'TEXT',
      'file_size': 'INTEGER NOT NULL DEFAULT 0',
      'asset_count': 'INTEGER NOT NULL DEFAULT 0',
      'status': 'TEXT NOT NULL',
      'message': 'TEXT',
      'created_at': 'TEXT NOT NULL',
    });

    await db.execute("""
UPDATE media_files
SET original_path = CASE
      WHEN original_path IS NULL OR TRIM(original_path) = '' THEN file_path
      ELSE original_path
    END,
    media_type = COALESCE(NULLIF(media_type, ''), 'image'),
    title = CASE
      WHEN title IS NULL OR TRIM(title) = '' THEN COALESCE(file_path, 'Untitled media')
      ELSE title
    END,
    file_size = COALESCE(file_size, 0),
    version = CASE WHEN version IS NULL OR version < 1 THEN 1 ELSE version END,
    is_favorite = COALESCE(is_favorite, 0),
    is_deleted = COALESCE(is_deleted, 0),
    updated_at = COALESCE(NULLIF(updated_at, ''), created_at, datetime('now'))
""");

    await DbAlterHelpers.addMissingColumns(db, 'scan_groups', {
      'id': 'INTEGER',
      'title': 'TEXT NOT NULL',
      'source': "TEXT NOT NULL DEFAULT 'scanner'",
      'created_at': 'TEXT NOT NULL',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'tags': "TEXT NOT NULL DEFAULT ''",
    });

    await DbAlterHelpers.addMissingColumns(db, 'scans', {
      'id': 'INTEGER',
      'original_path': 'TEXT NOT NULL',
      'edited_path': 'TEXT NOT NULL',
      'created_at': 'TEXT NOT NULL',
      'group_id': 'INTEGER',
      'sort_id': 'INTEGER NOT NULL DEFAULT 0',
      'title': "TEXT NOT NULL DEFAULT ''",
      'notes': "TEXT NOT NULL DEFAULT ''",
      'ocr_text': "TEXT NOT NULL DEFAULT ''",
      'file_size': 'INTEGER NOT NULL DEFAULT 0',
      'checksum': 'TEXT',
      'version': 'INTEGER NOT NULL DEFAULT 1',
      'is_favorite': 'INTEGER NOT NULL DEFAULT 0',
      'updated_at': "TEXT NOT NULL DEFAULT ''",
    });

    await DbAlterHelpers.addMissingColumns(db, 'scan_edit_history', {
      'scan_id': 'INTEGER NOT NULL',
      'action': 'TEXT NOT NULL',
      'version': 'INTEGER NOT NULL DEFAULT 1',
      'source_path': 'TEXT NOT NULL',
      'output_path': 'TEXT NOT NULL',
      'metadata_json': 'TEXT',
      'created_at': 'TEXT NOT NULL',
    });

    await db.execute("""
UPDATE scan_groups
SET source = COALESCE(NULLIF(source, ''), 'scanner'),
    updated_at = COALESCE(NULLIF(updated_at, ''), created_at, datetime('now')),
    is_favorite = COALESCE(is_favorite, 0),
    tags = COALESCE(tags, '')
""");

    await db.execute("""
UPDATE scans
SET edited_path = COALESCE(NULLIF(edited_path, ''), original_path),
    sort_id = COALESCE(sort_id, 0),
    title = COALESCE(title, ''),
    notes = COALESCE(notes, ''),
    ocr_text = COALESCE(ocr_text, ''),
    file_size = COALESCE(file_size, 0),
    version = CASE WHEN version IS NULL OR version < 1 THEN 1 ELSE version END,
    is_favorite = COALESCE(is_favorite, 0),
    updated_at = COALESCE(NULLIF(updated_at, ''), created_at, datetime('now'))
""");
    await DbAlterHelpers.addMissingColumns(db, 'user_settings', {
      'key': 'TEXT NOT NULL',
      'value': 'TEXT NOT NULL',
      'user_id': 'INTEGER NOT NULL DEFAULT 0',
    });

    await DbAlterHelpers.addMissingColumns(db, 'pill_types', {
      'is_system': 'INTEGER NOT NULL DEFAULT 0',
    });
    await DbAlterHelpers.addMissingColumns(db, 'dosage_types', {
      'is_system': 'INTEGER NOT NULL DEFAULT 0',
    });
    await DbAlterHelpers.addMissingColumns(db, 'pills', {
      'dose_quantity': 'REAL NOT NULL DEFAULT 1',
      'color_hex': "TEXT NOT NULL DEFAULT '#6C63FF'",
      'track_inventory': 'INTEGER NOT NULL DEFAULT 1',
    });
    await DbAlterHelpers.addMissingColumns(db, 'schedule_rules', {
      'days_of_month': 'TEXT',
    });
    // Backfill safe defaults for records created by older app versions.
    await db.execute("""
UPDATE pills
SET dose_quantity = COALESCE(dose_quantity, 1),
    color_hex = COALESCE(NULLIF(color_hex, ''), '#6C63FF'),
    track_inventory = COALESCE(track_inventory, 1)
""");

    await db.execute("""
UPDATE pill_types
SET is_system = CASE
  WHEN name IN ('Tablet','Capsule','Syrup','Injection','Drops','Inhaler','Cream','Powder') THEN 1
  ELSE COALESCE(is_system, 0)
END
""");

    await db.execute("""
UPDATE dosage_types
SET is_system = CASE
  WHEN name IN ('mg','mcg','g','ml','drops','units') THEN 1
  ELSE COALESCE(is_system, 0)
END
""");

    await db.execute('''
DELETE FROM reminder_occurrences
WHERE id NOT IN (
  SELECT MIN(id)
  FROM reminder_occurrences
  GROUP BY pill_id, scheduled_date, scheduled_time
)
''');

    await db.execute("""
UPDATE expense_titles
SET color = COALESCE(NULLIF(color, ''), '#5C6BC0'),
    icon_code = COALESCE(icon_code, 57895),
    icon_font_family = COALESCE(NULLIF(icon_font_family, ''), 'MaterialIcons'),
    hidden = COALESCE(hidden, 0),
    uuid = COALESCE(NULLIF(uuid, ''), 'legacy-expense-title-' || id)
""");

    await db.execute("""
UPDATE expense_items
SET uuid = COALESCE(NULLIF(uuid, ''), 'legacy-expense-item-' || id),
    price = COALESCE(price, 0),
    in_or_out = COALESCE(NULLIF(in_or_out, ''), 'Out')
""");

    await db.execute("""
UPDATE month_closing
SET uuid = COALESCE(NULLIF(uuid, ''), 'legacy-month-closing-' || id),
    item_count = CASE
      WHEN item_count = 0 THEN (
        SELECT COUNT(*) FROM expense_items ei
        WHERE ei.closing_id = month_closing.id AND ei.deleted_at IS NULL
      )
      ELSE item_count
    END,
    total_in = CASE
      WHEN item_count = 0 THEN (
        SELECT COALESCE(SUM(price), 0) FROM expense_items ei
        WHERE ei.closing_id = month_closing.id
          AND ei.deleted_at IS NULL AND ei.in_or_out = 'In'
      )
      ELSE total_in
    END,
    total_out = CASE
      WHEN item_count = 0 THEN (
        SELECT COALESCE(SUM(price), 0) FROM expense_items ei
        WHERE ei.closing_id = month_closing.id
          AND ei.deleted_at IS NULL AND ei.in_or_out = 'Out'
      )
      ELSE total_out
    END,
    closed_at = COALESCE(closed_at, creation_date),
    is_locked = COALESCE(is_locked, 1)
""");

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expense_items_date
ON expense_items(date)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id
ON expense_items(expense_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expense_items_closing_id
ON expense_items(closing_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expense_items_active_lookup
ON expense_items(deleted_at, closing_id, expense_id, date)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expense_titles_active_position
ON expense_titles(deleted_at, hidden, position)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_month_closing_dates
ON month_closing(deleted_at, start_date, end_date)
''');


    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_grocery_titles_status_date
ON grocery_titles(status, plan_date DESC, position)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_grocery_items_plan_status_due
ON grocery_items(grocery_id, status, due_at, priority)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_household_chores_status_due
ON household_chores(status, due_at, priority)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_household_alerts_active
ON household_alerts(status, is_read, severity, alert_at DESC)
''');

    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_household_alert_unique
ON household_alerts(entity_type, entity_id, alert_type, status)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_household_activity_entity
ON household_activity_logs(entity_type, entity_id, occurred_at DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_mood_entries_date
ON mood_entries(dateTime DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_mood_entries_favorite
ON mood_entries(isFavorite, dateTime DESC)
''');

    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_reminder_occurrence_unique
ON reminder_occurrences(pill_id, scheduled_date, scheduled_time)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_reminder_occurrence_schedule
ON reminder_occurrences(scheduled_date, scheduled_time, status)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_pills_profile_active
ON pills(profile_id, is_active)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_meters_active_type
ON meters(is_active, meter_type, name)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_readings_meter_date
ON readings(meter_id, date DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_meter_baseline_anchors_reading
ON meter_baseline_anchors(reading_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_meter_tariff_slabs_meter
ON meter_tariff_slabs(meter_id, position, from_unit)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_pill_inventory_low_stock
ON pill_inventory(remaining_quantity, low_stock_threshold)
''');


    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_loans_active_due
ON loans(archived_at, status, due_date, loan_type)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_loans_search
ON loans(entity_name COLLATE NOCASE, phone, reference_number)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_loan_transactions_account_date
ON loan_transactions(loan_id, date DESC, id DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_loan_transactions_type_date
ON loan_transactions(transaction_type, date DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_media_files_library
ON media_files(is_deleted, media_type, is_favorite, updated_at DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_media_collections_order
ON media_collections(sort_order, name COLLATE NOCASE)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_media_collection_items_media
ON media_collection_items(media_id, collection_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_media_collection_items_collection_order
ON media_collection_items(collection_id, sort_order, added_at, media_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_media_history_media_version
ON media_edit_history(media_id, version DESC, id DESC)
''');


    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_scan_groups_library
ON scan_groups(is_favorite, updated_at DESC, created_at DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_scans_group_order
ON scans(group_id, sort_id, id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_scan_history_scan_version
ON scan_edit_history(scan_id, version DESC, id DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_invoice_business_default_updated
ON invoice_business_profiles(isDefault DESC, updatedAt DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_invoice_customers_usage
ON invoice_customers(lastUsedAt DESC, usageCount DESC, name)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_invoices_business_customer
ON invoices(businessId, customerId, date DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_quotations_library
ON quotations(is_favorite DESC, category, updated_at DESC, created_at DESC)
''');
    
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_quotations_remote_uid
ON quotations(remote_uid)
WHERE remote_uid IS NOT NULL AND TRIM(remote_uid) != ''
''');

    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_quotations_content_unique
ON quotations(
  LOWER(TRIM(text)),
  LOWER(TRIM(COALESCE(author, ''))),
  LOWER(TRIM(category))
)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_quotations_remote_category
ON quotations(remote_category_id, remote_catalog_version)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_members_tree_name
ON family_members(tree_id, first_name COLLATE NOCASE, last_name COLLATE NOCASE)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_relationships_tree_members
ON family_relationships(tree_id, from_member_id, to_member_id, relationship_type)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_memories_tree_date
ON family_memories(tree_id, memory_date DESC, created_at DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_member_photos_owner
ON family_member_photos(tree_id, member_id, id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_memory_photos_owner
ON family_memory_photos(tree_id, memory_id, id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_memory_people_member
ON family_memory_people(member_id, memory_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_life_connections_tree
ON life_connections(tree_id, from_member_id, to_member_id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_life_events_tree_date
ON life_events(tree_id, event_date DESC, created_at DESC)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_life_event_people_person
ON life_event_people(member_id, event_id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_memory_event
ON family_memories(event_id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_family_memories_member
ON family_memories(member_id, created_at DESC)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_backup_restore_history_created
ON backup_restore_history(created_at DESC)
''');
  }


  static Future<void> _dropRemovedShopTables(Database db) async {
    const tables = <String>[
      'shop_deal_products',
      'shop_deals',
      'shop_products',
      'shop_subcategories',
      'shop_units',
      'shop_categories',
      'shop_details',
    ];

    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }

  static Future<void> clearAllTables(Database db) async {
    // Keep your behavior, but centralized.
    const tables = <String>[
      'life_event_people',
      'life_connections',
      'life_events',
      'family_memory_people',
      'family_memory_photos',
      'family_member_photos',
      'family_memories',
      'family_relationships',
      'family_members',
      'family_trees',
      'meter_tariff_slabs',
      'meter_baseline_anchors',
      'readings',
      'meters',
      'household_alerts',
      'household_activity_logs',
      'household_chores',
      'grocery_items',
      'grocery_titles',
      'invoice_items',
      'invoices',
      'invoice_customers',
      'invoice_business_profiles',
      'invoice_preferences',
      'loan_transactions',
      'loans',
    ];

    for (final table in tables) {
      await db.delete(table);
      await db.rawQuery("DELETE FROM sqlite_sequence where name='$table'");
    }
  }
}
