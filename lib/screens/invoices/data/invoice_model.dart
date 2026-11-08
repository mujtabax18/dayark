import 'dart:math' as math;

class Invoice {
  final String id;
  final String number;
  final DateTime date;
  final DateTime dueDate;

  // Optional reusable profile links. Invoice values below remain snapshots.
  final String? businessId;
  final String? customerId;

  // Business snapshot
  final String businessName;
  final String businessAddress;
  final String? businessEmail;
  final String? businessPhone;
  final String? businessTaxId;

  // Customer snapshot
  final String customerName;
  final String customerAddress;
  final String? customerEmail;
  final String? customerPhone;

  final String? purchaseOrderNumber;
  final List<InvoiceItem> items;
  final String currencySymbol;
  final double taxRate;
  final String discountType;
  final double discountValue;
  final double shippingAmount;
  final double paidAmount;
  final String status;

  final String paymentInfo;
  final String? terms;
  final String? notes;
  final String? footerText;

  // PDF design settings
  final String? logoPath;
  final String? backgroundImagePath;
  final String templateStyle;
  final int accentColorValue;
  final double backgroundOpacity;

  const Invoice({
    required this.id,
    required this.number,
    required this.date,
    required this.dueDate,
    this.businessId,
    this.customerId,
    this.businessName = '',
    this.businessAddress = '',
    this.businessEmail,
    this.businessPhone,
    this.businessTaxId,
    required this.customerName,
    required this.customerAddress,
    this.customerEmail,
    this.customerPhone,
    this.purchaseOrderNumber,
    required this.items,
    this.currencySymbol = 'PKR',
    required this.taxRate,
    this.discountType = 'percentage',
    this.discountValue = 0,
    this.shippingAmount = 0,
    this.paidAmount = 0,
    this.status = 'draft',
    required this.paymentInfo,
    this.terms,
    this.notes,
    this.footerText,
    this.logoPath,
    this.backgroundImagePath,
    this.templateStyle = 'modern',
    this.accentColorValue = 0xFF2563EB,
    this.backgroundOpacity = 0.06,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  double get itemDiscountTotal =>
      items.fold(0, (sum, item) => sum + item.discountAmount);

  double get discountAmount {
    if (discountType == 'fixed') {
      return math.min(math.max(discountValue, 0), subtotal);
    }
    final percentage = math.min(math.max(discountValue, 0), 100);
    return subtotal * (percentage / 100);
  }

  double get taxableAmount => math.max(0, subtotal - discountAmount);

  double get tax => taxableAmount * (math.max(taxRate, 0) / 100);

  double get total => taxableAmount + math.max(shippingAmount, 0) + tax;

  double get balanceDue => math.max(0, total - math.max(paidAmount, 0));

  bool get isPaid => balanceDue <= 0.009;

  Invoice copyWith({
    String? id,
    String? number,
    DateTime? date,
    DateTime? dueDate,
    String? businessId,
    String? customerId,
    String? businessName,
    String? businessAddress,
    String? businessEmail,
    String? businessPhone,
    String? businessTaxId,
    String? customerName,
    String? customerAddress,
    String? customerEmail,
    String? customerPhone,
    String? purchaseOrderNumber,
    List<InvoiceItem>? items,
    String? currencySymbol,
    double? taxRate,
    String? discountType,
    double? discountValue,
    double? shippingAmount,
    double? paidAmount,
    String? status,
    String? paymentInfo,
    String? terms,
    String? notes,
    String? footerText,
    String? logoPath,
    String? backgroundImagePath,
    String? templateStyle,
    int? accentColorValue,
    double? backgroundOpacity,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessEmail: businessEmail ?? this.businessEmail,
      businessPhone: businessPhone ?? this.businessPhone,
      businessTaxId: businessTaxId ?? this.businessTaxId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      purchaseOrderNumber: purchaseOrderNumber ?? this.purchaseOrderNumber,
      items: items ?? this.items,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      shippingAmount: shippingAmount ?? this.shippingAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      terms: terms ?? this.terms,
      notes: notes ?? this.notes,
      footerText: footerText ?? this.footerText,
      logoPath: logoPath ?? this.logoPath,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      templateStyle: templateStyle ?? this.templateStyle,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }
}

class InvoiceItem {
  final String id;
  final String description;
  final String? sku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double discountPercent;

  const InvoiceItem({
    required this.id,
    required this.description,
    this.sku,
    this.unit = 'item',
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
  });

  double get grossTotal => quantity * unitPrice;

  double get discountAmount {
    final percentage = math.min(math.max(discountPercent, 0), 100);
    return grossTotal * (percentage / 100);
  }

  double get total => grossTotal - discountAmount;

  InvoiceItem copyWith({
    String? id,
    String? description,
    String? sku,
    String? unit,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}
