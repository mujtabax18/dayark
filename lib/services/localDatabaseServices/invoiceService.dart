// /lib/services/localDatabaseServices/invoiceService.dart

import '../db/drift_database.dart';

import '../../screens/invoices/data/invoice_model.dart';
import '../database_service.dart';

class InvoiceDatabaseService {
  final DatabaseService _databaseService;

  InvoiceDatabaseService(this._databaseService);

  Future<Database> get _db async => _databaseService.database;

  Future<void> insertInvoice(Invoice invoice) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'invoices',
        _invoiceMap(invoice),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceItems(txn, invoice);
    });
  }

  Future<List<Invoice>> getAllInvoices() async {
    final db = await _db;
    final invoicesRaw = await db.query(
      'invoices',
      orderBy: 'date DESC, number COLLATE NOCASE ASC',
    );

    final invoices = <Invoice>[];
    for (final row in invoicesRaw) {
      final invoiceId = row['id']?.toString() ?? '';
      final itemRows = await db.query(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [invoiceId],
        orderBy: 'rowid ASC',
      );

      invoices.add(_invoiceFromMap(row, itemRows));
    }
    return invoices;
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'invoices',
        _invoiceMap(invoice)..remove('id'),
        where: 'id = ?',
        whereArgs: [invoice.id],
      );
      await _replaceItems(txn, invoice);
    });
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [id],
      );
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _replaceItems(
    DatabaseExecutor executor,
    Invoice invoice,
  ) async {
    await executor.delete(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoice.id],
    );

    for (final item in invoice.items) {
      await executor.insert('invoice_items', {
        'id': item.id,
        'invoiceId': invoice.id,
        'description': item.description,
        'sku': item.sku,
        'unit': item.unit,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'discountPercent': item.discountPercent,
      });
    }
  }

  Map<String, Object?> _invoiceMap(Invoice invoice) {
    return {
      'id': invoice.id,
      'number': invoice.number,
      'date': invoice.date.millisecondsSinceEpoch,
      'dueDate': invoice.dueDate.millisecondsSinceEpoch,
      'businessId': invoice.businessId,
      'customerId': invoice.customerId,
      'businessName': invoice.businessName,
      'businessAddress': invoice.businessAddress,
      'businessEmail': invoice.businessEmail,
      'businessPhone': invoice.businessPhone,
      'businessTaxId': invoice.businessTaxId,
      'customerName': invoice.customerName,
      'customerAddress': invoice.customerAddress,
      'customerEmail': invoice.customerEmail,
      'customerPhone': invoice.customerPhone,
      'purchaseOrderNumber': invoice.purchaseOrderNumber,
      'currencySymbol': invoice.currencySymbol,
      'taxRate': invoice.taxRate,
      'discountType': invoice.discountType,
      'discountValue': invoice.discountValue,
      'shippingAmount': invoice.shippingAmount,
      'paidAmount': invoice.paidAmount,
      'status': invoice.status,
      'paymentInfo': invoice.paymentInfo,
      'terms': invoice.terms,
      'notes': invoice.notes,
      'footerText': invoice.footerText,
      'logoPath': invoice.logoPath,
      'backgroundImagePath': invoice.backgroundImagePath,
      'templateStyle': invoice.templateStyle,
      'accentColorValue': invoice.accentColorValue,
      'backgroundOpacity': invoice.backgroundOpacity,
    };
  }

  Invoice _invoiceFromMap(
    Map<String, Object?> row,
    List<Map<String, Object?>> itemRows,
  ) {
    return Invoice(
      id: _string(row['id']),
      number: _string(row['number']),
      date: _dateFromMilliseconds(row['date']),
      dueDate: _dateFromMilliseconds(row['dueDate']),
      businessId: _nullableString(row['businessId']),
      customerId: _nullableString(row['customerId']),
      businessName: _string(row['businessName']),
      businessAddress: _string(row['businessAddress']),
      businessEmail: _nullableString(row['businessEmail']),
      businessPhone: _nullableString(row['businessPhone']),
      businessTaxId: _nullableString(row['businessTaxId']),
      customerName: _string(row['customerName']),
      customerAddress: _string(row['customerAddress']),
      customerEmail: _nullableString(row['customerEmail']),
      customerPhone: _nullableString(row['customerPhone']),
      purchaseOrderNumber: _nullableString(row['purchaseOrderNumber']),
      currencySymbol: _nonEmptyString(row['currencySymbol'], 'PKR'),
      taxRate: _double(row['taxRate']),
      discountType: _nonEmptyString(row['discountType'], 'percentage'),
      discountValue: _double(row['discountValue']),
      shippingAmount: _double(row['shippingAmount']),
      paidAmount: _double(row['paidAmount']),
      status: _nonEmptyString(row['status'], 'draft'),
      paymentInfo: _string(row['paymentInfo']),
      terms: _nullableString(row['terms']),
      notes: _nullableString(row['notes']),
      footerText: _nullableString(row['footerText']),
      logoPath: _nullableString(row['logoPath']),
      backgroundImagePath: _nullableString(row['backgroundImagePath']),
      templateStyle: _nonEmptyString(row['templateStyle'], 'modern'),
      accentColorValue: _int(row['accentColorValue'], 0xFF2563EB),
      backgroundOpacity: _double(row['backgroundOpacity'], 0.06),
      items: itemRows
          .map(
            (item) => InvoiceItem(
              id: _string(item['id']),
              description: _string(item['description']),
              sku: _nullableString(item['sku']),
              unit: _nonEmptyString(item['unit'], 'item'),
              quantity: _double(item['quantity']),
              unitPrice: _double(item['unitPrice']),
              discountPercent: _double(item['discountPercent']),
            ),
          )
          .toList(growable: false),
    );
  }

  String _string(Object? value) => value?.toString() ?? '';

  String _nonEmptyString(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  double _double(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _int(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime _dateFromMilliseconds(Object? value) {
    final milliseconds = _int(value, DateTime.now().millisecondsSinceEpoch);
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
