import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/LoanModel.dart';
import 'khata_formatters.dart';

class KhataWhatsAppService {
  KhataWhatsAppService._();

  static String paymentReminder({
    required LoanModel loan,
    required KhataAccountSnapshot snapshot,
  }) {
    final amount = KhataFormatters.money(
      snapshot.outstanding,
      currencyCode: loan.currencyCode,
    );
    final due = loan.dueDate == null
        ? ''
        : '\nDue date: ${KhataFormatters.date(loan.dueDate)}';
    final installment = loan.installmentAmount > 0
        ? '\nExpected installment: ${KhataFormatters.money(loan.installmentAmount, currencyCode: loan.currencyCode)}'
        : '';
    final reference = loan.referenceNumber.trim().isEmpty
        ? ''
        : '\nReference: ${loan.referenceNumber.trim()}';

    if (loan.isGiven) {
      return 'Assalam-o-Alaikum ${loan.entityName},\n\n'
          'This is a friendly payment reminder for your khata account.\n'
          'Outstanding balance: $amount$due$installment$reference\n\n'
          'Please share the payment details after payment. Thank you.';
    }

    return 'Assalam-o-Alaikum ${loan.entityName},\n\n'
        'This is an update regarding our khata account.\n'
        'My outstanding payable balance is $amount.$due$installment$reference\n\n'
        'I will share the payment details after payment. Thank you.';
  }

  static String accountStatement({
    required LoanModel loan,
    required KhataAccountSnapshot snapshot,
    required List<LoanTransaction> recentTransactions,
  }) {
    final buffer = StringBuffer()
      ..writeln('KHATA ACCOUNT STATEMENT')
      ..writeln('Name: ${loan.entityName}')
      ..writeln('Account: ${loan.isGiven ? 'To Receive' : 'To Pay'}')
      ..writeln(
        'Opening balance: ${KhataFormatters.money(snapshot.openingAmount, currencyCode: loan.currencyCode)}',
      );

    if (snapshot.addedCharges > 0) {
      buffer.writeln(
        'Additional charges: ${KhataFormatters.money(snapshot.addedCharges, currencyCode: loan.currencyCode)}',
      );
    }
    buffer
      ..writeln(
        'Payments: ${KhataFormatters.money(snapshot.payments, currencyCode: loan.currencyCode)}',
      )
      ..writeln(
        'Discounts: ${KhataFormatters.money(snapshot.discounts, currencyCode: loan.currencyCode)}',
      )
      ..writeln(
        'Outstanding: ${KhataFormatters.money(snapshot.outstanding, currencyCode: loan.currencyCode)}',
      );

    if (loan.dueDate != null) {
      buffer.writeln('Due date: ${KhataFormatters.date(loan.dueDate)}');
    }
    if (loan.referenceNumber.trim().isNotEmpty) {
      buffer.writeln('Reference: ${loan.referenceNumber.trim()}');
    }

    if (recentTransactions.isNotEmpty) {
      buffer.writeln('\nRecent entries:');
      for (final entry in recentTransactions.take(5)) {
        final sign = entry.increasesBalance ? '+' : '-';
        buffer.writeln(
          '${KhataFormatters.date(entry.date)} | '
          '${KhataFormatters.titleCase(entry.transactionType)} | '
          '$sign${KhataFormatters.money(entry.amount, currencyCode: loan.currencyCode)}',
        );
      }
    }

    buffer.writeln('\nGenerated from Digital Khata.');
    return buffer.toString().trim();
  }

  static String paymentThankYou({
    required LoanModel loan,
    required KhataAccountSnapshot snapshot,
    required LoanTransaction payment,
  }) {
    return 'Assalam-o-Alaikum ${loan.entityName},\n\n'
        'Payment of ${KhataFormatters.money(payment.amount, currencyCode: loan.currencyCode)} '
        'has been recorded on ${KhataFormatters.date(payment.date)}.\n'
        'Remaining khata balance: ${KhataFormatters.money(snapshot.outstanding, currencyCode: loan.currencyCode)}.\n\n'
        'Thank you.';
  }

  static Future<bool> send({
    required String phone,
    required String message,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isNotEmpty) {
      final uri = Uri.https(
        'wa.me',
        '/$normalizedPhone',
        <String, String>{'text': message},
      );
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {
        // Use the system share sheet below when WhatsApp cannot be opened.
      }
    }

    await SharePlus.instance.share(
      ShareParams(text: message, subject: 'Khata account update'),
    );
    return false;
  }

  static Future<void> share(String message) async {
    await SharePlus.instance.share(
      ShareParams(text: message, subject: 'Khata account statement'),
    );
  }

  static String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('03') && digits.length == 11) {
      digits = '92${digits.substring(1)}';
    }
    return digits;
  }
}
