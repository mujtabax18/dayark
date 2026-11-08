part of '../device_sync_service.dart';

class DeviceSyncService extends StateNotifier<DeviceSyncState>
    with WidgetsBindingObserver {
  DeviceSyncService(this._databaseService) : super(const DeviceSyncState()) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  final DatabaseService _databaseService;
  HttpServer? _server;
  LocalSyncTls? _tls;
  Future<LocalSyncTls>? _tlsLoading;
  Future<void>? _networkStarting;
  Timer? _timer;
  String? _pairToken;
  String? _pairCode;
  String? _secondaryInviteToken;
  bool _primaryRoleCreatedForPairing = false;
  bool _applyingRemote = false;
  bool _autoRun = true;
  bool _initialized = false;
  bool _logoutInProgress = false;
  DateTime? _syncStartedAt;
  static const _syncInterval = Duration(seconds: 15);
  static const _networkTimeout = Duration(seconds: 10);
  static const _bootstrapTimeout = Duration(minutes: 5);
  static const _localOnlyTables = <String>{
    'backup_restore_history',
  };

  Future<Database> get _db => _databaseService.database;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('sync_device_id');
      if (id == null) {
        id = _randomToken(18);
        await prefs.setString('sync_device_id', id);
      }
      final name =
          prefs.getString('sync_device_name') ?? Platform.localHostname;
      final roleName = prefs.getString('sync_role') ?? 'standalone';
      final role = SyncRole.values.firstWhere(
        (e) => e.name == roleName,
        orElse: () => SyncRole.standalone,
      );
      _autoRun = prefs.getBool('sync_auto_run') ?? true;
      state = state.copyWith(deviceId: id, deviceName: name, role: role);
      await _ensureSchema();
      await _installJournalTriggers();
      await _migrateSyncProtocolIfNeeded(prefs, role);
      // An existing installation may contain years of journal history. None
      // of that history is a new transfer for this version's sync dashboard.
      // Keep the journal itself: outstanding writes must not be discarded.
      await _initializeSyncStatsBaseline();
      await refresh();
      if (role == SyncRole.primary) await refreshLocalBackups();
      _initialized = true;

      // Device sync belongs to the application, not to DeviceSyncScreen. Once a
      // device has been linked, restore the listener/timer automatically on the
      // next app launch and immediately continue any interrupted durable queue.
      if (role != SyncRole.standalone && _autoRun) {
        await startNetworking(userInitiated: false);
        unawaited(syncNow());
      }
    } catch (e) {
      state = state.copyWith(error: 'Sync setup failed: $e');
    }
  }

  Future<void> _ensureSchema() async {
    final db = await _db;
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_devices(
      device_id TEXT PRIMARY KEY, name TEXT NOT NULL, host TEXT NOT NULL DEFAULT '',
      port INTEGER NOT NULL DEFAULT 0, token TEXT NOT NULL DEFAULT '',
      is_primary INTEGER NOT NULL DEFAULT 0, revoked INTEGER NOT NULL DEFAULT 0,
      last_seen TEXT, created_at TEXT NOT NULL)''');
    await _ensureColumn(
      db,
      'sync_devices',
      'previous_token',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(db, 'sync_devices', 'token_issued_at', 'TEXT');
    await _ensureColumn(db, 'sync_devices', 'tls_fingerprint', "TEXT NOT NULL DEFAULT ''");
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_journal(
      id INTEGER PRIMARY KEY AUTOINCREMENT, op_id TEXT NOT NULL UNIQUE,
      origin_device TEXT NOT NULL, table_name TEXT NOT NULL, row_id TEXT NOT NULL,
      operation TEXT NOT NULL, payload TEXT, changed_at TEXT NOT NULL,
      applied INTEGER NOT NULL DEFAULT 0)''');
    // Newer sync builds attach a stable entity id to each row operation. Older
    // installations keep working because these columns are added lazily.
    await _ensureColumn(db, 'sync_journal', 'entity_id', 'TEXT');
    await _ensureColumn(db, 'sync_journal', 'foreign_entities', 'TEXT');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_ack(
      op_id TEXT NOT NULL, device_id TEXT NOT NULL, ack_at TEXT NOT NULL,
      PRIMARY KEY(op_id, device_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_conflicts(
      id INTEGER PRIMARY KEY AUTOINCREMENT, table_name TEXT NOT NULL,
      row_id TEXT NOT NULL, local_payload TEXT, remote_payload TEXT,
      resolved_payload TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_runtime(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_seeded_rows(
      device_id TEXT NOT NULL, table_name TEXT NOT NULL, row_id TEXT NOT NULL,
      seeded_at TEXT NOT NULL, PRIMARY KEY(device_id, table_name, row_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_row_identity(
      table_name TEXT NOT NULL, local_row_id TEXT NOT NULL,
      entity_id TEXT NOT NULL, created_at TEXT NOT NULL,
      PRIMARY KEY(table_name, local_row_id),
      UNIQUE(table_name, entity_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_remote_row_map(
      origin_device TEXT NOT NULL, table_name TEXT NOT NULL,
      remote_row_id TEXT NOT NULL, local_row_id TEXT NOT NULL,
      entity_id TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY(origin_device, table_name, remote_row_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_bootstrap(
      device_id TEXT PRIMARY KEY, needs_bootstrap INTEGER NOT NULL DEFAULT 1,
      cutoff_journal_id INTEGER NOT NULL DEFAULT 0, snapshot_id TEXT,
      snapshot_created_at TEXT, completed_at TEXT)''');
    await _ensureColumn(
      db,
      'sync_bootstrap',
      'needs_bootstrap',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      'sync_bootstrap',
      'cutoff_journal_id',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(db, 'sync_bootstrap', 'snapshot_id', 'TEXT');
    await _ensureColumn(db, 'sync_bootstrap', 'snapshot_created_at', 'TEXT');
    await _ensureColumn(db, 'sync_bootstrap', 'completed_at', 'TEXT');
    // Backup/restore history is intentionally local to each device. Older
    // versions may already have journaled those rows; discard them once.
    await db.delete(
      'sync_journal',
      where: 'table_name=?',
      whereArgs: ['backup_restore_history'],
    );
    // A process crash during restore must not leave journaling permanently
    // disabled on the next launch. No restore is active during initialization.
    await db.insert(
      'sync_runtime',
      {'key': 'applying_remote', 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Dashboard statistics are NOT the total size of the durable replication
  // journal. A full snapshot is the baseline; only changes made after that
  // baseline count as sent/received. The floors are local runtime metadata and
  // do not affect which unsent operations are eligible for delivery.
  static const _statsJournalFloorKey = 'sync_stats_journal_floor_v3';
  static const _statsConflictFloorKey = 'sync_stats_conflict_floor_v3';

  Future<void> _initializeSyncStatsBaseline() async {
    final db = await _db;
    final existing = await db.query(
      'sync_runtime',
      columns: const ['key'],
      where: 'key IN (?, ?)',
      whereArgs: [_statsJournalFloorKey, _statsConflictFloorKey],
    );
    final keys = existing.map((e) => e['key']?.toString()).toSet();
    if (!keys.contains(_statsJournalFloorKey)) {
      final last = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(MAX(id), 0) FROM sync_journal'),
      ) ?? 0;
      await db.insert('sync_runtime', {
        'key': _statsJournalFloorKey,
        'value': '$last',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (!keys.contains(_statsConflictFloorKey)) {
      final last = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(MAX(id), 0) FROM sync_conflicts'),
      ) ?? 0;
      await db.insert('sync_runtime', {
        'key': _statsConflictFloorKey,
        'value': '$last',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _resetSyncStatsBaseline({bool emptyJournal = false}) async {
    final db = await _db;
    final lastJournal = emptyJournal
        ? 0
        : Sqflite.firstIntValue(
              await db.rawQuery('SELECT COALESCE(MAX(id), 0) FROM sync_journal'),
            ) ?? 0;
    final lastConflict = emptyJournal
        ? 0
        : Sqflite.firstIntValue(
              await db.rawQuery('SELECT COALESCE(MAX(id), 0) FROM sync_conflicts'),
            ) ?? 0;
    await db.transaction((txn) async {
      await txn.insert('sync_runtime', {
        'key': _statsJournalFloorKey,
        'value': '$lastJournal',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_runtime', {
        'key': _statsConflictFloorKey,
        'value': '$lastConflict',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _migrateSyncProtocolIfNeeded(
    SharedPreferences prefs,
    SyncRole role,
  ) async {
    const protocolVersion = 2;
    final current = prefs.getInt('sync_protocol_version') ?? 1;
    if (current >= protocolVersion) return;

    if (role == SyncRole.primary) {
      final db = await _db;
      await _requireFreshBootstrapForSecondaries(db);
    }
    await prefs.setInt('sync_protocol_version', protocolVersion);
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info("${table.replaceAll('"', '""')}")',
    );
    if (columns.any((c) => c['name']?.toString() == column)) return;
    await db.execute(
      'ALTER TABLE "${table.replaceAll('"', '""')}" ADD COLUMN "${column.replaceAll('"', '""')}" $definition',
    );
  }

  Future<void> _installJournalTriggers() async {
    final db = await _db;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%'",
    );
    for (final item in tables) {
      final table = item['name']?.toString();
      if (table == null || table.isEmpty) continue;
      final safe = table.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
      if (_localOnlyTables.contains(table)) {
        await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_ai');
        await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_au');
        await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_ad');
        continue;
      }
      final cols = await db.rawQuery(
        'PRAGMA table_info("${table.replaceAll('"', '""')}")',
      );
      if (cols.isEmpty) continue;
      final pk = cols.where((c) => (c['pk'] as num? ?? 0) > 0).toList();
      if (pk.length != 1)
        continue; // composite/system tables remain local-only.
      final pkName = pk.first['name'].toString().replaceAll('"', '""');
      final jsonNew = <String>[];
      final jsonOld = <String>[];
      for (final c in cols) {
        final raw = c['name'].toString();
        final q = raw.replaceAll('"', '""');
        final key = raw.replaceAll("'", "''");
        jsonNew.add("'$key', NEW.\"$q\"");
        jsonOld.add("'$key', OLD.\"$q\"");
      }
      await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_ai');
      await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_au');
      await db.execute('DROP TRIGGER IF EXISTS sync_${safe}_ad');
      final guard =
          "COALESCE((SELECT value FROM sync_runtime WHERE key='applying_remote'),'0') <> '1'";
      final changedColumns = cols.map((c) {
        final q = c['name'].toString().replaceAll('"', '""');
        return 'OLD."$q" IS NOT NEW."$q"';
      }).join(' OR ');
      await db.execute(
        '''CREATE TRIGGER sync_${safe}_ai AFTER INSERT ON "$table" WHEN $guard BEGIN
        INSERT INTO sync_journal(op_id,origin_device,table_name,row_id,operation,payload,changed_at)
        VALUES(lower(hex(randomblob(16))),'${state.deviceId}', '${table.replaceAll("'", "''")}', CAST(NEW."$pkName" AS TEXT),'upsert',json_object(${jsonNew.join(',')}),strftime('%Y-%m-%dT%H:%M:%fZ','now'));
      END''',
      );
      await db.execute(
        '''CREATE TRIGGER sync_${safe}_au AFTER UPDATE ON "$table" WHEN $guard AND ($changedColumns) BEGIN
        INSERT INTO sync_journal(op_id,origin_device,table_name,row_id,operation,payload,changed_at)
        VALUES(lower(hex(randomblob(16))),'${state.deviceId}', '${table.replaceAll("'", "''")}', CAST(NEW."$pkName" AS TEXT),'upsert',json_object(${jsonNew.join(',')}),strftime('%Y-%m-%dT%H:%M:%fZ','now'));
      END''',
      );
      await db.execute(
        '''CREATE TRIGGER sync_${safe}_ad AFTER DELETE ON "$table" WHEN $guard BEGIN
        INSERT INTO sync_journal(op_id,origin_device,table_name,row_id,operation,payload,changed_at)
        VALUES(lower(hex(randomblob(16))),'${state.deviceId}', '${table.replaceAll("'", "''")}', CAST(OLD."$pkName" AS TEXT),'delete',json_object(${jsonOld.join(',')}),strftime('%Y-%m-%dT%H:%M:%fZ','now'));
      END''',
      );
    }
  }

  /// Adds every pre-existing business row to the durable journal once.
  /// This is what makes the first pairing a full historical sync instead of
  /// only syncing writes that happen after pairing.
  Future<int> _seedHistoricalData() async {
    final db = await _db;
    final markerKey = 'history_seed_complete:${state.deviceId}';
    final marker = await db.query(
      'sync_runtime',
      columns: ['value'],
      where: 'key=?',
      whereArgs: [markerKey],
      limit: 1,
    );
    if (marker.isNotEmpty && marker.first['value'] == '1') return 0;

    var seeded = 0;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%'",
    );
    await db.transaction((txn) async {
      for (final item in tables) {
        final table = item['name']?.toString();
        if (table == null || table.isEmpty) continue;
        final safeTable = table.replaceAll('\"', '\"\"');
        final cols = await txn.rawQuery('PRAGMA table_info("$safeTable")');
        final pk = cols.where((c) => (c['pk'] as num? ?? 0) > 0).toList();
        if (pk.length != 1) continue;
        final pkName = pk.first['name'].toString();
        final rows = await txn.query(table);
        for (final row in rows) {
          final rowId = row[pkName]?.toString();
          if (rowId == null) continue;
          final alreadySeeded = await txn.query(
            'sync_seeded_rows',
            columns: ['row_id'],
            where: 'device_id=? AND table_name=? AND row_id=?',
            whereArgs: [state.deviceId, table, rowId],
            limit: 1,
          );
          if (alreadySeeded.isNotEmpty) continue;

          // If this row already has a local journal entry, it is already
          // represented by its latest local write and does not need a second
          // bootstrap operation.
          final existingJournal = await txn.query(
            'sync_journal',
            columns: ['id'],
            where: 'origin_device=? AND table_name=? AND row_id=?',
            whereArgs: [state.deviceId, table, rowId],
            limit: 1,
          );
          if (existingJournal.isEmpty) {
            await txn.insert('sync_journal', {
              'op_id': _randomToken(24),
              'origin_device': state.deviceId,
              'table_name': table,
              'row_id': rowId,
              'operation': 'bootstrap_upsert',
              'payload': jsonEncode(_encodePayload(row)),
              'changed_at': DateTime.now().toUtc().toIso8601String(),
              'applied': 0,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            seeded++;
          }
          await txn.insert('sync_seeded_rows', {
            'device_id': state.deviceId,
            'table_name': table,
            'row_id': rowId,
            'seeded_at': DateTime.now().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
    await db.insert('sync_runtime', {
      'key': markerKey,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return seeded;
  }

  Future<void> _resetHistoricalSeedMarker(Database db) async {
    await db.delete(
      'sync_runtime',
      where: 'key=?',
      whereArgs: ['history_seed_complete:${state.deviceId}'],
    );
  }

  static Map<String, dynamic> _encodePayload(Map<String, Object?> row) {
    return row.map((key, value) {
      if (value is List<int>) {
        return MapEntry(key, {'__dayark_blob__': base64Encode(value)});
      }
      return MapEntry(key, value);
    });
  }

  static Map<String, dynamic> _decodePayload(String raw) {
    final decoded = (jsonDecode(raw) as Map).map(
      (k, v) => MapEntry(k.toString(), v),
    );
    return decoded.map((key, value) {
      if (value is Map &&
          value.length == 1 &&
          value['__dayark_blob__'] is String) {
        return MapEntry(key, base64Decode(value['__dayark_blob__'] as String));
      }
      return MapEntry(key, value);
    });
  }

  Future<void> setDeviceName(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_device_name', v);
    state = state.copyWith(deviceName: v);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Never stop merely because the user navigated away or minimized the app.
    // Android/iOS may still suspend the process themselves; when Flutter is
    // resumed we reopen the LAN listener and drain the durable queue.
    if (!_initialized || !_autoRun || state.role == SyncRole.standalone) return;
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(_resumeAfterLifecycleChange());
    } else if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      // Push anything already queued before the OS potentially suspends us.
      unawaited(syncNow());
    }
  }

  Future<void> _resumeAfterLifecycleChange() async {
    await startNetworking(userInitiated: false);
    await syncNow();
  }

  Future<void> becomePrimary() async {
    if (state.role == SyncRole.secondary) {
      state = state.copyWith(
        error: 'This device is already linked as a secondary. Create new pairing codes from the primary device, or logout/forget this link first.',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_role', SyncRole.primary.name);
    await prefs.setBool('sync_auto_run', true);
    _autoRun = true;
    state = state.copyWith(role: SyncRole.primary, clearError: true);
    await _resetSyncStatsBaseline();
    await refreshLocalBackups();
    await startNetworking();
  }

  Future<void> startNetworking({bool userInitiated = true}) async {
    if (userInitiated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_auto_run', true);
      _autoRun = true;
    }
    // Pairing and the background initialization can start simultaneously.
    // Only one operation may bind the fixed listener port at a time.
    if (_networkStarting != null) {
      await _networkStarting;
      return;
    }
    if (_server != null) {
      if (!state.running) state = state.copyWith(running: true);
      _ensureSyncTimer();
      return;
    }
    final pending = _startSecureNetworkingOnce();
    _networkStarting = pending;
    try {
      await pending;
    } finally {
      _networkStarting = null;
    }
  }

  Future<void> _startSecureNetworkingOnce() async {
    try {
      // All platforms use exactly one fixed TCP port; there is NO HTTP,
      // insecure certificate, or random-port fallback.
      _tlsLoading ??= LocalSyncTls.loadOrCreate();
      final identity = await _tlsLoading!;
      _tls = identity;

      // Migrating from the v1 ASN.1 certificate format generates a new TLS
      // identity. Old fingerprints are no longer valid: mark existing peers as
      // needing explicit secure re-pairing, preserving their data and journals.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('sync_tls_identity_version') != LocalSyncTls.identityVersion) {
        final db = await _db;
        await db.update(
          'sync_devices',
          {'tls_fingerprint': ''},
          where: 'revoked=0',
        );
        await prefs.setInt('sync_tls_identity_version', LocalSyncTls.identityVersion);
        await refresh();
      }

      _server = await HttpServer.bindSecure(
        InternetAddress.anyIPv4,
        LocalSyncTls.syncPort,
        identity.serverContext,
        shared: false,
      );
      _server!.listen(
        _handleRequest,
        onError: (e) => state = state.copyWith(error: '$e'),
        cancelOnError: false,
      );
      state = state.copyWith(running: true, clearError: true);
      _ensureSyncTimer();
      await refresh();
    } on SocketException catch (e) {
      // Do not silently switch to an unpredictable port when firewall rules
      // and existing QR codes expect a known listener.
      state = state.copyWith(
        running: false,
        syncing: false,
        error: 'Cannot listen for secure LAN sync on TCP '
            '${LocalSyncTls.syncPort}: ${e.message}. '
            'Check that another instance is not using the port, and allow '
            'incoming TCP ${LocalSyncTls.syncPort} in the computer firewall.',
      );
    } catch (e) {
      _tlsLoading = null;
      state = state.copyWith(
        running: false,
        syncing: false,
        error: 'Could not start secure local sync: $e',
      );
    }
  }

  void _ensureSyncTimer() {
    if (_timer?.isActive == true) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      _syncInterval,
      (_) => unawaited(_runLightweightSyncTick()),
    );
  }

  Future<void> _runLightweightSyncTick() async {
    if (!_initialized ||
        !_autoRun ||
        state.role == SyncRole.standalone ||
        state.syncing ||
        state.firstSyncing ||
        state.backupBusy) {
      return;
    }

    try {
      final db = await _db;
      final activePeer = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT 1 FROM sync_devices WHERE revoked=0 LIMIT 1',
        ),
      );
      if (activePeer == null) return;
      await syncNow();
    } catch (_) {
      // Keep the background tick silent. A manual sync still surfaces errors,
      // while the next lightweight tick retries durable pending operations.
    }
  }

  Future<void> stopNetworking({bool userInitiated = true}) async {
    if (userInitiated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_auto_run', false);
      _autoRun = false;
    }
    _timer?.cancel();
    _timer = null;
    if (_networkStarting != null) await _networkStarting;
    await _server?.close(force: true);
    _server = null;
    _syncStartedAt = null;
    state = state.copyWith(running: false, syncing: false, clearPairing: true);
  }

  Future<void> createPairing() async {
    if (state.role == SyncRole.standalone) {
      _primaryRoleCreatedForPairing = true;
    }
    if (state.role != SyncRole.primary) await becomePrimary();
    if (state.role != SyncRole.primary) return;
    if (_server == null) await startNetworking();
    final ip = await _localIpv4();
    if (_server == null) return; // Preserve the port/TLS listener error.
    if (ip == null) {
      state = state.copyWith(
        error: 'Connect both devices to the same Wi‑Fi/LAN first.',
      );
      return;
    }
    _pairToken = _randomToken(32);
    _pairCode = (100000 + Random.secure().nextInt(900000)).toString();
    final url =
        'dayark://pair?host=$ip&port=${_server!.port}&token=$_pairToken&code=$_pairCode&fp=${_tls!.fingerprint}&primary=${Uri.encodeComponent(state.deviceName)}';
    state = state.copyWith(
      pairingUrl: url,
      pairingCode: _pairCode,
      clearError: true,
    );
  }

  /// Cancel a pending pairing invitation and restore standalone mode.
  /// Existing paired devices must be disconnected explicitly so cancelling
  /// an invitation never silently breaks an established synchronization.
  Future<void> cancelPairing() async {
    if (state.firstSyncing || state.backupBusy || state.syncing) return;

    _pairToken = null;
    _pairCode = null;
    _secondaryInviteToken = null;
    _primaryRoleCreatedForPairing = false;

    try {
      final db = await _db;
      final peerCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM sync_devices WHERE revoked=0',
          )) ?? 0;

      if (peerCount != 0) {
        // Only dismiss this invitation: active device relationships are kept.
        state = state.copyWith(clearPairing: true, clearError: true);
        return;
      }

      // Works for either QR type, including a primary role saved before the
      // screen was reopened. Keep application data and sync history intact.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_role', SyncRole.standalone.name);
      await stopNetworking(userInitiated: false);
      state = state.copyWith(
        role: SyncRole.standalone,
        devices: const [],
        clearPairing: true,
        clearError: true,
        clearActivity: true,
      );
    } catch (e) {
      state = state.copyWith(
        clearPairing: true,
        error: 'Could not cancel pairing: $e',
      );
    }
  }

  /// Advertise this device as a secondary without changing its sync role.
  Future<void> createSecondaryQr() async {
    if (state.role == SyncRole.primary) {
      state = state.copyWith(error: 'A primary cannot advertise itself as a secondary.');
      return;
    }
    await startNetworking();
    final ip = await _localIpv4();
    if (_server == null) return; // Preserve the port/TLS listener error.
    if (ip == null) {
      state = state.copyWith(error: 'Connect both devices to the same local network first.');
      return;
    }
    _secondaryInviteToken = _randomToken(32);
    state = state.copyWith(
      pairingUrl: 'dayark://secondary?host=$ip&port=${_server!.port}&token=$_secondaryInviteToken&fp=${_tls!.fingerprint}',
      pairingCode: 'Secondary device',
      clearError: true,
    );
  }

  /// The scanning primary sends its normal pairing URL to the waiting secondary.
  Future<void> pairSecondaryFromQr(String raw) async {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'dayark' || uri.host != 'secondary') {
        throw const FormatException('Invalid secondary QR code');
      }
      if (state.role == SyncRole.secondary) {
        throw StateError('This device is already a secondary.');
      }
      // The scanned QR authenticates the waiting secondary's TLS identity.
      final secondaryFingerprint = uri.queryParameters['fp'];
      final inviteToken = uri.queryParameters['token'];
      if (inviteToken == null || inviteToken.isEmpty ||
          !LocalSyncTls.isValidFingerprint(secondaryFingerprint)) {
        throw const FormatException('A current secure secondary QR is required.');
      }
      await createPairing();
      if (state.pairingUrl == null) throw StateError('Could not create primary pairing code');
      final client = LocalSyncTls.pinnedClient(
        secondaryFingerprint, timeout: const Duration(seconds: 8));
      try {
        final request = await client.postUrl(LocalSyncTls.endpoint(
          uri.queryParameters['host']!,
          int.parse(uri.queryParameters['port']!),
          '/secondary-invite',
        ));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({
          'token': uri.queryParameters['token'],
          'pairingUrl': state.pairingUrl,
        }));
        final response = await request.close();
        final result = await utf8.decoder.bind(response).join();
        if (response.statusCode != 200) throw StateError(result);
        state = state.copyWith(clearError: true, clearPairing: true);
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      state = state.copyWith(error: 'Secondary QR pairing failed: $e');
    }
  }

  Future<void> connectWithUrl(String raw, {String? name}) async {
    if (state.role == SyncRole.primary) {
      state = state.copyWith(
        error: 'This device is the primary. Logout/forget its current sync group before joining another primary.',
      );
      return;
    }
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'dayark' || uri.host != 'pair')
        throw const FormatException('Invalid DayArk pairing URL');
      final host = uri.queryParameters['host']!;
      final port = int.parse(uri.queryParameters['port']!);
      if (port != LocalSyncTls.syncPort) {
        throw const FormatException('Old pairing URL uses a different port. Generate a fresh QR on the updated device.');
      }
      final token = uri.queryParameters['token']!;
      final code = uri.queryParameters['code']!;
      final primaryFingerprint = uri.queryParameters['fp'];
      if (!LocalSyncTls.isValidFingerprint(primaryFingerprint)) {
        throw const FormatException('This is an older, insecure pairing QR. Generate a new QR on the updated primary.');
      }

      // Start our listener before pairing so the primary learns the secondary
      // device's LAN port and can also initiate sync back to it.
      if (_server == null) await startNetworking();
      if (_server == null || _tls == null) {
        throw StateError(
          state.error ?? 'Could not start secure listener on TCP ${LocalSyncTls.syncPort}.',
        );
      }

      final client = LocalSyncTls.pinnedClient(primaryFingerprint);
      final req = await client.postUrl(LocalSyncTls.endpoint(host, port, '/pair'));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'token': token,
          'code': code,
          'deviceId': state.deviceId,
          'name': name?.trim().isNotEmpty == true
              ? name!.trim()
              : state.deviceName,
          'listenPort': _server?.port ?? 0,
          'listenFingerprint': _tls!.fingerprint,
        }),
      );
      final res = await req.close().timeout(_networkTimeout);
      final pairingResponse = await utf8.decoder
          .bind(res)
          .join()
          .timeout(_networkTimeout);
      final body = jsonDecode(pairingResponse) as Map<String, dynamic>;
      client.close(force: true);
      if (res.statusCode != 200)
        throw Exception(body['error'] ?? 'Pairing rejected');
      final db = await _db;
      final oldPrimaryRows = await db.query(
        'sync_devices',
        columns: ['token'],
        where: 'device_id=?',
        whereArgs: [body['deviceId']],
        limit: 1,
      );
      final previousPrimaryToken = oldPrimaryRows.isEmpty
          ? ''
          : oldPrimaryRows.first['token']?.toString() ?? '';
      await db.delete(
        'sync_devices',
        where: 'is_primary=1 AND device_id<>?',
        whereArgs: [body['deviceId']],
      );
      await db.insert('sync_devices', {
        'device_id': body['deviceId'],
        'name': body['name'],
        'host': host,
        'port': port,
        'token': body['deviceToken'],
        'tls_fingerprint': primaryFingerprint,
        'previous_token': previousPrimaryToken,
        'token_issued_at': DateTime.now().toUtc().toIso8601String(),
        'is_primary': 1,
        'revoked': 0,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_role', SyncRole.secondary.name);
      await prefs.setBool('sync_auto_run', true);
      _autoRun = true;
      state = state.copyWith(role: SyncRole.secondary, clearError: true);
      await startNetworking();
      final primaryPeer = <String, Object?>{
        'device_id': body['deviceId'],
        'host': host,
        'port': port,
        'token': body['deviceToken'],
        'tls_fingerprint': primaryFingerprint,
      };
      final bootstrapped = await _bootstrapFromPrimary(primaryPeer);
      if (bootstrapped) await syncNow();
    } catch (e) {
      state = state.copyWith(error: 'Pairing failed: $e');
    }
  }

  Future<bool> _peerNeedsBootstrap(Database db, String peerId) async {
    final rows = await db.query(
      'sync_bootstrap',
      columns: const ['needs_bootstrap'],
      where: 'device_id=?',
      whereArgs: [peerId],
      limit: 1,
    );
    return rows.isNotEmpty && (rows.first['needs_bootstrap'] as num? ?? 0) == 1;
  }

  Future<Map<String, Object?>?> _authenticatedPeer(
    Database db,
    String peerId,
    String token,
  ) async {
    final rows = await db.query(
      'sync_devices',
      where: 'device_id=?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty || (rows.first['revoked'] as num? ?? 0) == 1) {
      return null;
    }
    final row = rows.first;
    final currentToken = row['token']?.toString() ?? '';
    final previousToken = row['previous_token']?.toString() ?? '';
    if (token != currentToken && token != previousToken) return null;
    if (token == currentToken && previousToken.isNotEmpty) {
      await db.update(
        'sync_devices',
        {'previous_token': ''},
        where: 'device_id=?',
        whereArgs: [peerId],
      );
    }
    return row;
  }

  Future<List<Map<String, String>>> _snapshotIdentityRows(Database db) async {
    final result = <Map<String, String>>[];
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%'",
    );
    for (final item in tables) {
      final table = item['name']?.toString() ?? '';
      if (table.isEmpty || _localOnlyTables.contains(table)) continue;
      final info = await db.rawQuery(
        'PRAGMA table_info("${table.replaceAll('"', '""')}")',
      );
      final pk = info.where((c) => (c['pk'] as num? ?? 0) > 0).toList();
      if (pk.length != 1) continue;
      final pkName = pk.first['name'].toString();
      final rows = await db.query(table);
      for (final raw in rows) {
        final rowId = raw[pkName]?.toString() ?? '';
        if (rowId.isEmpty) continue;
        final entityId = await _ensureEntityForLocalRow(
          db,
          table: table,
          localRowId: rowId,
          payload: Map<String, dynamic>.from(raw),
          originDevice: state.deviceId,
        );
        result.add({
          'table': table,
          'row_id': rowId,
          'entity_id': entityId,
        });
      }
    }
    return result;
  }

  Future<PortableBackupPackage> _createSyncSnapshot(Database db) async {
    final identityRows = await _snapshotIdentityRows(db);
    final identityBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'source_device_id': state.deviceId,
          'rows': identityRows,
        }),
      ),
    );
    return BackupService.createPortableBackup(
      db,
      scope: PortableBackupScope.fullDatabase,
      excludedTables: _localOnlyTables,
      excludedTablePrefixes: const ['sync_'],
      additionalFiles: {'sync_identity.json': identityBytes},
    );
  }

  static Future<Map<String, String>> _readSnapshotIdentityMap(
    File zipFile,
  ) async {
    final zipBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? identityFile;
    for (final entry in archive) {
      if (entry.isFile &&
          entry.name.replaceAll('\\', '/') == 'sync_identity.json') {
        identityFile = entry;
        break;
      }
    }
    if (identityFile == null) return const {};
    final bytes = identityFile.readBytes();
    if (bytes == null) return const {};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['rows'] is! List) return const {};
    final result = <String, String>{};
    for (final raw in decoded['rows'] as List) {
      if (raw is! Map) continue;
      final table = raw['table']?.toString() ?? '';
      final rowId = raw['row_id']?.toString() ?? '';
      final entityId = raw['entity_id']?.toString() ?? '';
      if (table.isEmpty || rowId.isEmpty || entityId.isEmpty) continue;
      result['$table\u0000$rowId'] = entityId;
    }
    return result;
  }

  Future<void> _prepareSecondaryForBootstrap(Database db) async {
    await db.transaction((txn) async {
      await txn.insert(
        'sync_runtime',
        {'key': 'applying_remote', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('sync_ack');
      await txn.delete('sync_journal');
      await txn.delete('sync_conflicts');
      await txn.delete('sync_seeded_rows');
      await txn.delete('sync_row_identity');
      await txn.delete('sync_remote_row_map');
      await txn.delete(
        'sync_runtime',
        where: 'key LIKE ?',
        whereArgs: ['bootstrap_pending_ack:%'],
      );
    });
  }

  Future<void> _finishBootstrapRuntime(Database db) async {
    await db.insert(
      'sync_runtime',
      {'key': 'applying_remote', 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _bindBootstrapSnapshotToPrimary(
    Database db,
    String primaryDeviceId,
    Map<String, String> identityMap,
  ) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%'",
    );
    await db.transaction((txn) async {
      for (final item in tables) {
        final table = item['name']?.toString() ?? '';
        if (table.isEmpty || _localOnlyTables.contains(table)) continue;
        final info = await txn.rawQuery(
          'PRAGMA table_info("${table.replaceAll('"', '""')}")',
        );
        final pk = info.where((c) => (c['pk'] as num? ?? 0) > 0).toList();
        if (pk.length != 1) continue;
        final pkName = pk.first['name'].toString();
        final rows = await txn.query(table);
        for (final raw in rows) {
          final rowId = raw[pkName]?.toString();
          if (rowId == null || rowId.isEmpty) continue;
          final payload = Map<String, dynamic>.from(raw);
          final entityId = identityMap['$table\u0000$rowId'] ??
              _deriveEntityId(
                table: table,
                payload: payload,
                originDevice: primaryDeviceId,
                rowId: rowId,
              );
          await txn.insert(
            'sync_row_identity',
            {
              'table_name': table,
              'local_row_id': rowId,
              'entity_id': entityId,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            'sync_remote_row_map',
            {
              'origin_device': primaryDeviceId,
              'table_name': table,
              'remote_row_id': rowId,
              'local_row_id': rowId,
              'entity_id': entityId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<bool> _ackBootstrap(
    Map<String, Object?> peer, {
    bool silent = false,
  }) async {
    final host = peer['host']?.toString() ?? '';
    final port = (peer['port'] as num?)?.toInt() ?? 0;
    final peerId = peer['device_id']?.toString() ?? '';
    final token = peer['token']?.toString() ?? '';
    if (host.isEmpty || port == 0 || peerId.isEmpty || token.isEmpty) {
      return false;
    }
    final db = await _db;
    final marker = await db.query(
      'sync_runtime',
      columns: const ['value'],
      where: 'key=?',
      whereArgs: ['bootstrap_pending_ack:$peerId'],
      limit: 1,
    );
    final snapshotId =
        marker.isEmpty ? '' : marker.first['value']?.toString() ?? '';
    if (snapshotId.isEmpty) return false;

    HttpClient? client;
    try {
      client = LocalSyncTls.pinnedClient(peer['tls_fingerprint']?.toString());
      final request = await client.postUrl(LocalSyncTls.endpoint(host, port, '/bootstrap/ack'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'deviceId': state.deviceId,
          'token': token,
          'snapshotId': snapshotId,
        }),
      );
      final response = await request.close().timeout(_networkTimeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_networkTimeout);
      final body = responseText.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseText) as Map<String, dynamic>;
      if (response.statusCode == 403 && body['revoked'] == true) {
        await _logoutAfterRevocation();
        return false;
      }
      if (response.statusCode != 200) {
        if (!silent) {
          state = state.copyWith(
            error: body['error']?.toString() ?? 'Could not confirm first sync.',
          );
        }
        return false;
      }
      await db.delete(
        'sync_runtime',
        where: 'key=?',
        whereArgs: ['bootstrap_pending_ack:$peerId'],
      );
      return true;
    } catch (e) {
      if (!silent) state = state.copyWith(error: 'First sync confirmation failed: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _bootstrapFromPrimary(Map<String, Object?> peer) async {
    if (state.role != SyncRole.secondary) return false;
    final host = peer['host']?.toString() ?? '';
    final port = (peer['port'] as num?)?.toInt() ?? 0;
    final primaryId = peer['device_id']?.toString() ?? '';
    final token = peer['token']?.toString() ?? '';
    if (host.isEmpty || port == 0 || primaryId.isEmpty || token.isEmpty) {
      state = state.copyWith(error: 'Primary device network details are incomplete.');
      return false;
    }

    // Never let an acknowledgement from an older pairing/bootstrap session
    // unlock a newly requested baseline. A fresh marker is written only after
    // the new snapshot has been imported successfully.
    final runtimeDb = await _db;
    await runtimeDb.delete(
      'sync_runtime',
      where: 'key=?',
      whereArgs: ['bootstrap_pending_ack:$primaryId'],
    );

    final wasSyncing = state.syncing;
    state = state.copyWith(
      firstSyncing: true,
      syncing: true,
      activity: 'Preparing first sync from the primary device…',
      clearError: true,
    );

    File? tempFile;
    HttpClient? client;
    try {
      client = LocalSyncTls.pinnedClient(
        peer['tls_fingerprint']?.toString(), timeout: const Duration(seconds: 8))
        ..idleTimeout = _bootstrapTimeout;
      final request = await client.postUrl(LocalSyncTls.endpoint(host, port, '/bootstrap'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'deviceId': state.deviceId,
          'token': token,
        }),
      );
      state = state.copyWith(activity: 'Downloading compressed first-sync snapshot…');
      final response = await request.close().timeout(_bootstrapTimeout);
      if (response.statusCode == 403) {
        final text = await utf8.decoder.bind(response).join();
        final body = text.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(text) as Map<String, dynamic>;
        if (body['revoked'] == true) await _logoutAfterRevocation();
        throw Exception(body['error'] ?? 'Primary rejected the device.');
      }
      if (response.statusCode != 200) {
        final text = await utf8.decoder.bind(response).join();
        throw Exception(text.isEmpty ? 'Snapshot download failed.' : text);
      }
      final snapshotId =
          response.headers.value('x-dayark-bootstrap-id')?.trim() ?? '';
      if (snapshotId.isEmpty) {
        throw const FormatException('Primary did not identify the first-sync snapshot.');
      }

      final temp = await getTemporaryDirectory();
      tempFile = File(
        p.join(
          temp.path,
          'dayark_sync_${DateTime.now().microsecondsSinceEpoch}.housezip',
        ),
      );
      final expectedBytes = response.contentLength;
      var receivedBytes = 0;
      var lastUiUpdate = 0;
      final sink = tempFile.openWrite();
      try {
        await for (final chunk in response.timeout(_bootstrapTimeout)) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (receivedBytes - lastUiUpdate >= 512 * 1024) {
            lastUiUpdate = receivedBytes;
            final receivedMb = receivedBytes / (1024 * 1024);
            final totalText = expectedBytes > 0
                ? ' / ${(expectedBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                : '';
            state = state.copyWith(
              activity:
                  'Downloading compressed first-sync snapshot… ${receivedMb.toStringAsFixed(1)} MB$totalText',
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (receivedBytes == 0) {
        throw const FormatException('Primary returned an empty first-sync snapshot.');
      }
      final identityMap = await _readSnapshotIdentityMap(tempFile);

      // Re-pairing or a primary restore can replace an already-used secondary.
      // Preserve its old local data before making any destructive changes.
      // If this backup fails (e.g. not enough storage), abort the bootstrap.
      state = state.copyWith(activity: 'Saving a secondary safety backup…');
      await _writeSecondarySafetyBackup();
      state = state.copyWith(activity: 'Replacing secondary data with primary snapshot…');
      final db = await _db;
      await _prepareSecondaryForBootstrap(db);
      try {
        await DatabaseRestoreService.restorePortableZip(db, tempFile, allowLegacy: true);
        state = state.copyWith(activity: 'Finalizing row mappings for incremental sync…');
        await _bindBootstrapSnapshotToPrimary(
          db,
          primaryId,
          identityMap,
        );
      } finally {
        await _finishBootstrapRuntime(db);
      }
      // The imported rows are the starting state, not thousands of received
      // changes. The journal was emptied before restore, and local triggers
      // were suppressed while the snapshot was applied.
      await _resetSyncStatsBaseline(emptyJournal: true);

      await db.insert(
        'sync_runtime',
        {'key': 'bootstrap_pending_ack:$primaryId', 'value': snapshotId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      state = state.copyWith(activity: 'Confirming first sync with the primary…');
      final acknowledged = await _ackBootstrap(peer, silent: true);
      if (!acknowledged) {
        state = state.copyWith(
          error: 'Data was imported successfully, but the primary has not confirmed it yet. The app will retry automatically.',
        );
      }
      await _installJournalTriggers();
      await refresh();
      // Returning success without an acknowledged snapshot would immediately
      // restart the download on the next 409 response. Instead, retain the
      // pending ACK and retry it without ever re-importing a completed snapshot.
      return acknowledged;
    } catch (e) {
      state = state.copyWith(error: 'First sync failed: $e');
      return false;
    } finally {
      client?.close(force: true);
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      state = state.copyWith(
        firstSyncing: false,
        syncing: wasSyncing,
        clearActivity: true,
      );
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      if (req.method == 'POST' && req.uri.path == '/secondary-invite') {
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        if (_secondaryInviteToken == null ||
            body['token'] != _secondaryInviteToken ||
            state.role == SyncRole.primary ||
            body['pairingUrl'] is! String) {
          return _json(req.response, 403, {'error': 'Secondary invitation rejected'});
        }
        _secondaryInviteToken = null; // One-time invitation.
        _json(req.response, 200, {'accepted': true});
        state = state.copyWith(clearPairing: true);
        unawaited(connectWithUrl(body['pairingUrl'] as String));
        return;
      }
      if (req.method == 'POST' && req.uri.path == '/pair') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        if (state.role != SyncRole.primary ||
            body['token'] != _pairToken ||
            body['code'] != _pairCode) {
          return _json(req.response, 403, {
            'error': 'Pairing code expired or rejected',
          });
        }
        final peerId = body['deviceId']?.toString() ?? '';
        final secondaryFingerprint = body['listenFingerprint']?.toString();
        if (peerId.isEmpty ||
            !LocalSyncTls.isValidFingerprint(secondaryFingerprint) ||
            (body['listenPort'] as num? ?? 0) <= 0) {
          return _json(req.response, 400, {'error': 'A secure secondary listener is required.'});
        }
        final peerToken = _randomToken(36);
        final remote = req.connectionInfo?.remoteAddress.address ?? '';
        final peerPort = (body['listenPort'] as num?)?.toInt() ?? 0;
        final db = await _db;
        final activePeers = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM sync_devices WHERE revoked=0',
        )) ?? 0;
        if (activePeers == 0) await _resetSyncStatsBaseline();
        final existingPeer = await db.query(
          'sync_devices',
          columns: ['token'],
          where: 'device_id=?',
          whereArgs: [peerId],
          limit: 1,
        );
        final previousToken = existingPeer.isEmpty
            ? ''
            : existingPeer.first['token']?.toString() ?? '';
        await db.insert('sync_devices', {
          'device_id': peerId,
          'name': body['name']?.toString() ?? 'Connected device',
          'host': remote,
          'port': peerPort,
          // The primary always creates the relationship token and sends it to
          // the secondary. Re-pairing an already-known device rotates it.
          'token': peerToken,
          'tls_fingerprint': secondaryFingerprint,
          'previous_token': previousToken,
          'token_issued_at': DateTime.now().toUtc().toIso8601String(),
          'is_primary': 0,
          'revoked': 0,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert(
          'sync_bootstrap',
          {
            'device_id': peerId,
            'needs_bootstrap': 1,
            'cutoff_journal_id': 0,
            'snapshot_id': null,
            'snapshot_created_at': null,
            'completed_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        _pairToken = null;
        _pairCode = null;
        await refresh();
        return _json(req.response, 200, {
          'deviceId': state.deviceId,
          'name': state.deviceName,
          'deviceToken': peerToken,
        });
      }
      if (req.method == 'POST' && req.uri.path == '/bootstrap') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final peerId = body['deviceId']?.toString() ?? '';
        final token = body['token']?.toString() ?? '';
        final db = await _db;
        if (state.role != SyncRole.primary) {
          return _json(req.response, 409, {
            'error': 'Only the primary device can provide a first-sync snapshot.',
          });
        }
        final peer = await _authenticatedPeer(db, peerId, token);
        if (peer == null) {
          return _json(req.response, 403, {
            'error': 'Device revoked or pairing token is invalid',
            'revoked': true,
          });
        }
        if (!await _peerNeedsBootstrap(db, peerId)) {
          return _json(req.response, 409, {
            'error': 'This device is already initialized.',
            'bootstrapRequired': false,
          });
        }

        final cutoff = Sqflite.firstIntValue(
              await db.rawQuery('SELECT MAX(id) FROM sync_journal'),
            ) ??
            0;
        final snapshotId = _randomToken(18);
        state = state.copyWith(
          firstSyncing: true,
          activity: 'Preparing compressed first-sync snapshot for ${peer['name'] ?? 'device'}…',
          clearError: true,
        );
        try {
          final package = await _createSyncSnapshot(db);
          await db.update(
            'sync_bootstrap',
            {
              'cutoff_journal_id': cutoff,
              'snapshot_id': snapshotId,
              'snapshot_created_at': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'device_id=?',
            whereArgs: [peerId],
          );
          state = state.copyWith(
            activity:
                'Sending compressed first-sync snapshot… ${(package.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
          );
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.contentType = ContentType('application', 'zip');
          req.response.contentLength = package.bytes.length;
          req.response.headers.set('x-dayark-snapshot-name', package.fileName);
          req.response.headers.set('x-dayark-bootstrap-cutoff', '$cutoff');
          req.response.headers.set('x-dayark-bootstrap-id', snapshotId);
          req.response.add(package.bytes);
          await req.response.close();
          return;
        } finally {
          state = state.copyWith(firstSyncing: false, clearActivity: true);
        }
      }
      if (req.method == 'POST' && req.uri.path == '/bootstrap/ack') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final peerId = body['deviceId']?.toString() ?? '';
        final token = body['token']?.toString() ?? '';
        final snapshotId = body['snapshotId']?.toString() ?? '';
        final db = await _db;
        if (state.role != SyncRole.primary) {
          return _json(req.response, 409, {
            'error': 'Bootstrap acknowledgement must be sent to the primary.',
          });
        }
        final peer = await _authenticatedPeer(db, peerId, token);
        if (peer == null) {
          return _json(req.response, 403, {
            'error': 'Device revoked or pairing token is invalid',
            'revoked': true,
          });
        }
        final bootstrapRows = await db.query(
          'sync_bootstrap',
          columns: const [
            'cutoff_journal_id',
            'snapshot_id',
            'snapshot_created_at',
            'needs_bootstrap',
          ],
          where: 'device_id=?',
          whereArgs: [peerId],
          limit: 1,
        );
        if (bootstrapRows.isEmpty) {
          return _json(req.response, 409, {
            'error': 'No first-sync snapshot is pending for this device.',
          });
        }
        final expectedSnapshotId =
            bootstrapRows.first['snapshot_id']?.toString() ?? '';
        if (snapshotId.isEmpty || snapshotId != expectedSnapshotId) {
          return _json(req.response, 409, {
            'error': 'First-sync acknowledgement does not match the current snapshot.',
          });
        }
        if ((bootstrapRows.first['needs_bootstrap'] as num? ?? 0) == 0) {
          return _json(req.response, 200, {'ok': true});
        }
        final cutoff =
            (bootstrapRows.first['cutoff_journal_id'] as num? ?? 0).toInt();
        if (cutoff > 0) {
          final ackAt = DateTime.now().toUtc().toIso8601String();
          await db.rawInsert(
            'INSERT OR IGNORE INTO sync_ack(op_id, device_id, ack_at) '
            'SELECT op_id, ?, ? FROM sync_journal WHERE id <= ?',
            [peerId, ackAt, cutoff],
          );
        }
        await db.insert(
          'sync_bootstrap',
          {
            'device_id': peerId,
            'needs_bootstrap': 0,
            'cutoff_journal_id': cutoff,
            'snapshot_id': expectedSnapshotId,
            'snapshot_created_at':
                bootstrapRows.first['snapshot_created_at']?.toString(),
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.update(
          'sync_devices',
          {'last_seen': DateTime.now().toUtc().toIso8601String()},
          where: 'device_id=?',
          whereArgs: [peerId],
        );
        await refresh();
        return _json(req.response, 200, {'ok': true});
      }
      if (req.method == 'POST' && req.uri.path == '/logout') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final peerId = body['deviceId']?.toString() ?? '';
        final token = body['token']?.toString() ?? '';
        final db = await _db;
        if (state.role != SyncRole.secondary) {
          return _json(req.response, 409, {
            'error': 'Only a linked secondary can receive a primary logout.',
          });
        }
        final peer = await _authenticatedPeer(db, peerId, token);
        if (peer == null || (peer['is_primary'] as num? ?? 0) != 1) {
          return _json(req.response, 403, {
            'error': 'Primary device authentication failed.',
            'revoked': true,
          });
        }

        _json(req.response, 200, {'ok': true, 'loggedOut': true});
        unawaited(_logoutAfterRevocation());
        return;
      }
      if (req.method == 'POST' && req.uri.path == '/sync/ack') {
        // When a peer PULLS a batch in a /sync response, the originating
        // device has not yet seen a receipt. Explicit ACKs unblock the next
        // batch even if only one device's periodic timer is running.
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final peerId = body['deviceId']?.toString() ?? '';
        final token = body['token']?.toString() ?? '';
        final db = await _db;
        final peer = await _authenticatedPeer(db, peerId, token);
        if (peer == null) {
          return _json(req.response, 403, {
            'error': 'Device revoked or pairing token is invalid',
            'revoked': true,
          });
        }
        if (state.role == SyncRole.primary &&
            await _peerNeedsBootstrap(db, peerId)) {
          return _json(req.response, 409, {
            'error': 'A fresh snapshot is required.',
            'bootstrapRequired': true,
          });
        }
        final ids = (body['acked'] as List? ?? const [])
            .map((value) => value?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .take(500)
            .toList(growable: false);
        if (ids.isNotEmpty) {
          // A peer can only acknowledge an operation this device actually
          // knows. Unknown op IDs must not create false delivery receipts.
          final placeholders = List.filled(ids.length, '?').join(',');
          final known = await db.rawQuery(
            'SELECT op_id FROM sync_journal WHERE op_id IN ($placeholders)',
            ids,
          );
          final stamp = DateTime.now().toUtc().toIso8601String();
          await db.transaction((txn) async {
            for (final row in known) {
              await txn.insert('sync_ack', {
                'op_id': row['op_id'],
                'device_id': peerId,
                'ack_at': stamp,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          });
        }
        await db.update(
          'sync_devices',
          {'last_seen': DateTime.now().toUtc().toIso8601String()},
          where: 'device_id=?',
          whereArgs: [peerId],
        );
        await refresh();
        return _json(req.response, 200, {'ok': true});
      }
      if (req.method == 'POST' && req.uri.path == '/sync') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final peerId = body['deviceId'].toString();
        final token = body['token'].toString();
        final db = await _db;
        final deviceRows = await db.query(
          'sync_devices',
          where: 'device_id=?',
          whereArgs: [peerId],
          limit: 1,
        );
        if (deviceRows.isEmpty ||
            (deviceRows.first['revoked'] as num? ?? 0) == 1) {
          return _json(req.response, 403, {
            'error': 'Device revoked or not paired',
            'revoked': true,
          });
        }
        final row = deviceRows.first;
        final currentToken = row['token']?.toString() ?? '';
        final previousToken = row['previous_token']?.toString() ?? '';
        if (token != currentToken && token != previousToken) {
          return _json(req.response, 403, {
            'error': 'Pairing token is no longer valid',
            'revoked': true,
          });
        }
        // Once the peer proves it received the rotated token, retire the grace
        // token. This makes re-pair token changes robust to one lost response.
        if (token == currentToken && previousToken.isNotEmpty) {
          await db.update(
            'sync_devices',
            {'previous_token': ''},
            where: 'device_id=?',
            whereArgs: [peerId],
          );
        }
        if (state.role == SyncRole.primary &&
            await _peerNeedsBootstrap(db, peerId)) {
          return _json(req.response, 409, {
            'error': 'A fresh compressed snapshot is required before incremental sync.',
            'bootstrapRequired': true,
          });
        }
        final incoming = (body['operations'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final applied = await _applyOperations(incoming);
        final acceptedIds = await _ackReceivedOperations(db, incoming, peerId);
        final announcedPort = (body['listenPort'] as num?)?.toInt() ?? 0;
        final peerUpdate = <String, dynamic>{
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        };
        final remoteAddress = req.connectionInfo?.remoteAddress.address ?? '';
        if (remoteAddress.isNotEmpty) peerUpdate['host'] = remoteAddress;
        if (announcedPort > 0) peerUpdate['port'] = announcedPort;
        await db.update(
          'sync_devices',
          peerUpdate,
          where: 'device_id=?',
          whereArgs: [peerId],
        );
        // Only journaled (accepted) rows are acknowledged. Rejecting an
        // unsupported table must leave the sender's queue intact until both
        // installations understand the new schema.
        final outgoing = await _operationsFor(peerId);
        await refresh();
        return _json(req.response, 200, {
          'operations': outgoing,
          'acked': acceptedIds,
          'applied': applied,
          'hasMore': outgoing.length >= 500,
        });
      }
      _json(req.response, 404, {'error': 'Not found'});
    } catch (e) {
      _json(req.response, 500, {'error': '$e'});
    }
  }

  Future<void> syncNow() async {
    // Never overlap two reconciliation passes. Every network wait below is
    // bounded, so an unavailable peer exits naturally and the next timer tick
    // retries the durable queue.
    if (_logoutInProgress ||
        state.syncing ||
        state.firstSyncing ||
        state.backupBusy) {
      return;
    }
    _syncStartedAt = DateTime.now();
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final db = await _db;
      final peers = await db.query('sync_devices', where: 'revoked=0');
      for (final peer in peers) {
        final host = peer['host'].toString();
        final port = (peer['port'] as num?)?.toInt() ?? 0;
        if (host.isEmpty || port == 0) continue;
        final peerId = peer['device_id'].toString();

        // A primary never sends incremental operations to a secondary until
        // that secondary confirms the compressed baseline snapshot.
        if (state.role == SyncRole.primary &&
            await _peerNeedsBootstrap(db, peerId)) {
          continue;
        }

        // If the data import completed but the acknowledgement response was
        // lost, confirm it first instead of downloading the snapshot again.
        if (state.role == SyncRole.secondary &&
            (peer['is_primary'] as num? ?? 0) == 1) {
          final pendingAck = await db.query(
            'sync_runtime',
            columns: const ['value'],
            where: 'key=?',
            whereArgs: ['bootstrap_pending_ack:$peerId'],
            limit: 1,
          );
          if (pendingAck.isNotEmpty) {
            final acknowledged = await _ackBootstrap(peer, silent: true);
            if (!acknowledged) continue;
          }
        }

        try {
          // Incremental sync is intentionally small. The initial historical
          // database transfer is handled by the compressed bootstrap endpoint.
          for (var round = 0; round < 100; round++) {
            final ops = await _operationsFor(peerId);
            final client = LocalSyncTls.pinnedClient(
              peer['tls_fingerprint']?.toString(), timeout: const Duration(seconds: 4));
            final request = await client.postUrl(LocalSyncTls.endpoint(host, port, '/sync'));
            request.headers.contentType = ContentType.json;
            request.write(
              jsonEncode({
                'deviceId': state.deviceId,
                'token': peer['token'],
                'listenPort': _server?.port ?? 0,
                'operations': ops,
              }),
            );
            final response = await request.close().timeout(_networkTimeout);
            final responseText = await utf8.decoder
                .bind(response)
                .join()
                .timeout(_networkTimeout);
            final body = jsonDecode(responseText) as Map<String, dynamic>;
            client.close(force: true);
            if (_logoutInProgress || state.role == SyncRole.standalone) return;
            if (response.statusCode == 403 && body['revoked'] == true) {
              await _logoutAfterRevocation();
              return;
            }
            if (response.statusCode == 409 &&
                body['bootstrapRequired'] == true &&
                state.role == SyncRole.secondary) {
              final imported = await _bootstrapFromPrimary(peer);
              if (imported) continue;
              break;
            }
            if (response.statusCode != 200) break;
            for (final id in (body['acked'] as List? ?? const [])) {
              await db.insert('sync_ack', {
                'op_id': id,
                'device_id': peerId,
                'ack_at': DateTime.now().toUtc().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            final incoming = (body['operations'] as List? ?? const [])
                .cast<Map<String, dynamic>>();
            await _applyOperations(incoming);
            final acceptedIncoming =
                await _ackReceivedOperations(db, incoming, peerId);
            final acknowledgedRemote = await _confirmPulledOperations(
              peer,
              acceptedIncoming,
            );
            await db.update(
              'sync_devices',
              {'last_seen': DateTime.now().toUtc().toIso8601String()},
              where: 'device_id=?',
              whereArgs: [peerId],
            );

            final remoteHasMore = body['hasMore'] == true;
            final ackedOutgoing = (body['acked'] as List? ?? const []).length;
            // Never spin through 100 retries of the same 500 rows when a
            // receiver is on an older schema or an acknowledgement failed.
            // The durable queue will be retried on the next light LAN tick.
            if (incoming.isNotEmpty &&
                (!acknowledgedRemote || acceptedIncoming.isEmpty)) {
              break;
            }
            if (ops.isNotEmpty && ackedOutgoing == 0) break;
            // Both incremental directions are exhausted for this pass.
            if (ops.length < 500 && !remoteHasMore && incoming.length < 500) {
              break;
            }
          }
        } on TimeoutException {
          // Offline/stalled peer: the journal remains durable. The next timer
          // tick or lifecycle resume will retry without losing its position.
        } on SocketException {
          // Peer is currently unreachable on the LAN; retry later.
        } catch (e) {
          state = state.copyWith(
            error: "Sync with ${peer['name'] ?? 'device'} paused: $e",
          );
        }
      }
      state = state.copyWith(lastSync: DateTime.now());
    } finally {
      _syncStartedAt = null;
      state = state.copyWith(syncing: false);
      await refresh();
    }
  }

  // A normal /sync response contains remote operations, but the remote does
  // not know we imported them until we ACK. Sending this immediately allows
  // pull-only syncing and correctly paginates queues larger than 500 rows.
  Future<bool> _confirmPulledOperations(
    Map<String, Object?> peer,
    List<String> ackedIds,
  ) async {
    if (ackedIds.isEmpty) return true;
    final host = peer['host']?.toString() ?? '';
    final port = (peer['port'] as num?)?.toInt() ?? 0;
    if (host.isEmpty || port == 0) return false;
    HttpClient? client;
    try {
      client = LocalSyncTls.pinnedClient(
        peer['tls_fingerprint']?.toString(), timeout: const Duration(seconds: 4));
      final request = await client.postUrl(LocalSyncTls.endpoint(host, port, '/sync/ack'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'deviceId': state.deviceId,
        'token': peer['token'],
        'acked': ackedIds,
      }));
      final response = await request.close().timeout(_networkTimeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_networkTimeout);
      if (response.statusCode == 403) {
        try {
          final body = jsonDecode(responseText) as Map<String, dynamic>;
          if (body['revoked'] == true) await _logoutAfterRevocation();
        } catch (_) {}
      }
      return response.statusCode == 200;
    } catch (_) {
      // The sender will offer the same batch again at the next LAN tick;
      // deduplication in _applyOperations makes that retry safe.
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  // Persist acknowledgements only for operations successfully recorded in
  // this database. The other side may be running an older app; ACKing a table
  // it doesn't know would otherwise permanently lose that change.
  Future<List<String>> _ackReceivedOperations(
    Database db,
    List<Map<String, dynamic>> operations,
    String peerId,
  ) async {
    final requested = operations
        .map((op) => op['op_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (requested.isEmpty) return const [];
    final placeholders = List.filled(requested.length, '?').join(',');
    final known = await db.rawQuery(
      'SELECT op_id FROM sync_journal WHERE op_id IN ($placeholders)',
      requested,
    );
    final ackIds = known.map((r) => r['op_id'].toString()).toList();
    if (ackIds.isEmpty) return ackIds;
    final ackAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final id in ackIds) {
        await txn.insert('sync_ack', {
          'op_id': id,
          'device_id': peerId,
          'ack_at': ackAt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return ackIds;
  }

  Future<List<Map<String, dynamic>>> _operationsFor(String peerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT j.* FROM sync_journal j '
      'LEFT JOIN sync_ack a ON a.op_id=j.op_id AND a.device_id=? '
      'LEFT JOIN sync_bootstrap b ON b.device_id=? '
      "WHERE a.op_id IS NULL AND j.table_name<>'backup_restore_history' "
      'AND j.origin_device<>? '
      'AND j.id > CASE WHEN b.needs_bootstrap=0 '
      'THEN COALESCE(b.cutoff_journal_id,0) ELSE 0 END '
      'ORDER BY j.id LIMIT 500',
      [peerId, peerId, peerId],
    );

    final result = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final op = Map<String, dynamic>.from(raw);
      final table = op['table_name']?.toString() ?? '';
      final rowId = op['row_id']?.toString() ?? '';
      final origin = op['origin_device']?.toString() ?? state.deviceId;
      if (table.isEmpty || rowId.isEmpty) continue;

      Map<String, dynamic>? payload;
      final rawPayload = op['payload']?.toString();
      if (rawPayload != null && rawPayload.isNotEmpty) {
        try {
          payload = _decodePayload(rawPayload);
        } catch (_) {
          payload = null;
        }
      }

      var entityId = op['entity_id']?.toString() ?? '';
      if (entityId.isEmpty) {
        entityId = await _ensureEntityForLocalRow(
          db,
          table: table,
          localRowId: rowId,
          payload: payload,
          originDevice: origin,
        );
        await db.update(
          'sync_journal',
          {'entity_id': entityId},
          where: 'op_id=?',
          whereArgs: [op['op_id']],
        );
      }
      op['entity_id'] = entityId;

      Map<String, String> foreignEntities = const {};
      final storedForeign = op['foreign_entities'];
      if (storedForeign is String && storedForeign.isNotEmpty) {
        try {
          final decoded = jsonDecode(storedForeign);
          if (decoded is Map) {
            foreignEntities = decoded.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          }
        } catch (_) {
          foreignEntities = const {};
        }
      }

      if (foreignEntities.isEmpty &&
          payload != null &&
          op['operation']?.toString() != 'delete') {
        foreignEntities = await _foreignEntitiesForPayload(
          db,
          table: table,
          payload: payload,
        );
        if (foreignEntities.isNotEmpty) {
          await db.update(
            'sync_journal',
            {'foreign_entities': jsonEncode(foreignEntities)},
            where: 'op_id=?',
            whereArgs: [op['op_id']],
          );
        }
      }
      op['foreign_entities'] = foreignEntities;
      result.add(op);
    }
    return result;
  }

  /// Returns a stable id for a logical row. Local integer primary keys are not
  /// globally stable: two independently-used devices can both have row `2`
  /// while row `2` means different things. The stable entity id prevents those
  /// collisions from overwriting data during first/full sync.
  Future<String> _ensureEntityForLocalRow(
    Database db, {
    required String table,
    required String localRowId,
    Map<String, dynamic>? payload,
    required String originDevice,
    String? preferredEntityId,
  }) async {
    final existing = await db.query(
      'sync_row_identity',
      columns: ['entity_id'],
      where: 'table_name=? AND local_row_id=?',
      whereArgs: [table, localRowId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['entity_id'].toString();

    Map<String, dynamic>? rowPayload = payload;
    if (rowPayload == null) {
      final info = await db.rawQuery(
        'PRAGMA table_info("${table.replaceAll('"', '""')}")',
      );
      final pk = info.where((c) => (c['pk'] as num? ?? 0) > 0).toList();
      if (pk.length == 1) {
        final pkName = pk.first['name'].toString();
        final rows = await db.query(
          table,
          where: '"${pkName.replaceAll('"', '""')}"=?',
          whereArgs: [localRowId],
          limit: 1,
        );
        if (rows.isNotEmpty) rowPayload = Map<String, dynamic>.from(rows.first);
      }
    }

    final preferred = preferredEntityId?.trim() ?? '';
    final entityId = preferred.isNotEmpty
        ? preferred
        : _deriveEntityId(
            table: table,
            payload: rowPayload,
            originDevice: originDevice,
            rowId: localRowId,
          );

    await db.insert('sync_row_identity', {
      'table_name': table,
      'local_row_id': localRowId,
      'entity_id': entityId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final bound = await db.query(
      'sync_row_identity',
      columns: ['entity_id'],
      where: 'table_name=? AND local_row_id=?',
      whereArgs: [table, localRowId],
      limit: 1,
    );
    return bound.isNotEmpty ? bound.first['entity_id'].toString() : entityId;
  }

  static String _deriveEntityId({
    required String table,
    required Map<String, dynamic>? payload,
    required String originDevice,
    required String rowId,
  }) {
    final uuid = payload?['uuid']?.toString().trim() ?? '';
    if (uuid.isNotEmpty) return 'uuid:$table:$uuid';

    // These are seeded dictionary tables. Their numeric ids changed between
    // some app/database versions, but the unique name is the logical identity.
    if (table == 'dosage_types' || table == 'pill_types') {
      final name = payload?['name']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) return 'name:$table:$name';
    }

    return 'row:$originDevice:$table:$rowId';
  }

  Future<Map<String, String>> _foreignEntitiesForPayload(
    Database db, {
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final result = <String, String>{};
    final foreignKeys = await db.rawQuery(
      'PRAGMA foreign_key_list("${table.replaceAll('"', '""')}")',
    );
    for (final fk in foreignKeys) {
      final column = fk['from']?.toString() ?? '';
      final foreignTable = fk['table']?.toString() ?? '';
      if (column.isEmpty || foreignTable.isEmpty) continue;
      final localForeignId = payload[column];
      if (localForeignId == null) continue;
      final foreignEntity = await _ensureEntityForLocalRow(
        db,
        table: foreignTable,
        localRowId: localForeignId.toString(),
        originDevice: state.deviceId,
      );
      result[column] = foreignEntity;
    }
    return result;
  }

  Future<String?> _mappedLocalRowId(
    Database db, {
    required String table,
    required String entityId,
    required String originDevice,
    required String remoteRowId,
  }) async {
    if (entityId.isNotEmpty) {
      final byEntity = await db.query(
        'sync_row_identity',
        columns: ['local_row_id'],
        where: 'table_name=? AND entity_id=?',
        whereArgs: [table, entityId],
        limit: 1,
      );
      if (byEntity.isNotEmpty) return byEntity.first['local_row_id'].toString();
    }

    final byRemoteId = await db.query(
      'sync_remote_row_map',
      columns: ['local_row_id'],
      where: 'origin_device=? AND table_name=? AND remote_row_id=?',
      whereArgs: [originDevice, table, remoteRowId],
      limit: 1,
    );
    return byRemoteId.isEmpty
        ? null
        : byRemoteId.first['local_row_id'].toString();
  }

  /// Finds an existing row that is already the same logical record according
  /// to a UNIQUE index (for example dosage_types.name or expense uuid). This is
  /// the important guard against SQLite error 2067 during historical sync.
  Future<String?> _findUniqueLocalRowId(
    Database db, {
    required String table,
    required String pkName,
    required Map<String, dynamic> payload,
  }) async {
    // Some of the app's lookup/reference tables are seeded independently on
    // every installation. Their integer ids are therefore *not* a portable
    // identity. Resolve them by their natural key before looking at SQLite's
    // generated UNIQUE indexes. This is especially important for pill_types
    // and dosage_types: e.g. "ml" may be id=1 on one phone and id=2 on
    // another. Updating by the remote id would otherwise violate UNIQUE(name).
    final naturalKeyColumns = <String, List<String>>{
      'pill_types': const ['name'],
      'dosage_types': const ['name'],
      'media_collections': const ['name'],
    }[table];
    if (naturalKeyColumns != null &&
        naturalKeyColumns.every((column) => payload[column] != null)) {
      final where = naturalKeyColumns
          .map((column) => '"${column.replaceAll('"', '""')}"=?')
          .join(' AND ');
      final match = await db.query(
        table,
        columns: [pkName],
        where: where,
        whereArgs: naturalKeyColumns
            .map((column) => payload[column])
            .toList(growable: false),
        limit: 1,
      );
      if (match.isNotEmpty && match.first[pkName] != null) {
        return match.first[pkName].toString();
      }
    }

    final indexes = await db.rawQuery(
      'PRAGMA index_list("${table.replaceAll('"', '""')}")',
    );
    for (final index in indexes) {
      if ((index['unique'] as num? ?? 0) != 1) continue;
      if (index['origin']?.toString() == 'pk') continue;
      final indexName = index['name']?.toString() ?? '';
      if (indexName.isEmpty) continue;
      final columns = await db.rawQuery(
        'PRAGMA index_info("${indexName.replaceAll('"', '""')}")',
      );
      final names = columns
          .map((c) => c['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (names.isEmpty || names.any((name) => payload[name] == null)) continue;

      final where = names
          .map((name) => '"${name.replaceAll('"', '""')}"=?')
          .join(' AND ');
      final match = await db.query(
        table,
        columns: [pkName],
        where: where,
        whereArgs: names.map((name) => payload[name]).toList(growable: false),
        limit: 1,
      );
      if (match.isNotEmpty && match.first[pkName] != null) {
        return match.first[pkName].toString();
      }
    }
    return null;
  }

  Future<void> _bindRemoteRow(
    Database db, {
    required String table,
    required String localRowId,
    required String entityId,
    required String originDevice,
    required String remoteRowId,
  }) async {
    // Mappings can become stale after an old-version sync matched rows only by
    // integer id. Move the entity binding to the newly resolved logical row
    // instead of letting INSERT OR IGNORE keep the stale mapping forever.
    await db.delete(
      'sync_row_identity',
      where: 'table_name=? AND entity_id=? AND local_row_id<>?',
      whereArgs: [table, entityId, localRowId],
    );
    await db.insert('sync_row_identity', {
      'table_name': table,
      'local_row_id': localRowId,
      'entity_id': entityId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('sync_remote_row_map', {
      'origin_device': originDevice,
      'table_name': table,
      'remote_row_id': remoteRowId,
      'local_row_id': localRowId,
      'entity_id': entityId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> _translateForeignKeys(
    Database db, {
    required String table,
    required String originDevice,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> operation,
  }) async {
    final translated = Map<String, dynamic>.from(payload);
    Map<String, String> foreignEntities = const {};
    final rawForeignEntities = operation['foreign_entities'];
    if (rawForeignEntities is Map) {
      foreignEntities = rawForeignEntities.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (rawForeignEntities is String && rawForeignEntities.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawForeignEntities);
        if (decoded is Map) {
          foreignEntities = decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
      } catch (_) {
        foreignEntities = const {};
      }
    }

    final foreignKeys = await db.rawQuery(
      'PRAGMA foreign_key_list("${table.replaceAll('"', '""')}")',
    );
    for (final fk in foreignKeys) {
      final column = fk['from']?.toString() ?? '';
      final foreignTable = fk['table']?.toString() ?? '';
      if (column.isEmpty || foreignTable.isEmpty) continue;
      final remoteForeignId = payload[column];
      if (remoteForeignId == null) continue;

      String? localForeignId;
      final foreignEntity = foreignEntities[column];
      if (foreignEntity != null && foreignEntity.isNotEmpty) {
        final byEntity = await db.query(
          'sync_row_identity',
          columns: ['local_row_id'],
          where: 'table_name=? AND entity_id=?',
          whereArgs: [foreignTable, foreignEntity],
          limit: 1,
        );
        if (byEntity.isNotEmpty) {
          localForeignId = byEntity.first['local_row_id'].toString();
        }
      }

      if (localForeignId == null) {
        final byRemote = await db.query(
          'sync_remote_row_map',
          columns: ['local_row_id'],
          where: 'origin_device=? AND table_name=? AND remote_row_id=?',
          whereArgs: [originDevice, foreignTable, remoteForeignId.toString()],
          limit: 1,
        );
        if (byRemote.isNotEmpty) {
          localForeignId = byRemote.first['local_row_id']?.toString();
        }
      }

      if (localForeignId != null) {
        translated[column] = _coerceIdLike(remoteForeignId, localForeignId);
      }
    }
    return translated;
  }

  static Object _coerceIdLike(Object? original, String localRowId) {
    if (original is int) return int.tryParse(localRowId) ?? localRowId;
    if (original is double) return double.tryParse(localRowId) ?? localRowId;
    if (original is num) return num.tryParse(localRowId) ?? localRowId;
    return localRowId;
  }

  static String _canonicalPayload(
    Map<String, dynamic> payload, {
    String? omitKey,
  }) {
    final normalized = <String, dynamic>{};
    final keys = payload.keys.where((key) => key != omitKey).toList()..sort();
    for (final key in keys) {
      final value = payload[key];
      normalized[key] = value is List<int>
          ? {'__dayark_blob__': base64Encode(value)}
          : value;
    }
    return jsonEncode(normalized);
  }

  Future<int> _applyOperations(List<Map<String, dynamic>> operations) async {
    if (operations.isEmpty) return 0;
    final db = await _db;
    var applied = 0;
    await db.transaction((txn) async {
      await txn.insert('sync_runtime', {
        'key': 'applying_remote',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      _applyingRemote = true;
      try {
        for (final op in operations) {
          final opId = op['op_id']?.toString() ?? '';
          if (opId.isEmpty) continue;
          final alreadyApplied = await txn.query(
            'sync_journal',
            columns: ['id'],
            where: 'op_id=?',
            whereArgs: [opId],
            limit: 1,
          );
          if (alreadyApplied.isNotEmpty) continue;

          final table = op['table_name']?.toString() ?? '';
          if (table.isEmpty ||
              table.startsWith('sync_') ||
              _localOnlyTables.contains(table)) {
            continue;
          }
          final tableInfo = await txn.rawQuery(
            'PRAGMA table_info("${table.replaceAll('"', '""')}")',
          );
          if (tableInfo.isEmpty) continue;
          final pk = tableInfo
              .where((c) => (c['pk'] as num? ?? 0) > 0)
              .toList();
          if (pk.length != 1) continue;
          final pkInfo = pk.first;
          final pkName = pkInfo['name'].toString();
          final pkType = pkInfo['type']?.toString().toUpperCase() ?? '';
          final remoteRowId = op['row_id']?.toString() ?? '';
          final originDevice = op['origin_device']?.toString() ?? '';
          if (remoteRowId.isEmpty || originDevice.isEmpty) continue;

          Map<String, dynamic>? decodedPayload;
          final rawPayload = op['payload']?.toString() ?? '';
          if (rawPayload.isNotEmpty) {
            decodedPayload = _decodePayload(rawPayload);
          }
          final incomingEntityId = op['entity_id']?.toString().trim() ?? '';
          final entityId = incomingEntityId.isNotEmpty
              ? incomingEntityId
              : _deriveEntityId(
                  table: table,
                  payload: decodedPayload,
                  originDevice: originDevice,
                  rowId: remoteRowId,
                );

          String? localRowId = await _mappedLocalRowId(
            txn,
            table: table,
            entityId: entityId,
            originDevice: originDevice,
            remoteRowId: remoteRowId,
          );

          Map<String, dynamic>? translatedPayload;
          if (decodedPayload != null) {
            translatedPayload = await _translateForeignKeys(
              txn,
              table: table,
              originDevice: originDevice,
              payload: decodedPayload,
              operation: op,
            );
            final uniqueLocalRowId = await _findUniqueLocalRowId(
              txn,
              table: table,
              pkName: pkName,
              payload: translatedPayload,
            );
            if (uniqueLocalRowId != null) {
              if (localRowId != null && localRowId != uniqueLocalRowId) {
                // A stale numeric-id/entity mapping points at a different row,
                // while the incoming UNIQUE key points at the logical match.
                // Prefer the UNIQUE match and move this entity binding there.
                await txn.delete(
                  'sync_row_identity',
                  where: 'table_name=? AND entity_id=?',
                  whereArgs: [table, entityId],
                );
              }
              localRowId = uniqueLocalRowId;
            }
          }

          Map<String, dynamic>? existingRow;
          if (localRowId != null) {
            final rows = await txn.query(
              table,
              where: '"${pkName.replaceAll('"', '""')}"=?',
              whereArgs: [localRowId],
              limit: 1,
            );
            if (rows.isNotEmpty)
              existingRow = Map<String, dynamic>.from(rows.first);
          }

          // A remote row can have the same integer primary key as an unrelated
          // local row. Never overwrite that unrelated row merely because the
          // ids happen to match. Allocate a fresh local id and remember the map.
          if (localRowId == null && translatedPayload != null) {
            final remotePkValue = translatedPayload[pkName] ?? remoteRowId;
            final samePkRows = await txn.query(
              table,
              where: '"${pkName.replaceAll('"', '""')}"=?',
              whereArgs: [remotePkValue],
              limit: 1,
            );
            if (samePkRows.isEmpty) {
              localRowId = remotePkValue.toString();
            }
          }

          final localPending = localRowId == null
              ? const <Map<String, dynamic>>[]
              : await txn.rawQuery(
                  'SELECT operation,payload FROM sync_journal j '
                  'WHERE j.table_name=? AND j.row_id=? AND j.origin_device=? '
                  'AND EXISTS (SELECT 1 FROM sync_devices d '
                  'LEFT JOIN sync_bootstrap b ON b.device_id=d.device_id '
                  'WHERE d.revoked=0 AND d.device_id<>j.origin_device '
                  'AND COALESCE(b.needs_bootstrap,0)=0 '
                  'AND j.id>COALESCE(b.cutoff_journal_id,0) '
                  'AND NOT EXISTS(SELECT 1 FROM sync_ack a '
                  'WHERE a.op_id=j.op_id AND a.device_id=d.device_id)) '
                  'ORDER BY j.id DESC LIMIT 1',
                  [table, localRowId, state.deviceId],
                );

          var hasPendingConflict = false;
          if (localPending.isNotEmpty) {
            if (localPending.first['operation']?.toString() !=
                op['operation']?.toString()) {
              hasPendingConflict = true;
            } else if (translatedPayload != null &&
                localPending.first['payload']?.toString().isNotEmpty == true) {
              try {
                final localPendingPayload = _decodePayload(
                  localPending.first['payload'].toString(),
                );
                hasPendingConflict =
                    _canonicalPayload(localPendingPayload, omitKey: pkName) !=
                    _canonicalPayload(translatedPayload, omitKey: pkName);
              } catch (_) {
                hasPendingConflict = true;
              }
            }
          }

          var preservePrimaryLocal =
              state.role == SyncRole.primary && hasPendingConflict;

          if (hasPendingConflict) {
            await txn.insert('sync_conflicts', {
              'table_name': table,
              'row_id': localRowId ?? remoteRowId,
              'local_payload': localPending.first['payload'],
              'remote_payload': op['payload'],
              'resolved_payload': preservePrimaryLocal
                  ? localPending.first['payload']
                  : op['payload'],
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
          }

          if (op['operation'] == 'delete') {
            if (!preservePrimaryLocal && localRowId != null) {
              await txn.delete(
                table,
                where: '"${pkName.replaceAll('"', '""')}"=?',
                whereArgs: [localRowId],
              );
            }
          } else if (translatedPayload != null) {
            if (localRowId != null && existingRow == null) {
              final rows = await txn.query(
                table,
                where: '"${pkName.replaceAll('"', '""')}"=?',
                whereArgs: [localRowId],
                limit: 1,
              );
              if (rows.isNotEmpty)
                existingRow = Map<String, dynamic>.from(rows.first);
            }

            // On initial reconciliation, the primary keeps its version only
            // when this is genuinely the same logical entity. A mere numeric-id
            // collision is handled by inserting the remote row under a new id.
            if (op['operation'] == 'bootstrap_upsert' &&
                state.role == SyncRole.primary &&
                existingRow != null) {
              final localComparable = Map<String, dynamic>.from(existingRow);
              final remoteComparable = Map<String, dynamic>.from(
                translatedPayload,
              );
              if (_canonicalPayload(localComparable, omitKey: pkName) !=
                  _canonicalPayload(remoteComparable, omitKey: pkName)) {
                preservePrimaryLocal = true;
                await txn.insert('sync_conflicts', {
                  'table_name': table,
                  'row_id': localRowId ?? remoteRowId,
                  'local_payload': jsonEncode(_encodePayload(localComparable)),
                  'remote_payload': op['payload'],
                  'resolved_payload': jsonEncode(
                    _encodePayload(localComparable),
                  ),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                });
              }
            }

            if (!preservePrimaryLocal) {
              if (existingRow != null && localRowId != null) {
                final changes = Map<String, dynamic>.from(translatedPayload)
                  ..remove(pkName);
                if (changes.isNotEmpty) {
                  try {
                    await txn.update(
                      table,
                      changes,
                      where: '"${pkName.replaceAll('"', '""')}"=?',
                      whereArgs: [localRowId],
                    );
                  } catch (error) {
                    // Be defensive against stale mappings produced by older
                    // sync builds. If an UPDATE hits a UNIQUE constraint, find
                    // the row owning the incoming unique/natural key and merge
                    // into that logical row instead of pausing the whole sync.
                    final message = error.toString().toLowerCase();
                    final isUniqueConstraint =
                        message.contains('unique constraint') ||
                        message.contains('constraint failed') &&
                            message.contains('unique');
                    if (!isUniqueConstraint) rethrow;

                    final collisionRowId = await _findUniqueLocalRowId(
                      txn,
                      table: table,
                      pkName: pkName,
                      payload: translatedPayload,
                    );
                    if (collisionRowId == null ||
                        collisionRowId == localRowId) {
                      rethrow;
                    }

                    await txn.delete(
                      'sync_row_identity',
                      where: 'table_name=? AND entity_id=?',
                      whereArgs: [table, entityId],
                    );
                    localRowId = collisionRowId;
                    final retryChanges = Map<String, dynamic>.from(
                      translatedPayload,
                    )..remove(pkName);
                    if (retryChanges.isNotEmpty) {
                      await txn.update(
                        table,
                        retryChanges,
                        where: '"${pkName.replaceAll('"', '""')}"=?',
                        whereArgs: [localRowId],
                      );
                    }
                  }
                }
              } else {
                final insertPayload = Map<String, dynamic>.from(
                  translatedPayload,
                );
                final desiredPk = insertPayload[pkName] ?? remoteRowId;
                final occupied = await txn.query(
                  table,
                  columns: [pkName],
                  where: '"${pkName.replaceAll('"', '""')}"=?',
                  whereArgs: [desiredPk],
                  limit: 1,
                );

                if (occupied.isNotEmpty) {
                  if (pkType.contains('INT')) {
                    insertPayload.remove(pkName);
                    final insertedId = await txn.insert(table, insertPayload);
                    localRowId = insertedId.toString();
                  } else {
                    final replacementId = '$desiredPk-${_randomToken(6)}';
                    insertPayload[pkName] = replacementId;
                    await txn.insert(table, insertPayload);
                    localRowId = replacementId;
                  }
                } else {
                  insertPayload[pkName] = _coerceIdLike(
                    desiredPk,
                    desiredPk.toString(),
                  );
                  final insertedId = await txn.insert(table, insertPayload);
                  localRowId = pkType.contains('INT')
                      ? (int.tryParse(desiredPk.toString()) ?? insertedId)
                            .toString()
                      : desiredPk.toString();
                }
              }
            }
          }

          if (localRowId != null) {
            await _bindRemoteRow(
              txn,
              table: table,
              localRowId: localRowId,
              entityId: entityId,
              originDevice: originDevice,
              remoteRowId: remoteRowId,
            );
          }

          Map<String, String> storedForeignEntities = const {};
          final rawForeign = op['foreign_entities'];
          if (rawForeign is Map) {
            storedForeignEntities = rawForeign.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          } else if (rawForeign is String && rawForeign.isNotEmpty) {
            try {
              final decoded = jsonDecode(rawForeign);
              if (decoded is Map) {
                storedForeignEntities = decoded.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                );
              }
            } catch (_) {
              storedForeignEntities = const {};
            }
          }

          await txn.insert('sync_journal', {
            'op_id': opId,
            'origin_device': originDevice,
            'table_name': table,
            'row_id': remoteRowId,
            'operation': op['operation'],
            'payload': op['payload'],
            'changed_at': op['changed_at'],
            'applied': 1,
            'entity_id': entityId,
            'foreign_entities': storedForeignEntities.isEmpty
                ? null
                : jsonEncode(storedForeignEntities),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          applied++;
        }
      } finally {
        _applyingRemote = false;
        await txn.insert('sync_runtime', {
          'key': 'applying_remote',
          'value': '0',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return applied;
  }

  Future<void> _writeSecondarySafetyBackup() async {
    final db = await _db;
    final package = await BackupService.createPortableBackup(
      db,
      scope: PortableBackupScope.fullDatabase,
      excludedTables: _localOnlyTables,
      excludedTablePrefixes: const ['sync_'],
    );
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(
      p.join(documents.path, 'DayArk', 'SecondarySafetyBackups'),
    );
    await folder.create(recursive: true);
    final file = File(p.join(
      folder.path,
      'before_primary_snapshot_${_backupStamp(DateTime.now())}.housezip',
    ));
    final localSecret = await LocalBackupSecret.getOrCreate();
    final encrypted = await PortableBackupCrypto.encrypt(package.bytes, localSecret);
    await file.writeAsBytes(encrypted, flush: true);
  }

  Future<Directory> _localBackupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'DayArk', 'PrimaryBackups'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static String _backupStamp(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    final millis = value.millisecond.toString().padLeft(3, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}_$millis';
  }

  Future<LocalSyncBackup> _writeLocalPrimaryBackup({
    String prefix = 'primary',
  }) async {
    final db = await _db;
    final package = await BackupService.createPortableBackup(
      db,
      scope: PortableBackupScope.fullDatabase,
      excludedTables: _localOnlyTables,
      excludedTablePrefixes: const ['sync_'],
    );
    final directory = await _localBackupDirectory();
    final now = DateTime.now();
    final file = File(
      p.join(directory.path, 'dayark_${prefix}_${_backupStamp(now)}.housezip'),
    );
    final localSecret = await LocalBackupSecret.getOrCreate();
    final encrypted = await PortableBackupCrypto.encrypt(package.bytes, localSecret);
    await file.writeAsBytes(encrypted, flush: true);
    final stat = await file.stat();
    return LocalSyncBackup(
      path: file.path,
      fileName: p.basename(file.path),
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<void> refreshLocalBackups() async {
    if (state.role != SyncRole.primary) {
      state = state.copyWith(localBackups: const []);
      return;
    }
    try {
      final directory = await _localBackupDirectory();
      final backups = <LocalSyncBackup>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File ||
            p.extension(entity.path).toLowerCase() != '.housezip') {
          continue;
        }
        final stat = await entity.stat();
        backups.add(
          LocalSyncBackup(
            path: entity.path,
            fileName: p.basename(entity.path),
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(localBackups: backups);
    } catch (e) {
      state = state.copyWith(error: 'Could not load local backups: $e');
    }
  }

  Future<void> createLocalBackup() async {
    if (state.role != SyncRole.primary ||
        state.backupBusy ||
        state.firstSyncing ||
        state.syncing) {
      return;
    }
    state = state.copyWith(
      backupBusy: true,
      activity: 'Creating local primary restore point…',
      clearError: true,
    );
    try {
      await _writeLocalPrimaryBackup();
      await refreshLocalBackups();
    } catch (e) {
      state = state.copyWith(error: 'Local backup failed: $e');
    } finally {
      state = state.copyWith(backupBusy: false, clearActivity: true);
    }
  }

  Future<void> deleteLocalBackup(LocalSyncBackup backup) async {
    if (state.role != SyncRole.primary || state.backupBusy) return;
    try {
      final file = File(backup.path);
      if (await file.exists()) await file.delete();
      await refreshLocalBackups();
    } catch (e) {
      state = state.copyWith(error: 'Could not delete local backup: $e');
    }
  }

  Future<void> _requireFreshBootstrapForSecondaries(Database db) async {
    final peers = await db.query(
      'sync_devices',
      columns: const ['device_id'],
      where: 'revoked=0 AND is_primary=0',
    );
    for (final peer in peers) {
      final id = peer['device_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      await db.insert(
        'sync_bootstrap',
        {
          'device_id': id,
          'needs_bootstrap': 1,
          'cutoff_journal_id': 0,
          'snapshot_id': null,
          'snapshot_created_at': null,
          'completed_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> restoreLocalBackup(LocalSyncBackup backup) async {
    if (state.role != SyncRole.primary ||
        state.backupBusy ||
        state.firstSyncing ||
        state.syncing) {
      return;
    }
    final file = File(backup.path);
    if (!await file.exists()) {
      state = state.copyWith(error: 'The selected local backup no longer exists.');
      await refreshLocalBackups();
      return;
    }

    final resumeNetworking = state.running || _autoRun;
    state = state.copyWith(
      backupBusy: true,
      syncing: true,
      activity: 'Creating a safety backup before restore…',
      clearError: true,
    );
    try {
      // Freeze LAN writes first so the safety restore point represents a
      // stable primary state rather than racing an incoming sync request.
      await stopNetworking(userInitiated: false);
      state = state.copyWith(
        syncing: true,
        activity: 'Creating a safety backup before restore…',
      );
      await _writeLocalPrimaryBackup(prefix: 'before_restore');
      final db = await _db;
      await db.insert(
        'sync_runtime',
        {'key': 'applying_remote', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      try {
        state = state.copyWith(activity: 'Restoring selected primary backup…');
        final header = await file.openRead(0, 8).expand((part) => part).toList();
        final encrypted = PortableBackupCrypto.hasMagic(header);
        final password = encrypted ? await LocalBackupSecret.requireExisting() : null;
        await DatabaseRestoreService.restorePortableZip(
          db, file, password: password, allowLegacy: !encrypted,
        );
      } finally {
        await _finishBootstrapRuntime(db);
      }

      // A restored primary becomes the new source of truth. Do not replay old
      // incremental operations; every active secondary receives a fresh ZIP
      // baseline on its next contact, then incremental sync resumes.
      await db.delete('sync_ack');
      await db.delete('sync_journal');
      await db.delete('sync_conflicts');
      await db.delete('sync_seeded_rows');
      await db.delete('sync_row_identity');
      await db.delete('sync_remote_row_map');
      await _resetSyncStatsBaseline(emptyJournal: true);
      await _requireFreshBootstrapForSecondaries(db);
      await _installJournalTriggers();
      await refreshLocalBackups();
      if (resumeNetworking) {
        await startNetworking(userInitiated: false);
      }
      await refresh();
    } catch (e) {
      state = state.copyWith(error: 'Restore failed: $e');
      if (resumeNetworking) {
        await startNetworking(userInitiated: false);
      }
    } finally {
      state = state.copyWith(
        backupBusy: false,
        syncing: false,
        clearActivity: true,
      );
    }
  }

  Future<void> logoutDevice(String id) async {
    if (state.role != SyncRole.primary) return;
    final db = await _db;
    final rows = await db.query(
      'sync_devices',
      where: 'device_id=? AND revoked=0 AND is_primary=0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final peer = Map<String, Object?>.from(rows.first);
    await db.update(
      'sync_devices',
      {
        'revoked': 1,
        'token': _randomToken(48),
        'previous_token': '',
        'token_issued_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'device_id=?',
      whereArgs: [id],
    );

    // Logged-out devices stay in the local security record but are hidden from
    // the connected-device list. If the peer is online, tell it immediately;
    // otherwise its next startup/periodic sync receives a revoked response.
    await refresh();
    unawaited(_notifySecondaryLogout(peer));
  }

  Future<void> _notifySecondaryLogout(Map<String, Object?> peer) async {
    final host = peer['host']?.toString() ?? '';
    final port = (peer['port'] as num?)?.toInt() ?? 0;
    final token = peer['token']?.toString() ?? '';
    if (host.isEmpty || port == 0 || token.isEmpty) return;

    HttpClient? client;
    try {
      client = LocalSyncTls.pinnedClient(
        peer['tls_fingerprint']?.toString(), timeout: const Duration(seconds: 2));
      final request = await client.postUrl(LocalSyncTls.endpoint(host, port, '/logout'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'deviceId': state.deviceId,
          'token': token,
        }),
      );
      final response = await request.close().timeout(const Duration(seconds: 3));
      await response.drain().timeout(const Duration(seconds: 3));
    } catch (_) {
      // The device may be offline. Its stored token is already revoked on this
      // primary, so the next regular sync/startup will force the same logout.
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _clearSecondaryMirroredData(Database db) async {
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%'",
    );
    final tables = tableRows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty && name != 'android_metadata')
        .toList(growable: false);

    final foreignKeysWereEnabled =
        (Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')) ?? 0) == 1;
    if (foreignKeysWereEnabled) {
      await db.execute('PRAGMA foreign_keys = OFF');
    }

    try {
      await db.insert(
        'sync_runtime',
        {'key': 'applying_remote', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.transaction((txn) async {
        for (final table in tables.reversed) {
          final escaped = table.replaceAll('"', '""');
          await txn.execute('DELETE FROM "$escaped"');
        }
      });
    } finally {
      if (foreignKeysWereEnabled) {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }

  Future<void> _removeSecondaryImportedFiles() async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final imported = Directory(
        p.join(documents.path, 'HomeHelperRestored', 'full_database'),
      );
      if (await imported.exists()) {
        await imported.delete(recursive: true);
      }
    } catch (_) {
      // Database access is removed even if an orphaned imported file cannot be
      // deleted immediately because the OS still has it open.
    }
  }

  Future<void> _logoutAfterRevocation() async {
    if (state.role != SyncRole.secondary || _logoutInProgress) return;
    _logoutInProgress = true;

    try {
      final db = await _db;
      state = state.copyWith(
        activity: 'Primary logged out this device. Clearing synchronized data…',
        syncing: true,
        clearError: true,
      );

      await _clearSecondaryMirroredData(db);
      await _removeSecondaryImportedFiles();

      await db.delete('sync_ack');
      await db.delete('sync_journal');
      await db.delete('sync_conflicts');
      await db.delete('sync_seeded_rows');
      await db.delete('sync_row_identity');
      await db.delete('sync_remote_row_map');
      await db.delete('sync_bootstrap');
      await db.delete('sync_devices');
      await db.delete('sync_runtime');
      await _resetHistoricalSeedMarker(db);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_role', SyncRole.standalone.name);
      await prefs.setBool('sync_auto_run', false);
      _autoRun = false;
      await stopNetworking(userInitiated: false);
      state = state.copyWith(
        role: SyncRole.standalone,
        syncing: false,
        pendingWrites: 0,
        sentWrites: 0,
        receivedWrites: 0,
        conflicts: 0,
        devices: const [],
        localBackups: const [],
        clearPairing: true,
        clearActivity: true,
        error:
            'This device was logged out by the primary. Synchronized local data was cleared. Pair again to reconnect.',
      );
    } catch (e) {
      state = state.copyWith(
        syncing: false,
        clearActivity: true,
        error: 'Could not finish primary logout cleanup: $e',
      );
    } finally {
      _logoutInProgress = false;
    }
  }

  Future<void> disconnect({bool forgetPeers = false}) async {
    await stopNetworking();
    if (forgetPeers) {
      final db = await _db;
      await db.delete('sync_ack');
      await db.delete('sync_journal');
      await db.delete('sync_conflicts');
      await db.delete('sync_devices');
      await db.delete('sync_bootstrap');
      await db.delete('sync_seeded_rows');
      await db.delete('sync_row_identity');
      await db.delete('sync_remote_row_map');
      await db.delete(
        'sync_runtime',
        where: 'key LIKE ?',
        whereArgs: ['bootstrap_pending_ack:%'],
      );
      await _resetHistoricalSeedMarker(db);
      await _resetSyncStatsBaseline(emptyJournal: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_role', SyncRole.standalone.name);
      state = state.copyWith(
        role: SyncRole.standalone,
        localBackups: const [],
      );
    }
    await refresh();
  }

  Future<void> refresh() async {
    final db = await _db;
    final deviceRows = await db.query(
      'sync_devices',
      where: 'revoked=0',
      orderBy: 'is_primary DESC, name',
    );
    final floors = await db.query(
      'sync_runtime',
      columns: const ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: [_statsJournalFloorKey, _statsConflictFloorKey],
    );
    final floorValues = {
      for (final row in floors)
        row['key'].toString(): int.tryParse(row['value']?.toString() ?? '') ?? 0,
    };
    final journalFloor = floorValues[_statsJournalFloorKey] ?? 0;
    final conflictFloor = floorValues[_statsConflictFloorKey] ?? 0;

    // Pending is the real outstanding delta queue, across all connected peers.
    // Historical writes covered by each peer's acknowledged ZIP snapshot are
    // not pending, even if old journal rows remain stored for deduplication.
    final pending = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM sync_journal j '
      "WHERE j.table_name<>'backup_restore_history' AND EXISTS ("
      'SELECT 1 FROM sync_devices d '
      'LEFT JOIN sync_bootstrap b ON b.device_id=d.device_id '
      'WHERE d.revoked=0 AND d.device_id<>j.origin_device '
      'AND COALESCE(b.needs_bootstrap,0)=0 '
      'AND j.id>COALESCE(b.cutoff_journal_id,0) '
      'AND NOT EXISTS (SELECT 1 FROM sync_ack a '
      'WHERE a.op_id=j.op_id AND a.device_id=d.device_id))',
    )) ?? 0;

    // A snapshot ACK never counts as a newly sent change. For a shared group,
    // count each locally authored delta once even if multiple peers received
    // it, rather than displaying all historical ACK records.
    final sent = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(DISTINCT j.op_id) FROM sync_journal j '
      'JOIN sync_ack a ON a.op_id=j.op_id '
      'JOIN sync_devices d ON d.device_id=a.device_id AND d.revoked=0 '
      'LEFT JOIN sync_bootstrap b ON b.device_id=d.device_id '
      'WHERE j.origin_device=? AND j.id>? '
      "AND j.table_name<>'backup_restore_history' "
      'AND COALESCE(b.needs_bootstrap,0)=0 '
      'AND j.id>COALESCE(b.cutoff_journal_id,0)',
      [state.deviceId, journalFloor],
    )) ?? 0;
    final received = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM sync_journal '
      'WHERE applied=1 AND id>?',
      [journalFloor],
    )) ?? 0;
    final conflicts = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM sync_conflicts WHERE id>?',
      [conflictFloor],
    )) ?? 0;
    state = state.copyWith(
      pendingWrites: pending,
      sentWrites: sent,
      receivedWrites: received,
      conflicts: conflicts,
      devices: deviceRows
          .map(
            (r) => SyncDevice(
              id: r['device_id'].toString(),
              name: r['name'].toString(),
              host: r['host'].toString(),
              port: (r['port'] as num?)?.toInt() ?? 0,
              token: r['token'].toString(),
              isPrimary: (r['is_primary'] as num? ?? 0) == 1,
              revoked: (r['revoked'] as num? ?? 0) == 1,
              tlsPinned: LocalSyncTls.isValidFingerprint(
                r['tls_fingerprint']?.toString()),
              lastSeen: DateTime.tryParse(r['last_seen']?.toString() ?? ''),
            ),
          )
          .toList(),
    );
  }

  static Future<String?> _localIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final i in interfaces)
      for (final a in i.addresses) if (!a.isLoopback) return a.address;
    return null;
  }

  static String _randomToken(int bytes) => base64Url
      .encode(List<int>.generate(bytes, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  static void _json(HttpResponse res, int status, Map<String, dynamic> body) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    res.close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _server?.close(force: true);
    super.dispose();
  }
}

final deviceSyncProvider =
    StateNotifierProvider<DeviceSyncService, DeviceSyncState>((ref) {
      return DeviceSyncService(ref.watch(databaseServiceProvider));
    });
