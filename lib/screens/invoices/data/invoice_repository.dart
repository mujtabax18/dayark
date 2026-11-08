import '../../../services/db/drift_database.dart';
import 'invoice_model.dart';

class InvoiceRepository {
  final Database database;

  InvoiceRepository({required this.database});

  // Implement your CRUD operations here
  // Example:
  Future<int> createInvoice(Invoice invoice) async {
    // Implementation for saving to database
    return 0;
  }

  Future<List<Invoice>> getAllInvoices() async {
    // Implementation for fetching from database
    return [];
  }
}