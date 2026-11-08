import 'package:intl/intl.dart';

class CurrencySetting {
  const CurrencySetting({
    required this.code,
    required this.symbol,
    required this.name,
    this.isCustom = false,
  });

  final String code;
  final String symbol;
  final String name;
  final bool isCustom;

  static const CurrencySetting pkr = CurrencySetting(
    code: 'PKR',
    symbol: 'PKR',
    name: 'Pakistani Rupee',
  );

  static const List<CurrencySetting> presets = [
    pkr,
    CurrencySetting(code: 'USD', symbol: r'$', name: 'US Dollar'),
    CurrencySetting(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencySetting(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencySetting(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencySetting(code: 'AED', symbol: 'AED', name: 'UAE Dirham'),
    CurrencySetting(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal'),
    CurrencySetting(code: 'QAR', symbol: 'QAR', name: 'Qatari Riyal'),
    CurrencySetting(code: 'KWD', symbol: 'KD', name: 'Kuwaiti Dinar'),
    CurrencySetting(code: 'BHD', symbol: 'BD', name: 'Bahraini Dinar'),
    CurrencySetting(code: 'OMR', symbol: 'OMR', name: 'Omani Rial'),
    CurrencySetting(code: 'CAD', symbol: r'C$', name: 'Canadian Dollar'),
    CurrencySetting(code: 'AUD', symbol: r'A$', name: 'Australian Dollar'),
    CurrencySetting(code: 'NZD', symbol: r'NZ$', name: 'New Zealand Dollar'),
    CurrencySetting(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    CurrencySetting(code: 'CNY', symbol: 'CN¥', name: 'Chinese Yuan'),
    CurrencySetting(code: 'HKD', symbol: r'HK$', name: 'Hong Kong Dollar'),
    CurrencySetting(code: 'SGD', symbol: r'S$', name: 'Singapore Dollar'),
    CurrencySetting(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    CurrencySetting(code: 'SEK', symbol: 'kr', name: 'Swedish Krona'),
    CurrencySetting(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone'),
    CurrencySetting(code: 'DKK', symbol: 'kr', name: 'Danish Krone'),
    CurrencySetting(code: 'RUB', symbol: '₽', name: 'Russian Ruble'),
    CurrencySetting(code: 'TRY', symbol: '₺', name: 'Turkish Lira'),
    CurrencySetting(code: 'KRW', symbol: '₩', name: 'South Korean Won'),
    CurrencySetting(code: 'THB', symbol: '฿', name: 'Thai Baht'),
    CurrencySetting(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
    CurrencySetting(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
    CurrencySetting(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka'),
    CurrencySetting(code: 'LKR', symbol: 'LKR', name: 'Sri Lankan Rupee'),
    CurrencySetting(code: 'NPR', symbol: 'NPR', name: 'Nepalese Rupee'),
    CurrencySetting(code: 'AFN', symbol: '؋', name: 'Afghan Afghani'),
    CurrencySetting(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    CurrencySetting(code: 'NGN', symbol: '₦', name: 'Nigerian Naira'),
    CurrencySetting(code: 'GHS', symbol: '₵', name: 'Ghanaian Cedi'),
    CurrencySetting(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling'),
    CurrencySetting(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound'),
    CurrencySetting(code: 'ILS', symbol: '₪', name: 'Israeli New Shekel'),
    CurrencySetting(code: 'BRL', symbol: r'R$', name: 'Brazilian Real'),
    CurrencySetting(code: 'MXN', symbol: r'MX$', name: 'Mexican Peso'),
    CurrencySetting(code: 'ARS', symbol: r'AR$', name: 'Argentine Peso'),
    CurrencySetting(code: 'CLP', symbol: r'CL$', name: 'Chilean Peso'),
    CurrencySetting(code: 'COP', symbol: r'COL$', name: 'Colombian Peso'),
    CurrencySetting(code: 'PLN', symbol: 'zł', name: 'Polish Zloty'),
    CurrencySetting(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna'),
    CurrencySetting(code: 'HUF', symbol: 'Ft', name: 'Hungarian Forint'),
    CurrencySetting(code: 'RON', symbol: 'lei', name: 'Romanian Leu'),
    CurrencySetting(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
    CurrencySetting(code: 'VND', symbol: '₫', name: 'Vietnamese Dong'),
  ];

  String get dropdownLabel => '$code — $name ($symbol)';

  String get shortLabel => symbol == code ? code : '$code • $symbol';

  String format(num value, {int decimalDigits = 2}) {
    final decimalPattern = decimalDigits <= 0
        ? ''
        : '.${List.filled(decimalDigits, '0').join()}';
    final formatter = NumberFormat('#,##0$decimalPattern');
    return '$symbol ${formatter.format(value)}';
  }

  String formatCompact(num value) {
    return '$symbol ${NumberFormat.compact().format(value)}';
  }

  static CurrencySetting? presetByCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final item in presets) {
      if (item.code == normalized) return item;
    }
    return null;
  }

  static CurrencySetting fromStored({
    String? code,
    String? symbol,
    String? name,
  }) {
    final normalizedCode = (code ?? '').trim().toUpperCase();
    final normalizedSymbol = (symbol ?? '').trim();
    final normalizedName = (name ?? '').trim();

    if (normalizedCode.isEmpty) return pkr;

    final preset = presetByCode(normalizedCode);
    if (preset != null &&
        (normalizedSymbol.isEmpty || normalizedSymbol == preset.symbol) &&
        (normalizedName.isEmpty || normalizedName == preset.name)) {
      return preset;
    }

    return CurrencySetting(
      code: normalizedCode,
      symbol: normalizedSymbol.isEmpty ? normalizedCode : normalizedSymbol,
      name: normalizedName.isEmpty ? 'Custom currency' : normalizedName,
      isCustom: true,
    );
  }
}
