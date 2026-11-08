import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db/drift_database.dart';

class SqliteSqlExporter {
  /// Exports the currently-open database into a .sql file.
  /// Returns the file path.
  static Future<String> exportToSqlFile({
    required Database db,
    String fileName = 'db_dump.sql',
    bool includeSchema = true,
    bool includeData = true,
    bool includeSystemTables = false,
    List<String> excludeTables = const [
      'android_metadata',
      'sqlite_sequence',
    ],
  }) async {
    final sql = await exportToSqlString(
      db: db,
      includeSchema: includeSchema,
      includeData: includeData,
      includeSystemTables: includeSystemTables,
      excludeTables: excludeTables,
    );

    final dir = await getApplicationDocumentsDirectory();
    final outPath = p.join(dir.path, fileName);
    final file = File(outPath);
    await file.writeAsString(sql, flush: true);
    return outPath;
  }

  static Future<ShareResult> shareSqlFile({
    required BuildContext context,
    required String filePath,
    String? subject,
    String? text,
  }) async {
    final box = context.findRenderObject() as RenderBox?;

    return Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/sql')],
      subject: subject,
      text: text,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  /// Exports DB to .sql and immediately shares it.
  static Future<String> exportAndShare({
    required BuildContext context,
    required Database db,
    String fileName = 'db_dump.sql',
    String? subject,
    String? text,
    List<String> excludeTables = const ['android_metadata', 'sqlite_sequence'],
  }) async {
    final path = await exportToSqlFile(
      db: db,
      fileName: fileName,
      excludeTables: excludeTables,
    );

    await shareSqlFile(
      context: context,
      filePath: path,
      subject: subject ?? 'SQLite DB Dump',
      text: text ?? 'SQL export attached for analysis.',
    );

    return path;
  }

  /// Exports DB as a single SQL script (schema + inserts).
  static Future<String> exportToSqlString({
    required Database db,
    bool includeSchema = true,
    bool includeData = true,
    bool includeSystemTables = false,
    List<String> excludeTables = const [
      'android_metadata',
      'sqlite_sequence',
    ],
  }) async {
    final sb = StringBuffer();

    sb.writeln('-- SQLite SQL Dump');
    sb.writeln('-- Generated: ${DateTime.now().toIso8601String()}');
    sb.writeln('PRAGMA foreign_keys=OFF;');
    sb.writeln('BEGIN TRANSACTION;');
    sb.writeln();

    // 1) Collect tables
    final tableRows = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type='table'
      ORDER BY name;
    ''');

    final tables = <String>[];
    for (final row in tableRows) {
      final name = row['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final isSystem = name.startsWith('sqlite_');
      if (!includeSystemTables && isSystem) continue;
      if (excludeTables.contains(name)) continue;

      tables.add(name);
    }

    // 2) Schema
    if (includeSchema) {
      sb.writeln('-- ----------------------------');
      sb.writeln('-- Schema');
      sb.writeln('-- ----------------------------');
      sb.writeln();

      // Dump all schema objects (tables, indexes, triggers, views) except sqlite_ internal objects
      final schemaRows = await db.rawQuery('''
        SELECT type, name, tbl_name, sql
        FROM sqlite_master
        WHERE sql IS NOT NULL
          AND name NOT LIKE 'sqlite_%'
        ORDER BY
          CASE type
            WHEN 'table' THEN 1
            WHEN 'view' THEN 2
            WHEN 'index' THEN 3
            WHEN 'trigger' THEN 4
            ELSE 5
          END,
          name;
      ''');

      for (final r in schemaRows) {
        final type = r['type']?.toString() ?? '';
        final name = r['name']?.toString() ?? '';
        final tbl = r['tbl_name']?.toString() ?? '';
        final sql = r['sql']?.toString();

        if (sql == null || sql.trim().isEmpty) continue;

        // If user wants to exclude some tables, skip schema objects bound to them
        if (excludeTables.contains(name) || excludeTables.contains(tbl))
          continue;

        sb.writeln('-- $type: $name');
        sb.writeln('$sql;');
        sb.writeln();
      }
    }

    // 3) Data
    if (includeData) {
      sb.writeln('-- ----------------------------');
      sb.writeln('-- Data');
      sb.writeln('-- ----------------------------');
      sb.writeln();

      for (final table in tables) {
        // Skip views (just in case a view slipped into table list)
        final typeRow = await db.rawQuery(
          "SELECT type FROM sqlite_master WHERE name=? LIMIT 1",
          [table],
        );
        final type =
            typeRow.isNotEmpty ? (typeRow.first['type']?.toString() ?? '') : '';
        if (type != 'table') continue;

        // Column order
        final colsInfo = await db.rawQuery('PRAGMA table_info("$table");');
        final cols =
            colsInfo.map((c) => c['name']!.toString()).toList(growable: false);

        // Pull all rows
        final rows = await db.rawQuery('SELECT * FROM "$table";');

        sb.writeln('-- Table: $table (${rows.length} rows)');
        if (rows.isEmpty) {
          sb.writeln();
          continue;
        }

        final colList = cols.map((c) => '"$c"').join(', ');

        for (final row in rows) {
          final values = cols.map((c) => _sqlLiteral(row[c])).join(', ');
          sb.writeln('INSERT INTO "$table" ($colList) VALUES ($values);');
        }

        sb.writeln();
      }
    }

    sb.writeln('COMMIT;');
    sb.writeln('PRAGMA foreign_keys=ON;');
    return sb.toString();
  }

  /// Converts a Dart value returned by SQLite/Drift into a safe SQL literal.
  static String _sqlLiteral(Object? value) {
    if (value == null) return 'NULL';

    if (value is num) {
      // Avoid NaN/Infinity in SQL dumps
      if (value is double && (!value.isFinite)) return 'NULL';
      return value.toString();
    }

    if (value is Uint8List) {
      // SQLite BLOB literal: X'ABCD...'
      final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return "X'$hex'";
    }

    // SQLite drivers may return List<int> for blobs in some setups
    if (value is List<int>) {
      final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return "X'$hex'";
    }

    // Strings / dates stored as text
    final s = value.toString();
    final escaped = s.replaceAll("'", "''");
    return "'$escaped'";
  }
}
