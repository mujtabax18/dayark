class InvoiceBusinessProfile {
  const InvoiceBusinessProfile({
    required this.id,
    required this.name,
    required this.address,
    this.email,
    this.phone,
    this.taxId,
    this.logoPath,
    this.backgroundImagePath,
    this.templateStyle = 'modern',
    this.accentColorValue = 0xFF2563EB,
    this.backgroundOpacity = 0.06,
    this.currencySymbol = 'PKR',
    this.defaultTaxRate = 0,
    this.paymentInfo = '',
    this.terms,
    this.customerNote,
    this.footerText,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String? email;
  final String? phone;
  final String? taxId;
  final String? logoPath;
  final String? backgroundImagePath;
  final String templateStyle;
  final int accentColorValue;
  final double backgroundOpacity;
  final String currencySymbol;
  final double defaultTaxRate;
  final String paymentInfo;
  final String? terms;
  final String? customerNote;
  final String? footerText;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvoiceBusinessProfile copyWith({
    String? id,
    String? name,
    String? address,
    String? email,
    String? phone,
    String? taxId,
    String? logoPath,
    String? backgroundImagePath,
    String? templateStyle,
    int? accentColorValue,
    double? backgroundOpacity,
    String? currencySymbol,
    double? defaultTaxRate,
    String? paymentInfo,
    String? terms,
    String? customerNote,
    String? footerText,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceBusinessProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      logoPath: logoPath ?? this.logoPath,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      templateStyle: templateStyle ?? this.templateStyle,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      terms: terms ?? this.terms,
      customerNote: customerNote ?? this.customerNote,
      footerText: footerText ?? this.footerText,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class InvoiceCustomerProfile {
  const InvoiceCustomerProfile({
    required this.id,
    required this.name,
    this.company,
    required this.address,
    this.email,
    this.phone,
    this.taxId,
    this.notes,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String? company;
  final String address;
  final String? email;
  final String? phone;
  final String? taxId;
  final String? notes;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  String get displayName {
    final companyName = company?.trim() ?? '';
    return companyName.isEmpty ? name : '$name • $companyName';
  }

  InvoiceCustomerProfile copyWith({
    String? id,
    String? name,
    String? company,
    String? address,
    String? email,
    String? phone,
    String? taxId,
    String? notes,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return InvoiceCustomerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      notes: notes ?? this.notes,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

class InvoicePreferences {
  const InvoicePreferences({
    this.defaultDueDays = 7,
    this.defaultStatus = 'draft',
    this.autoSaveBusinesses = true,
    this.autoSaveCustomers = true,
  });

  final int defaultDueDays;
  final String defaultStatus;
  final bool autoSaveBusinesses;
  final bool autoSaveCustomers;

  InvoicePreferences copyWith({
    int? defaultDueDays,
    String? defaultStatus,
    bool? autoSaveBusinesses,
    bool? autoSaveCustomers,
  }) {
    return InvoicePreferences(
      defaultDueDays: defaultDueDays ?? this.defaultDueDays,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      autoSaveBusinesses: autoSaveBusinesses ?? this.autoSaveBusinesses,
      autoSaveCustomers: autoSaveCustomers ?? this.autoSaveCustomers,
    );
  }
}
