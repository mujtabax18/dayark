import 'dart:typed_data';

import '../view/PdfInvoiceService.dart';
import 'invoice_model.dart';

/// Backward-compatible generator used by older parts of the app.
class InvoicePdfGenerator {
  static Future<Uint8List> generate(Invoice invoice) async {
    final document = await PdfInvoiceService.buildPdf(invoice);
    return document.save();
  }
}
