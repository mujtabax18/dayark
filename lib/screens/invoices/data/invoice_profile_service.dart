import '../../../services/db/drift_database.dart';

import '../../../services/database_service.dart';
import 'invoice_profile_model.dart';

class InvoiceProfileService {
  InvoiceProfileService(this._databaseService);

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  Future<List<InvoiceBusinessProfile>> getBusinesses() async {
    final db = await _db;
    final rows = await db.query(
      'invoice_business_profiles',
      orderBy: 'isDefault DESC, updatedAt DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(_businessFromMap).toList(growable: false);
  }

  Future<InvoiceBusinessProfile?> getDefaultBusiness() async {
    final db = await _db;
    final rows = await db.query(
      'invoice_business_profiles',
      orderBy: 'isDefault DESC, updatedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _businessFromMap(rows.first);
  }

  Future<InvoiceBusinessProfile?> findMatchingBusiness({
    required String name,
    required String address,
    String? email,
    String? phone,
  }) async {
    final db = await _db;
    final cleanedName = name.trim().toLowerCase();
    final cleanedAddress = address.trim().toLowerCase();
    final cleanedEmail = email?.trim().toLowerCase() ?? '';
    final cleanedPhone = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';

    final rows = await db.query(
      'invoice_business_profiles',
      where: '''
        (LOWER(TRIM(name)) = ? AND LOWER(TRIM(address)) = ?)
        OR (? <> '' AND LOWER(TRIM(email)) = ?)
        OR (? <> '' AND REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '(', '') LIKE ?)
      ''',
      whereArgs: [
        cleanedName,
        cleanedAddress,
        cleanedEmail,
        cleanedEmail,
        cleanedPhone,
        '%$cleanedPhone%',
      ],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _businessFromMap(rows.first);
  }

  Future<InvoiceBusinessProfile?> getBusiness(String id) async {
    final db = await _db;
    final rows = await db.query(
      'invoice_business_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _businessFromMap(rows.first);
  }

  Future<void> upsertBusiness(InvoiceBusinessProfile business) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'invoice_business_profiles',
        columns: ['isDefault'],
        where: 'id = ?',
        whereArgs: [business.id],
        limit: 1,
      );
      final existingWasDefault =
          existingRows.isNotEmpty && _bool(existingRows.first['isDefault']);
      final countBefore = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM invoice_business_profiles'),
          ) ??
          0;
      final effectiveDefault =
          business.isDefault || existingWasDefault || countBefore == 0;

      if (effectiveDefault) {
        await txn.update('invoice_business_profiles', {'isDefault': 0});
      }

      final map = _businessMap(business);
      map['isDefault'] = effectiveDefault ? 1 : 0;
      await txn.insert(
        'invoice_business_profiles',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> setDefaultBusiness(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('invoice_business_profiles', {'isDefault': 0});
      await txn.update(
        'invoice_business_profiles',
        {'isDefault': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteBusiness(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'invoice_business_profiles',
        columns: ['isDefault'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final wasDefault = rows.isNotEmpty && _bool(rows.first['isDefault']);
      await txn.delete(
        'invoice_business_profiles',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (wasDefault) {
        final remaining = await txn.query(
          'invoice_business_profiles',
          columns: ['id'],
          orderBy: 'updatedAt DESC',
          limit: 1,
        );
        if (remaining.isNotEmpty) {
          await txn.update(
            'invoice_business_profiles',
            {'isDefault': 1},
            where: 'id = ?',
            whereArgs: [remaining.first['id']],
          );
        }
      }
    });
  }

  Future<List<InvoiceCustomerProfile>> getCustomers({String query = ''}) async {
    final db = await _db;
    final cleaned = query.trim();
    final rows = await db.query(
      'invoice_customers',
      where: cleaned.isEmpty
          ? null
          : '(name LIKE ? OR company LIKE ? OR email LIKE ? OR phone LIKE ? OR address LIKE ?)',
      whereArgs: cleaned.isEmpty
          ? null
          : List<Object?>.filled(5, '%$cleaned%'),
      orderBy: 'lastUsedAt DESC, usageCount DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(_customerFromMap).toList(growable: false);
  }

  Future<InvoiceCustomerProfile?> findMatchingCustomer({
    required String name,
    required String address,
    String? email,
    String? phone,
  }) async {
    final db = await _db;
    final cleanedName = name.trim().toLowerCase();
    final cleanedAddress = address.trim().toLowerCase();
    final cleanedEmail = email?.trim().toLowerCase() ?? '';
    final cleanedPhone = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';

    final rows = await db.query(
      'invoice_customers',
      where: '''
        (LOWER(TRIM(name)) = ? AND LOWER(TRIM(address)) = ?)
        OR (? <> '' AND LOWER(TRIM(email)) = ?)
        OR (? <> '' AND REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '(', '') LIKE ?)
      ''',
      whereArgs: [
        cleanedName,
        cleanedAddress,
        cleanedEmail,
        cleanedEmail,
        cleanedPhone,
        '%$cleanedPhone%',
      ],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _customerFromMap(rows.first);
  }

  Future<InvoiceCustomerProfile?> getCustomer(String id) async {
    final db = await _db;
    final rows = await db.query(
      'invoice_customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _customerFromMap(rows.first);
  }

  Future<void> upsertCustomer(
    InvoiceCustomerProfile customer, {
    bool markUsed = false,
  }) async {
    final db = await _db;
    final map = _customerMap(customer);
    if (markUsed) {
      map['usageCount'] = customer.usageCount + 1;
      map['lastUsedAt'] = DateTime.now().toIso8601String();
    }
    await db.insert(
      'invoice_customers',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _db;
    await db.delete('invoice_customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<InvoicePreferences> getPreferences() async {
    final db = await _db;
    final rows = await db.query(
      'invoice_preferences',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      const preferences = InvoicePreferences();
      await savePreferences(preferences);
      return preferences;
    }
    final row = rows.first;
    return InvoicePreferences(
      defaultDueDays: _int(row['defaultDueDays'], 7).clamp(0, 365).toInt(),
      defaultStatus: _text(row['defaultStatus'], 'draft'),
      autoSaveBusinesses: _bool(row['autoSaveBusinesses'], true),
      autoSaveCustomers: _bool(row['autoSaveCustomers'], true),
    );
  }

  Future<void> savePreferences(InvoicePreferences preferences) async {
    final db = await _db;
    final values = <String, Object?>{
      'defaultDueDays': preferences.defaultDueDays.clamp(0, 365),
      'defaultStatus': preferences.defaultStatus,
      'autoSaveBusinesses': preferences.autoSaveBusinesses ? 1 : 0,
      'autoSaveCustomers': preferences.autoSaveCustomers ? 1 : 0,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final updated = await db.update(
      'invoice_preferences',
      values,
      where: 'id = 1',
    );
    if (updated == 0) {
      await db.insert(
        'invoice_preferences',
        {
          'id': 1,
          ...values,
          'legacyProfilesMigrated': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Map<String, Object?> _businessMap(InvoiceBusinessProfile value) => {
        'id': value.id,
        'name': value.name,
        'address': value.address,
        'email': value.email,
        'phone': value.phone,
        'taxId': value.taxId,
        'logoPath': value.logoPath,
        'backgroundImagePath': value.backgroundImagePath,
        'templateStyle': value.templateStyle,
        'accentColorValue': value.accentColorValue,
        'backgroundOpacity': value.backgroundOpacity,
        'currencySymbol': value.currencySymbol,
        'defaultTaxRate': value.defaultTaxRate,
        'paymentInfo': value.paymentInfo,
        'terms': value.terms,
        'customerNote': value.customerNote,
        'footerText': value.footerText,
        'isDefault': value.isDefault ? 1 : 0,
        'createdAt': value.createdAt.toIso8601String(),
        'updatedAt': value.updatedAt.toIso8601String(),
      };

  InvoiceBusinessProfile _businessFromMap(Map<String, Object?> row) {
    final now = DateTime.now();
    return InvoiceBusinessProfile(
      id: _text(row['id']),
      name: _text(row['name']),
      address: _text(row['address']),
      email: _nullable(row['email']),
      phone: _nullable(row['phone']),
      taxId: _nullable(row['taxId']),
      logoPath: _nullable(row['logoPath']),
      backgroundImagePath: _nullable(row['backgroundImagePath']),
      templateStyle: _text(row['templateStyle'], 'modern'),
      accentColorValue: _int(row['accentColorValue'], 0xFF2563EB),
      backgroundOpacity: _double(row['backgroundOpacity'], 0.06),
      currencySymbol: _text(row['currencySymbol'], 'PKR'),
      defaultTaxRate: _double(row['defaultTaxRate']),
      paymentInfo: _text(row['paymentInfo']),
      terms: _nullable(row['terms']),
      customerNote: _nullable(row['customerNote']),
      footerText: _nullable(row['footerText']),
      isDefault: _bool(row['isDefault']),
      createdAt: _date(row['createdAt']) ?? now,
      updatedAt: _date(row['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> _customerMap(InvoiceCustomerProfile value) => {
        'id': value.id,
        'name': value.name,
        'company': value.company,
        'address': value.address,
        'email': value.email,
        'phone': value.phone,
        'taxId': value.taxId,
        'notes': value.notes,
        'usageCount': value.usageCount,
        'createdAt': value.createdAt.toIso8601String(),
        'updatedAt': value.updatedAt.toIso8601String(),
        'lastUsedAt': value.lastUsedAt?.toIso8601String(),
      };

  InvoiceCustomerProfile _customerFromMap(Map<String, Object?> row) {
    final now = DateTime.now();
    return InvoiceCustomerProfile(
      id: _text(row['id']),
      name: _text(row['name']),
      company: _nullable(row['company']),
      address: _text(row['address']),
      email: _nullable(row['email']),
      phone: _nullable(row['phone']),
      taxId: _nullable(row['taxId']),
      notes: _nullable(row['notes']),
      usageCount: _int(row['usageCount']),
      createdAt: _date(row['createdAt']) ?? now,
      updatedAt: _date(row['updatedAt']) ?? now,
      lastUsedAt: _date(row['lastUsedAt']),
    );
  }

  String _text(Object? value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int _int(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _bool(Object? value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
