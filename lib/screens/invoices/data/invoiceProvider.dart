// /lib/providers/invoice_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/invoiceService.dart';
import 'invoice_model.dart';

/// ------------------------------------------------------------
/// Repository
/// ------------------------------------------------------------
class InvoiceRepository {
  final InvoiceDatabaseService _db;

  InvoiceRepository(this._db);

  Future<void> createInvoice(Invoice invoice) async {
    await _db.insertInvoice(invoice);
  }

  Future<List<Invoice>> getAllInvoices() async {
    return await _db.getAllInvoices();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _db.updateInvoice(invoice);
  }

  Future<void> deleteInvoice(String id) async {
    await _db.deleteInvoice(id);
  }
}

/// ------------------------------------------------------------
/// Repository Provider (single source of truth)
/// ------------------------------------------------------------
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final databaseService = DatabaseService();
  final invoiceDbService = InvoiceDatabaseService(databaseService);

  return InvoiceRepository(invoiceDbService);
});

/// ------------------------------------------------------------
/// Invoices StateNotifier
/// ------------------------------------------------------------
final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<Invoice>>(
  (ref) => InvoicesNotifier(ref.read(invoiceRepositoryProvider)),
);

class InvoicesNotifier extends StateNotifier<List<Invoice>> {
  final InvoiceRepository _repository;

  InvoicesNotifier(this._repository) : super(const []);

  /// Load all invoices
  Future<void> loadInvoices() async {
    final invoices = await _repository.getAllInvoices();
    state = invoices;
  }

  /// Add invoice
  Future<void> addInvoice(Invoice invoice) async {
    await _repository.createInvoice(invoice);
    await loadInvoices();
  }

  /// Update invoice
  Future<void> updateInvoice(Invoice invoice) async {
    await _repository.updateInvoice(invoice);
    await loadInvoices();
  }

  /// Delete invoice
  Future<void> deleteInvoice(String id) async {
    await _repository.deleteInvoice(id);
    await loadInvoices();
  }

  /// Get invoice by ID (used by View/Edit screen)
  Invoice? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
