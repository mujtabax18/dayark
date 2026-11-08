import 'drift_database.dart';

class DbTables {
  /// Creates tables only.
  ///
  /// Do not create indexes here: on an existing database, CREATE TABLE IF NOT
  /// EXISTS does not add newly introduced columns. Indexes are therefore
  /// created by DbMigrations only after all missing columns have been added.
  static Future<void> createAll(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        number TEXT NOT NULL DEFAULT '',
        baseline REAL,
        meter_type TEXT NOT NULL DEFAULT 'electricity',
        provider TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        consumer_name TEXT NOT NULL DEFAULT '',
        reference_number TEXT NOT NULL DEFAULT '',
        tariff_category TEXT NOT NULL DEFAULT 'residential',
        unit_label TEXT NOT NULL DEFAULT 'kWh',
        icon_key TEXT NOT NULL DEFAULT 'electricity',
        color_value INTEGER NOT NULL DEFAULT 4284246976,
        reading_frequency TEXT NOT NULL DEFAULT 'weekly',
        custom_interval_days INTEGER NOT NULL DEFAULT 7,
        billing_cycle_day INTEGER NOT NULL DEFAULT 1,
        target_units REAL,
        target_budget REAL,
        unit_rate REAL NOT NULL DEFAULT 0,
        fixed_charges REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_settings (
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        user_id INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (key, user_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_feature_positions (
        id INTEGER PRIMARY KEY,
        position INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        value REAL NOT NULL,
        date TEXT NOT NULL,
        meter_id INTEGER NOT NULL,
        closing_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        bill_amount REAL,
        estimated_cost REAL,
        source TEXT NOT NULL DEFAULT 'manual',
        reading_kind TEXT NOT NULL DEFAULT 'normal',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (meter_id) REFERENCES meters (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meter_baseline_anchors (
        meter_id INTEGER PRIMARY KEY,
        reading_id INTEGER,
        value REAL NOT NULL,
        date TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (meter_id) REFERENCES meters (id) ON DELETE CASCADE,
        FOREIGN KEY (reading_id) REFERENCES readings (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meter_tariff_slabs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_id INTEGER NOT NULL,
        from_unit REAL NOT NULL DEFAULT 0,
        to_unit REAL,
        rate REAL NOT NULL DEFAULT 0,
        label TEXT NOT NULL DEFAULT '',
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (meter_id) REFERENCES meters (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS grocery_titles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        plan_date TEXT,
        due_at TEXT,
        reminder_at TEXT,
        plan_type TEXT NOT NULL DEFAULT 'monthly',
        icon_key TEXT NOT NULL DEFAULT 'basket-shopping',
        color_value INTEGER NOT NULL DEFAULT 4281236786,
        alert_enabled INTEGER NOT NULL DEFAULT 0,
        alert_minutes_before INTEGER NOT NULL DEFAULT 60,
        status TEXT NOT NULL DEFAULT 'active',
        completed_at TEXT,
        created_at TEXT,
        updated_at TEXT,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS grocery_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        grocery_id INTEGER NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'general',
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'item',
        notes TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL DEFAULT 'normal',
        due_at TEXT,
        reminder_at TEXT,
        alert_enabled INTEGER NOT NULL DEFAULT 0,
        alert_minutes_before INTEGER NOT NULL DEFAULT 60,
        completed_at TEXT,
        completion_delay_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        closing_id INTEGER,
        FOREIGN KEY (grocery_id) REFERENCES grocery_titles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS household_chores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        series_root_id INTEGER,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        chore_type TEXT NOT NULL DEFAULT 'general',
        priority TEXT NOT NULL DEFAULT 'normal',
        icon_key TEXT NOT NULL DEFAULT 'broom',
        color_value INTEGER NOT NULL DEFAULT 4279592384,
        due_at TEXT,
        reminder_at TEXT,
        alert_enabled INTEGER NOT NULL DEFAULT 0,
        alert_minutes_before INTEGER NOT NULL DEFAULT 60,
        recurrence_type TEXT NOT NULL DEFAULT 'none',
        repeat_interval INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'pending',
        completed_at TEXT,
        completion_delay_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS household_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        alert_type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'info',
        alert_at TEXT NOT NULL,
        due_at TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS household_activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        old_status TEXT,
        new_status TEXT,
        scheduled_at TEXT,
        occurred_at TEXT NOT NULL,
        delay_minutes INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS expense_titles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  color TEXT DEFAULT '#5C6BC0',
  icon_code INTEGER,
  icon_font_family TEXT DEFAULT 'MaterialIcons',
  hidden INTEGER NOT NULL DEFAULT 0,
  creation_date TEXT,
  updatation_date TEXT,
  deleted_at TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS expense_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT NOT NULL,
  date TEXT NOT NULL,
  expense_id INTEGER NOT NULL,
  price REAL,
  in_or_out TEXT,
  notes TEXT,
  closing_id INTEGER,
  creation_date TEXT,
  updatation_date TEXT,
  deleted_at TEXT,
  FOREIGN KEY (expense_id) REFERENCES expense_titles (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS month_closing (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  item_count INTEGER NOT NULL DEFAULT 0,
  total_in REAL NOT NULL DEFAULT 0,
  total_out REAL NOT NULL DEFAULT 0,
  closed_at TEXT,
  is_locked INTEGER NOT NULL DEFAULT 1,
  creation_date TEXT,
  updatation_date TEXT,
  deleted_at TEXT
)
''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_features (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        route TEXT,
        iconCode INTEGER,
        position INTEGER,
        colorCode INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateTime TEXT NOT NULL,
        moodEmoji TEXT NOT NULL DEFAULT '😊',
        trigger TEXT,
        notes TEXT,
        title TEXT NOT NULL DEFAULT 'Untitled diary page',
        gratitude TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        imagePaths TEXT NOT NULL DEFAULT '[]',
        drawingPath TEXT,
        reminderAt TEXT,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        accentColorValue INTEGER NOT NULL DEFAULT 4285293567,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        notification_time TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL DEFAULT 'Personal growth',
        reason TEXT NOT NULL DEFAULT '',
        cue TEXT NOT NULL DEFAULT '',
        reward TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL DEFAULT 'medium',
        color_value INTEGER NOT NULL DEFAULT 4280391411,
        icon_code INTEGER NOT NULL DEFAULT 59517,
        target_value INTEGER NOT NULL DEFAULT 1,
        target_unit TEXT NOT NULL DEFAULT 'time',
        deadline_hour INTEGER NOT NULL DEFAULT 23,
        deadline_minute INTEGER NOT NULL DEFAULT 59,
        grace_minutes INTEGER NOT NULL DEFAULT 0,
        repeat_days TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
        archived_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        value REAL NOT NULL DEFAULT 1,
        mood TEXT NOT NULL DEFAULT 'neutral',
        status TEXT NOT NULL DEFAULT 'completed',
        updated_at TEXT,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE,
        UNIQUE(habit_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'General',
        source TEXT NOT NULL DEFAULT 'manual',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_used INTEGER NOT NULL DEFAULT 0,
        usage_count INTEGER NOT NULL DEFAULT 0,
        background_style TEXT NOT NULL DEFAULT 'sunrise',
        text_align TEXT NOT NULL DEFAULT 'center',
        font_size REAL NOT NULL DEFAULT 30,
        show_author INTEGER NOT NULL DEFAULT 1,
        remote_uid TEXT,
        remote_category_id TEXT,
        remote_catalog_version TEXT,
        remote_updated_at TEXT,
        imported_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature_name TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        interval_type TEXT,
        interval_value INTEGER,
        start_time TEXT,
        end_time TEXT,
        blocked_days TEXT,
        blocked_dates TEXT,
        blocked_months TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_id INTEGER NOT NULL,
        last_sent TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (setting_id) REFERENCES notification_settings(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS invoices(
      id TEXT PRIMARY KEY,
      number TEXT,
      date INTEGER,
      dueDate INTEGER,
      businessId TEXT,
      customerId TEXT,
      businessName TEXT NOT NULL DEFAULT '',
      businessAddress TEXT NOT NULL DEFAULT '',
      businessEmail TEXT,
      businessPhone TEXT,
      businessTaxId TEXT,
      customerName TEXT,
      customerAddress TEXT,
      customerEmail TEXT,
      customerPhone TEXT,
      purchaseOrderNumber TEXT,
      currencySymbol TEXT NOT NULL DEFAULT 'PKR',
      taxRate REAL NOT NULL DEFAULT 0,
      discountType TEXT NOT NULL DEFAULT 'percentage',
      discountValue REAL NOT NULL DEFAULT 0,
      shippingAmount REAL NOT NULL DEFAULT 0,
      paidAmount REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'draft',
      paymentInfo TEXT,
      terms TEXT,
      notes TEXT,
      footerText TEXT,
      logoPath TEXT,
      backgroundImagePath TEXT,
      templateStyle TEXT NOT NULL DEFAULT 'modern',
      accentColorValue INTEGER NOT NULL DEFAULT 4280640491,
      backgroundOpacity REAL NOT NULL DEFAULT 0.06
    )
  ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers(
        id TEXT PRIMARY KEY,
        name TEXT,
        address TEXT,
        email TEXT,
        phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_business_profiles(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        email TEXT,
        phone TEXT,
        taxId TEXT,
        logoPath TEXT,
        backgroundImagePath TEXT,
        templateStyle TEXT NOT NULL DEFAULT 'modern',
        accentColorValue INTEGER NOT NULL DEFAULT 4280640491,
        backgroundOpacity REAL NOT NULL DEFAULT 0.06,
        currencySymbol TEXT NOT NULL DEFAULT 'PKR',
        defaultTaxRate REAL NOT NULL DEFAULT 0,
        paymentInfo TEXT NOT NULL DEFAULT '',
        terms TEXT,
        customerNote TEXT,
        footerText TEXT,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_customers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        company TEXT,
        address TEXT NOT NULL DEFAULT '',
        email TEXT,
        phone TEXT,
        taxId TEXT,
        notes TEXT,
        usageCount INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastUsedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_preferences(
        id INTEGER PRIMARY KEY CHECK(id = 1),
        defaultDueDays INTEGER NOT NULL DEFAULT 7,
        defaultStatus TEXT NOT NULL DEFAULT 'draft',
        autoSaveBusinesses INTEGER NOT NULL DEFAULT 1,
        autoSaveCustomers INTEGER NOT NULL DEFAULT 1,
        legacyProfilesMigrated INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS invoice_items(
      id TEXT PRIMARY KEY,
      invoiceId TEXT,
      description TEXT,
      sku TEXT,
      unit TEXT NOT NULL DEFAULT 'item',
      quantity REAL,
      unitPrice REAL,
      discountPercent REAL NOT NULL DEFAULT 0,
      FOREIGN KEY(invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_name TEXT NOT NULL,
        loan_type INTEGER NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        interest_amount REAL NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        due_date TEXT,
        status INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'General',
        reference_number TEXT NOT NULL DEFAULT '',
        currency_code TEXT NOT NULL DEFAULT 'PKR',
        installment_frequency TEXT NOT NULL DEFAULT 'none',
        installment_amount REAL NOT NULL DEFAULT 0,
        reminder_enabled INTEGER NOT NULL DEFAULT 1,
        reminder_days_before INTEGER NOT NULL DEFAULT 3,
        last_reminder_at TEXT,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loan_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        transaction_type TEXT NOT NULL DEFAULT 'payment',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        reference_number TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (loan_id) REFERENCES loans (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        original_path TEXT NOT NULL,
        edited_path TEXT,
        media_type TEXT NOT NULL DEFAULT 'image',
        title TEXT NOT NULL DEFAULT '',
        mime_type TEXT,
        extension TEXT,
        file_size INTEGER NOT NULL DEFAULT 0,
        checksum TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_collection_items (
        collection_id INTEGER NOT NULL,
        media_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        added_at TEXT NOT NULL,
        PRIMARY KEY (collection_id, media_id),
        FOREIGN KEY (collection_id) REFERENCES media_collections (id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_files (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_edit_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        media_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        source_path TEXT NOT NULL,
        output_path TEXT NOT NULL,
        metadata_json TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (media_id) REFERENCES media_files (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS backup_restore_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        scope TEXT NOT NULL,
        file_name TEXT,
        file_size INTEGER NOT NULL DEFAULT 0,
        asset_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        message TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS pill_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_system INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS dosage_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_system INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS pills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  dosage_value REAL,
  dose_quantity REAL NOT NULL DEFAULT 1,
  dosage_type_id INTEGER,
  pill_type_id INTEGER,
  color_hex TEXT NOT NULL DEFAULT '#6C63FF',
  track_inventory INTEGER NOT NULL DEFAULT 1,
  notes TEXT,
  start_date TEXT,
  end_date TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (pill_type_id) REFERENCES pill_types(id),
  FOREIGN KEY (dosage_type_id) REFERENCES dosage_types(id)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS schedule_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pill_id INTEGER NOT NULL,

  rule_type TEXT NOT NULL,
  -- ONCE | DAILY | WEEKLY | MONTHLY | INTERVAL

  times TEXT NOT NULL,
  -- JSON array: ["08:00","20:00"]

  days_of_week TEXT,
  -- JSON array for WEEKLY: [1,3,5] (Mon=1)

  days_of_month TEXT,
  -- JSON array for MONTHLY: [1,15]

  interval_days INTEGER,
  -- For INTERVAL type (every X days)

  start_date TEXT NOT NULL,
  end_date TEXT,

  is_active INTEGER DEFAULT 1,
  created_at TEXT,

  FOREIGN KEY (pill_id) REFERENCES pills(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS reminder_occurrences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pill_id INTEGER NOT NULL,
  schedule_rule_id INTEGER,

  scheduled_date TEXT NOT NULL,
  -- yyyy-MM-dd

  scheduled_time TEXT NOT NULL,
  -- HH:mm

  status TEXT DEFAULT 'PENDING',
  -- PENDING | TAKEN | SKIPPED | MISSED

  action_time TEXT,
  -- When user tapped Taken / Skipped

  created_at TEXT,

  FOREIGN KEY (pill_id) REFERENCES pills(id) ON DELETE CASCADE,
  FOREIGN KEY (schedule_rule_id) REFERENCES schedule_rules(id)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS pill_inventory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pill_id INTEGER NOT NULL,

  total_quantity REAL NOT NULL,
  -- Initial stock (e.g. 30 tablets)

  remaining_quantity REAL NOT NULL,

  low_stock_threshold REAL,
  -- Alert when remaining <= this

  last_updated TEXT,

  FOREIGN KEY (pill_id) REFERENCES pills(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS occurrence_generation_tracker (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  pill_id INTEGER NOT NULL,
  schedule_rule_id INTEGER NOT NULL,

  generated_until_date TEXT NOT NULL,
  -- yyyy-MM-dd (last date occurrences exist for)

  last_generated_at TEXT,

  FOREIGN KEY (pill_id) REFERENCES pills(id) ON DELETE CASCADE,
  FOREIGN KEY (schedule_rule_id) REFERENCES schedule_rules(id) ON DELETE CASCADE,

  UNIQUE(pill_id, schedule_rule_id)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS scan_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'scanner',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT '',
  is_favorite INTEGER NOT NULL DEFAULT 0,
  tags TEXT NOT NULL DEFAULT ''
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS scans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  original_path TEXT NOT NULL,
  edited_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  group_id INTEGER,
  sort_id INTEGER NOT NULL DEFAULT 0,
  title TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  ocr_text TEXT NOT NULL DEFAULT '',
  file_size INTEGER NOT NULL DEFAULT 0,
  checksum TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (group_id) REFERENCES scan_groups(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_trees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  cover_image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL DEFAULT '',
  nickname TEXT NOT NULL DEFAULT '',
  gender TEXT NOT NULL DEFAULT 'unspecified',
  birth_date TEXT,
  death_date TEXT,
  phone TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  occupation TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  profile_image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_relationships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  from_member_id INTEGER NOT NULL,
  to_member_id INTEGER NOT NULL,
  relationship_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE,
  FOREIGN KEY (from_member_id) REFERENCES family_members(id) ON DELETE CASCADE,
  FOREIGN KEY (to_member_id) REFERENCES family_members(id) ON DELETE CASCADE,
  UNIQUE(tree_id, from_member_id, to_member_id, relationship_type)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  member_id INTEGER,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  memory_date TEXT,
  media_type TEXT NOT NULL DEFAULT 'text',
  media_path TEXT,
  event_id INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES life_events(id) ON DELETE SET NULL
)
''');

    // Supplemental photos and attendees are separate records so existing
    // family_members / family_memories data remains backward compatible.
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_member_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  member_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_memory_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  memory_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE,
  FOREIGN KEY (memory_id) REFERENCES family_memories(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS family_memory_people (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  memory_id INTEGER NOT NULL,
  member_id INTEGER NOT NULL,
  UNIQUE(memory_id, member_id),
  FOREIGN KEY (memory_id) REFERENCES family_memories(id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE
)
''');

    // Social relationships are separate from genealogy: neither friendships nor
    // colleagues can influence parent/child generations or spouse households.
    await db.execute('''
CREATE TABLE IF NOT EXISTS life_connections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  from_member_id INTEGER NOT NULL,
  to_member_id INTEGER NOT NULL,
  connection_type TEXT NOT NULL,
  custom_label TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  started_at TEXT,
  ended_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE,
  FOREIGN KEY (from_member_id) REFERENCES family_members(id) ON DELETE CASCADE,
  FOREIGN KEY (to_member_id) REFERENCES family_members(id) ON DELETE CASCADE,
  UNIQUE(tree_id, from_member_id, to_member_id, connection_type, custom_label)
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS life_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tree_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  event_type TEXT NOT NULL DEFAULT 'milestone',
  event_date TEXT,
  location TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (tree_id) REFERENCES family_trees(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS life_event_people (
  event_id INTEGER NOT NULL,
  member_id INTEGER NOT NULL,
  PRIMARY KEY(event_id, member_id),
  FOREIGN KEY (event_id) REFERENCES life_events(id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS scan_edit_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scan_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  source_path TEXT NOT NULL,
  output_path TEXT NOT NULL,
  metadata_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
)
''');
  }
}
