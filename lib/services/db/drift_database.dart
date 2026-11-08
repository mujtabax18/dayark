import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift_flutter/drift_flutter.dart';

/// Compatibility enum mirroring the conflict modes previously used by sqflite.
enum ConflictAlgorithm { rollback, abort, fail, ignore, replace }

typedef DatabaseExecutor = Database;
typedef Transaction = Database;

/// A small Drift-backed SQL facade.
///
/// The application historically used sqflite's raw SQL API throughout its
/// repositories. Keeping this facade means those repositories can move to
/// Drift without a risky feature-by-feature rewrite. All SQL is now executed
/// by Drift, so the same persistence layer can run on Android, iOS, macOS,
/// Windows, Linux and web.
class Database {
  Database._(this._drift, {this.path});

  final _RawDriftDatabase _drift;
  final String? path;
  bool _closed = false;

  bool get isOpen => !_closed;

  static Future<Database> open({
    required String name,
    required int schemaVersion,
    String? nativePath,
    bool shareAcrossIsolates = true,
  }) async {
    final connection = driftDatabase(
      name: name,
      native: DriftNativeOptions(
        shareAcrossIsolates: shareAcrossIsolates,
        databasePath: nativePath == null ? null : () async => nativePath,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );

    final raw = _RawDriftDatabase(connection, schemaVersion);
    // Force the lazy executor to open before returning. A harmless pragma is
    // enough and keeps all schema management in the existing migration code.
    await raw.customSelect('PRAGMA user_version').get();
    return Database._(raw, path: nativePath);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _drift.close();
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    await _drift.customStatement(sql, arguments ?? const <Object?>[]);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    _ensureOpen();
    final rows = await _drift
        .customSelect(
          sql,
          variables: _variables(arguments),
        )
        .get();
    return rows
        .map((row) => Map<String, dynamic>.from(row.data))
        .toList(growable: false);
  }

  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _drift.customInsert(sql, variables: _variables(arguments));
  }

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _drift.customUpdate(sql, variables: _variables(arguments));
  }

  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _drift.customUpdate(
      sql,
      variables: _variables(arguments),
      updateKind: drift.UpdateKind.delete,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final buffer = StringBuffer('SELECT ');
    if (distinct == true) buffer.write('DISTINCT ');
    buffer.write(
      columns == null || columns.isEmpty
          ? '*'
          : columns.map(_quoteIdentifier).join(', '),
    );
    buffer.write(' FROM ${_quoteIdentifier(table)}');
    if (where != null && where.trim().isNotEmpty) {
      buffer.write(' WHERE $where');
    }
    if (groupBy != null && groupBy.trim().isNotEmpty) {
      buffer.write(' GROUP BY $groupBy');
    }
    if (having != null && having.trim().isNotEmpty) {
      buffer.write(' HAVING $having');
    }
    if (orderBy != null && orderBy.trim().isNotEmpty) {
      buffer.write(' ORDER BY $orderBy');
    }
    if (limit != null) buffer.write(' LIMIT $limit');
    if (offset != null) {
      if (limit == null) buffer.write(' LIMIT -1');
      buffer.write(' OFFSET $offset');
    }
    return rawQuery(buffer.toString(), whereArgs);
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final conflict = _conflictSql(conflictAlgorithm);
    if (values.isEmpty) {
      return rawInsert(
        'INSERT$conflict INTO ${_quoteIdentifier(table)} DEFAULT VALUES',
      );
    }

    final columns = values.keys.map(_quoteIdentifier).join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    return rawInsert(
      'INSERT$conflict INTO ${_quoteIdentifier(table)} '
      '($columns) VALUES ($placeholders)',
      values.values.toList(growable: false),
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    if (values.isEmpty) return Future.value(0);
    final conflict = _conflictSql(conflictAlgorithm);
    final setClause = values.keys
        .map((column) => '${_quoteIdentifier(column)} = ?')
        .join(', ');
    final sql = StringBuffer(
      'UPDATE$conflict ${_quoteIdentifier(table)} SET $setClause',
    );
    if (where != null && where.trim().isNotEmpty) sql.write(' WHERE $where');
    return rawUpdate(
      sql.toString(),
      <Object?>[...values.values, ...?whereArgs],
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    final sql = StringBuffer('DELETE FROM ${_quoteIdentifier(table)}');
    if (where != null && where.trim().isNotEmpty) sql.write(' WHERE $where');
    return rawDelete(sql.toString(), whereArgs);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    _ensureOpen();
    return _drift.transaction(() => action(this));
  }

  Batch batch() => Batch._(this);

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Database has already been closed.');
    }
  }

  static List<drift.Variable<Object>> _variables(List<Object?>? values) {
    if (values == null || values.isEmpty) return const [];
    return values.map(_variable).toList(growable: false);
  }

  static drift.Variable<Object> _variable(Object? value) {
    if (value == null) return drift.Variable<String>(null);
    if (value is int) return drift.Variable<int>(value);
    if (value is double) return drift.Variable<double>(value);
    if (value is String) return drift.Variable<String>(value);
    if (value is bool) return drift.Variable<bool>(value);
    if (value is Uint8List) return drift.Variable<Uint8List>(value);
    if (value is DateTime) return drift.Variable<DateTime>(value);
    if (value is BigInt) return drift.Variable<BigInt>(value);
    if (value is num) return drift.Variable<double>(value.toDouble());
    return drift.Variable<String>(value.toString());
  }

  static String _quoteIdentifier(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }

  static String _conflictSql(ConflictAlgorithm? algorithm) {
    return switch (algorithm) {
      null => '',
      ConflictAlgorithm.rollback => ' OR ROLLBACK',
      ConflictAlgorithm.abort => ' OR ABORT',
      ConflictAlgorithm.fail => ' OR FAIL',
      ConflictAlgorithm.ignore => ' OR IGNORE',
      ConflictAlgorithm.replace => ' OR REPLACE',
    };
  }
}

