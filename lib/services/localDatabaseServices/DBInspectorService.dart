import '../db/drift_database.dart';

const String dbInspectorRowIdKey = '__db_inspector_rowid__';

class DBColumnInfo {
  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final Object? defaultValue;
  final int primaryKeyOrder;

  const DBColumnInfo({
    required this.cid,
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKeyOrder,
  });

  bool get isPrimaryKey => primaryKeyOrder > 0;

  bool get isInteger {
    final normalized = type.toUpperCase();
    return normalized.contains('INT');
  }

  bool get isReal {
    final normalized = type.toUpperCase();
    return normalized.contains('REAL') ||
        normalized.contains('FLOA') ||
        normalized.contains('DOUB') ||
        normalized.contains('NUM') ||
        normalized.contains('DEC');
  }

  bool get isBlob => type.toUpperCase().contains('BLOB');

  factory DBColumnInfo.fromPragma(Map<String, Object?> row) {
    return DBColumnInfo(
      cid: (row['cid'] as num?)?.toInt() ?? 0,
      name: row['name']?.toString() ?? '',
      type: row['type']?.toString() ?? 'TEXT',
      notNull: ((row['notnull'] as num?)?.toInt() ?? 0) == 1,
      defaultValue: row['dflt_value'],
      primaryKeyOrder: (row['pk'] as num?)?.toInt() ?? 0,
    );
  }
}

class DBInspectorService {
  final Database db;

  DBInspectorService(this.db);

  Future<List<String>> getAllTables() async {
    final result = await db.rawQuery('''
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name COLLATE NOCASE
''');
    return result.map((e) => e['name'] as String).toList();
  }

  Future<List<DBColumnInfo>> getColumns(String tableName) async {
    final pragma = await db.rawQuery(
      'PRAGMA table_info(${_quoteIdentifier(tableName)})',
    );
    return pragma.map(DBColumnInfo.fromPragma).toList();
  }

  Future<List<Map<String, dynamic>>> getTableData(
    String tableName, {
    String searchText = '',
    String? filterColumn,
    String filterOperator = 'contains',
    String filterValue = '',
    String? sortColumn,
    bool sortAscending = true,
    int limit = 100,
  }) async {
    final columns = await getColumns(tableName);
    final where = _buildWhere(
      columns: columns,
      searchText: searchText,
      filterColumn: filterColumn,
      filterOperator: filterOperator,
      filterValue: filterValue,
    );
    final safeLimit = limit.clamp(10, 1000);
    final orderBy = _buildOrderBy(
      columns: columns,
      sortColumn: sortColumn,
      ascending: sortAscending,
    );

    return db.rawQuery('''
SELECT rowid AS ${_quoteIdentifier(dbInspectorRowIdKey)}, *
FROM ${_quoteIdentifier(tableName)}
${where.sql}
$orderBy
LIMIT $safeLimit
''', where.args);
  }