class Batch {
  Batch._(this._db);

  final Database _db;
  final List<Future<Object?> Function()> _operations = [];

  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () => _db.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () => _db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _operations.add(() => _db.delete(table, where: where, whereArgs: whereArgs));
  }

  void execute(String sql, [List<Object?>? arguments]) {
    _operations.add(() async {
      await _db.execute(sql, arguments);
      return null;
    });
  }

  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    Future<List<Object?>> run() async {
      final results = <Object?>[];
      for (final operation in _operations) {
        if (continueOnError == true) {
          try {
            results.add(await operation());
          } catch (_) {
            results.add(null);
          }
        } else {
          results.add(await operation());
        }
      }
      return noResult == true ? const <Object?>[] : results;
    }

    if (continueOnError == true) return _db.transaction((_) => run());
    return _db.transaction((_) => run());
  }
}

/// Compatibility helper for the few call sites that only need the first
/// integer from a SELECT COUNT(*) style result.
abstract final class Sqflite {
  static int? firstIntValue(List<Map<String, Object?>> list) {
    if (list.isEmpty || list.first.isEmpty) return null;
    final value = list.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _RawDriftDatabase extends drift.GeneratedDatabase {
  _RawDriftDatabase(
    drift.QueryExecutor executor,
    this._schemaVersion,
  ) : super(executor);

  final int _schemaVersion;

  @override
  int get schemaVersion => _schemaVersion;

  // The existing application already has a mature hand-written migration
  // layer. Drift owns connection/execution here while DbMigrations remains the
  // schema source of truth, so Drift's generated-schema migrator must be a
  // no-op. DbConfig invokes DbMigrations immediately after the connection opens.
  @override
  drift.MigrationStrategy get migration => drift.MigrationStrategy(
        onCreate: (_) async {},
        onUpgrade: (_, __, ___) async {},
      );

  @override
  Iterable<drift.TableInfo<drift.Table, dynamic>> get allTables => const [];

  @override
  Iterable<drift.DatabaseSchemaEntity> get allSchemaEntities => const [];
}