  Future<int> countTableRows(
    String tableName, {
    String searchText = '',
    String? filterColumn,
    String filterOperator = 'contains',
    String filterValue = '',
  }) async {
    final columns = await getColumns(tableName);
    final where = _buildWhere(
      columns: columns,
      searchText: searchText,
      filterColumn: filterColumn,
      filterOperator: filterOperator,
      filterValue: filterValue,
    );
    final result = await db.rawQuery('''
SELECT COUNT(*)
FROM ${_quoteIdentifier(tableName)}
${where.sql}
''', where.args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String> getPrimaryKey(String tableName) async {
    final columns = await getColumns(tableName);
    final primaryKeys = columns.where((column) => column.isPrimaryKey).toList()
      ..sort((a, b) => a.primaryKeyOrder.compareTo(b.primaryKeyOrder));
    return primaryKeys.isEmpty ? dbInspectorRowIdKey : primaryKeys.first.name;
  }

  Future<void> updateRow({
    required String tableName,
    required String primaryKey,
    required Map<String, dynamic> row,
  }) async {
    final rowId = row[dbInspectorRowIdKey];
    if (rowId != null) {
      final values = Map<String, dynamic>.from(row)
        ..remove(dbInspectorRowIdKey)
        ..removeWhere((key, _) => key == primaryKey);
      await updateRowByRowId(
        tableName: tableName,
        rowId: rowId as int,
        values: values,
      );
      return;
    }

    final id = row[primaryKey];
    final updatedRow = Map<String, dynamic>.from(row)
      ..remove(dbInspectorRowIdKey)
      ..remove(primaryKey);
    final columns = await getColumns(tableName);
    final converted = _convertValues(columns, updatedRow);
    await db.update(
      tableName,
      converted,
      where: '${_quoteIdentifier(primaryKey)} = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateRowByRowId({
    required String tableName,
    required int rowId,
    required Map<String, dynamic> values,
  }) async {
    if (values.isEmpty) return;
    final columns = await getColumns(tableName);
    final converted = _convertValues(columns, values);
    if (converted.isEmpty) return;

    await db.update(
      tableName,
      converted,
      where: 'rowid = ?',
      whereArgs: [rowId],
    );
  }

  Future<int> updateRowsByRowIds({
    required String tableName,
    required Set<int> rowIds,
    required Map<String, dynamic> values,
  }) async {
    if (rowIds.isEmpty || values.isEmpty) return 0;
    final columns = await getColumns(tableName);
    final converted = _convertValues(columns, values);
    if (converted.isEmpty) return 0;

    final placeholders = List.filled(rowIds.length, '?').join(',');
    return db.update(
      tableName,
      converted,
      where: 'rowid IN ($placeholders)',
      whereArgs: rowIds.toList(),
    );
  }

  Future<void> deleteRow({
    required String tableName,
    required String primaryKey,
    required Map<String, dynamic> row,
  }) async {
    final rowId = row[dbInspectorRowIdKey];
    if (rowId != null) {
      await deleteRowByRowId(tableName: tableName, rowId: rowId as int);
      return;
    }

    final id = row[primaryKey];
    await db.delete(
      tableName,
      where: '${_quoteIdentifier(primaryKey)} = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRowByRowId({
    required String tableName,
    required int rowId,
  }) {
    return db.delete(tableName, where: 'rowid = ?', whereArgs: [rowId]);
  }

  Future<int> deleteRowsByRowIds({
    required String tableName,
    required Set<int> rowIds,
  }) {
    if (rowIds.isEmpty) return Future.value(0);
    final placeholders = List.filled(rowIds.length, '?').join(',');
    return db.delete(
      tableName,
      where: 'rowid IN ($placeholders)',
      whereArgs: rowIds.toList(),
    );
  }

  Future<int> insertRow({
    required String tableName,
    required Map<String, dynamic> values,
  }) async {
    final columns = await getColumns(tableName);
    final converted = _convertValues(
      columns,
      values,
      allowPrimaryKeys: true,
    );
    if (converted.isEmpty) {
      return db.rawInsert(
        'INSERT INTO ${_quoteIdentifier(tableName)} DEFAULT VALUES',
      );
    }
    return db.insert(tableName, converted);
  }

  Future<void> dropTable(String tableName) async {
    await db.execute('DROP TABLE IF EXISTS ${_quoteIdentifier(tableName)}');
  }

  _WhereClause _buildWhere({
    required List<DBColumnInfo> columns,
    required String searchText,
    required String? filterColumn,
    required String filterOperator,
    required String filterValue,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    final cleanSearch = searchText.trim();

    if (cleanSearch.isNotEmpty && columns.isNotEmpty) {
      final searchable = columns
          .where((column) => !column.isBlob)
          .map(
            (column) =>
                'CAST(${_quoteIdentifier(column.name)} AS TEXT) LIKE ? COLLATE NOCASE',
          )
          .toList();
      if (searchable.isNotEmpty) {
        conditions.add('(${searchable.join(' OR ')})');
        args.addAll(List.filled(searchable.length, '%$cleanSearch%'));
      }
    }

    final selectedColumn = columns.where((c) => c.name == filterColumn);
    final value = filterValue.trim();
    final needsValue = !const {
      'isNull',
      'isNotNull',
      'isEmpty',
      'isNotEmpty',
    }.contains(filterOperator);
    if (selectedColumn.isNotEmpty && (!needsValue || value.isNotEmpty)) {
      final column = _quoteIdentifier(selectedColumn.first.name);
      switch (filterOperator) {
        case 'equals':
          conditions.add('$column = ?');
          args.add(_coerceValue(selectedColumn.first, value));
          break;
        case 'notEquals':
          conditions.add('$column != ?');
          args.add(_coerceValue(selectedColumn.first, value));
          break;
        case 'startsWith':
          conditions.add('CAST($column AS TEXT) LIKE ? COLLATE NOCASE');
          args.add('$value%');
          break;
        case 'endsWith':
          conditions.add('CAST($column AS TEXT) LIKE ? COLLATE NOCASE');
          args.add('%$value');
          break;
        case 'greaterThan':
          conditions.add('$column > ?');
          args.add(_coerceValue(selectedColumn.first, value));
          break;
        case 'lessThan':
          conditions.add('$column < ?');
          args.add(_coerceValue(selectedColumn.first, value));
          break;
        case 'isNull':
          conditions.add('$column IS NULL');
          break;
        case 'isNotNull':
          conditions.add('$column IS NOT NULL');
          break;
        case 'isEmpty':
          conditions.add("COALESCE(CAST($column AS TEXT), '') = ''");
          break;
        case 'isNotEmpty':
          conditions.add("COALESCE(CAST($column AS TEXT), '') != ''");
          break;
        case 'contains':
        default:
          conditions.add('CAST($column AS TEXT) LIKE ? COLLATE NOCASE');
          args.add('%$value%');
          break;
      }
    }

    return _WhereClause(
      sql: conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      args: args,
    );
  }

  String _buildOrderBy({
    required List<DBColumnInfo> columns,
    required String? sortColumn,
    required bool ascending,
  }) {
    if (sortColumn == null || !columns.any((c) => c.name == sortColumn)) {
      return 'ORDER BY rowid ${ascending ? 'ASC' : 'DESC'}';
    }
    return 'ORDER BY ${_quoteIdentifier(sortColumn)} '
        '${ascending ? 'ASC' : 'DESC'}, rowid ASC';
  }

  Map<String, dynamic> _convertValues(
    List<DBColumnInfo> columns,
    Map<String, dynamic> values, {
    bool allowPrimaryKeys = false,
  }) {
    final byName = {for (final column in columns) column.name: column};
    final converted = <String, dynamic>{};

    for (final entry in values.entries) {
      final column = byName[entry.key];
      if (column == null ||
          (!allowPrimaryKeys && column.isPrimaryKey) ||
          column.isBlob) {
        continue;
      }
      converted[entry.key] = _coerceValue(column, entry.value);
    }
    return converted;
  }

  dynamic _coerceValue(DBColumnInfo column, dynamic value) {
    if (value == null) return null;
    if (value is! String) return value;

    final text = value.trim();
    if (column.isInteger) {
      final parsed = int.tryParse(text);
      if (parsed == null) {
        throw FormatException('${column.name} requires an integer value.');
      }
      return parsed;
    }
    if (column.isReal) {
      final parsed = double.tryParse(text);
      if (parsed == null) {
        throw FormatException('${column.name} requires a numeric value.');
      }
      return parsed;
    }
    return value;
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }
}

class _WhereClause {
  final String sql;
  final List<Object?> args;

  const _WhereClause({required this.sql, required this.args});
}
