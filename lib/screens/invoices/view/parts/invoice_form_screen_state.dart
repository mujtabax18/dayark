part of '../InvoiceFormScreen.dart';

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final InvoiceProfileService _profileService;
  late final String _invoiceId;

  final _numberCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _poNumberCtrl = TextEditingController();

  final _businessNameCtrl = TextEditingController();
  final _businessAddressCtrl = TextEditingController();
  final _businessEmailCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _businessTaxIdCtrl = TextEditingController();

  final _customerNameCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _customerEmailCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  final _taxCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _shippingCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _paymentCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();

  final List<InvoiceItem> _items = [];

  String _status = 'draft';
  String _discountType = 'percentage';
  String _currencySymbol = 'PKR';
  String _templateStyle = 'modern';
  int _accentColorValue = 0xFF2563EB;
  double _backgroundOpacity = 0.06;
  String? _logoPath;
  String? _backgroundImagePath;
  bool _saving = false;
  bool _loadingProfiles = true;
  bool _customerUsageRecorded = false;
  String? _selectedBusinessId;
  String? _selectedCustomerId;
  InvoiceBusinessProfile? _selectedBusiness;
  InvoiceCustomerProfile? _selectedCustomer;
  InvoicePreferences _preferences = const InvoicePreferences();

  static const _statusOptions = <String>[
    'draft',
    'sent',
    'partially_paid',
    'paid',
    'overdue',
    'cancelled',
  ];

  static const _accentColors = <int>[
    0xFF2563EB,
    0xFF0F766E,
    0xFF7C3AED,
    0xFFB45309,
    0xFFBE123C,
    0xFF334155,
  ];

  @override
  void initState() {
    super.initState();
    _profileService = InvoiceProfileService(DatabaseService());
    final invoice = widget.invoice;
    _invoiceId = invoice?.id ?? _uuid.v4();
    _customerUsageRecorded = invoice != null;
    _currencySymbol = ref.read(currencyProvider).symbol;
    final now = DateTime.now();

    if (invoice == null) {
      _numberCtrl.text = 'INV-${DateFormat('yyyyMMdd-HHmm').format(now)}';
      _dateCtrl.text = _formatDate(now);
      _dueDateCtrl.text = _formatDate(now.add(const Duration(days: 7)));
    } else {
      _numberCtrl.text = invoice.number;
      _dateCtrl.text = _formatDate(invoice.date);
      _dueDateCtrl.text = _formatDate(invoice.dueDate);
      _poNumberCtrl.text = invoice.purchaseOrderNumber ?? '';
      _selectedBusinessId = invoice.businessId;
      _selectedCustomerId = invoice.customerId;

      _businessNameCtrl.text = invoice.businessName;
      _businessAddressCtrl.text = invoice.businessAddress;
      _businessEmailCtrl.text = invoice.businessEmail ?? '';
      _businessPhoneCtrl.text = invoice.businessPhone ?? '';
      _businessTaxIdCtrl.text = invoice.businessTaxId ?? '';

      _customerNameCtrl.text = invoice.customerName;
      _customerAddressCtrl.text = invoice.customerAddress;
      _customerEmailCtrl.text = invoice.customerEmail ?? '';
      _customerPhoneCtrl.text = invoice.customerPhone ?? '';

      _taxCtrl.text = _cleanNumber(invoice.taxRate);
      _discountCtrl.text = _cleanNumber(invoice.discountValue);
      _shippingCtrl.text = _cleanNumber(invoice.shippingAmount);
      _paidCtrl.text = _cleanNumber(invoice.paidAmount);
      _paymentCtrl.text = invoice.paymentInfo;
      _termsCtrl.text = invoice.terms ?? '';
      _notesCtrl.text = invoice.notes ?? '';
      _footerCtrl.text = invoice.footerText ?? '';

      _items.addAll(invoice.items);
      _status = invoice.status;
      _discountType = invoice.discountType;
      _currencySymbol = invoice.currencySymbol;
      _templateStyle = invoice.templateStyle;
      _accentColorValue = invoice.accentColorValue;
      _backgroundOpacity = invoice.backgroundOpacity
          .clamp(0.02, 0.20)
          .toDouble();
      _logoPath = invoice.logoPath;
      _backgroundImagePath = invoice.backgroundImagePath;
    }

    for (final controller in [
      _taxCtrl,
      _discountCtrl,
      _shippingCtrl,
      _paidCtrl,
    ]) {
      controller.addListener(_refreshTotals);
    }

    _loadReusableData();
  }

  @override
  void dispose() {
    for (final controller in [
      _numberCtrl,
      _dateCtrl,
      _dueDateCtrl,
      _poNumberCtrl,
      _businessNameCtrl,
      _businessAddressCtrl,
      _businessEmailCtrl,
      _businessPhoneCtrl,
      _businessTaxIdCtrl,
      _customerNameCtrl,
      _customerAddressCtrl,
      _customerEmailCtrl,
      _customerPhoneCtrl,
      _taxCtrl,
      _discountCtrl,
      _shippingCtrl,
      _paidCtrl,
      _paymentCtrl,
      _termsCtrl,
      _notesCtrl,
      _footerCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refreshTotals() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _cleanNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);

  double get _invoiceDiscount {
    final value = math.max(0, _number(_discountCtrl));
    if (_discountType == 'fixed') return math.min(value.toDouble(), _subtotal);
    return _subtotal * (math.min(value, 100) / 100);
  }

  double get _taxableAmount => math.max(0, _subtotal - _invoiceDiscount);

  double get _tax => _taxableAmount * (math.max(0, _number(_taxCtrl)) / 100);

  double get _total =>
      _taxableAmount + math.max(0, _number(_shippingCtrl)) + _tax;

  double get _balance => math.max(0, _total - math.max(0, _number(_paidCtrl)));

  Future<void> _loadReusableData() async {
    try {
      final preferences = await _profileService.getPreferences();
      InvoiceBusinessProfile? business;
      InvoiceCustomerProfile? customer;

      if (widget.invoice == null) {
        business = await _profileService.getDefaultBusiness();
      } else {
        final businessId = _selectedBusinessId;
        final customerId = _selectedCustomerId;
        if (businessId != null) {
          business = await _profileService.getBusiness(businessId);
        }
        if (customerId != null) {
          customer = await _profileService.getCustomer(customerId);
        }
      }

      if (!mounted) return;
      if (widget.invoice == null) {
        final now = DateTime.now();
        _dueDateCtrl.text = _formatDate(
          now.add(Duration(days: preferences.defaultDueDays)),
        );
        if (business != null) {
          _applyBusiness(business, notify: false);
        }
      }
      setState(() {
        _preferences = preferences;
        _selectedBusiness = business;
        _selectedCustomer = customer;
        _loadingProfiles = false;
        if (widget.invoice == null) {
          _status = _statusOptions.contains(preferences.defaultStatus)
              ? preferences.defaultStatus
              : 'draft';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingProfiles = false);
      _showMessage('Saved invoice profiles could not be loaded: $error');
    }
  }

  void _applyBusiness(InvoiceBusinessProfile business, {bool notify = true}) {
    _businessNameCtrl.text = business.name;
    _businessAddressCtrl.text = business.address;
    _businessEmailCtrl.text = business.email ?? '';
    _businessPhoneCtrl.text = business.phone ?? '';
    _businessTaxIdCtrl.text = business.taxId ?? '';
    _taxCtrl.text = _cleanNumber(business.defaultTaxRate);
    _paymentCtrl.text = business.paymentInfo;
    _termsCtrl.text = business.terms ?? '';
    _notesCtrl.text = business.customerNote ?? '';
    _footerCtrl.text = business.footerText ?? '';

    void applyState() {
      _selectedBusinessId = business.id;
      _selectedBusiness = business;
      _logoPath = business.logoPath;
      _backgroundImagePath = business.backgroundImagePath;
      _templateStyle = business.templateStyle;
      _accentColorValue = business.accentColorValue;
      _backgroundOpacity = business.backgroundOpacity
          .clamp(0.02, 0.20)
          .toDouble();
    }

    if (notify) {
      setState(applyState);
    } else {
      applyState();
    }
  }

  void _startNewBusiness() {
    _businessNameCtrl.clear();
    _businessAddressCtrl.clear();
    _businessEmailCtrl.clear();
    _businessPhoneCtrl.clear();
    _businessTaxIdCtrl.clear();
    _paymentCtrl.clear();
    _termsCtrl.clear();
    _notesCtrl.clear();
    _footerCtrl.clear();
    _taxCtrl.text = '0';
    setState(() {
      _selectedBusinessId = null;
      _selectedBusiness = null;
      _logoPath = null;
      _backgroundImagePath = null;
      _templateStyle = 'modern';
      _accentColorValue = 0xFF2563EB;
      _backgroundOpacity = 0.06;
      _currencySymbol = ref.read(currencyProvider).symbol;
    });
  }

  void _applyCustomer(InvoiceCustomerProfile customer) {
    setState(() {
      if (_selectedCustomerId != customer.id) {
        _customerUsageRecorded = false;
      }
      _selectedCustomerId = customer.id;
      _selectedCustomer = customer;
      _customerNameCtrl.text = customer.name;
      _customerAddressCtrl.text = customer.address;
      _customerEmailCtrl.text = customer.email ?? '';
      _customerPhoneCtrl.text = customer.phone ?? '';
    });
  }

  void _startNewCustomer() {
    setState(() {
      _customerUsageRecorded = false;
      _selectedCustomerId = null;
      _selectedCustomer = null;
      _customerNameCtrl.clear();
      _customerAddressCtrl.clear();
      _customerEmailCtrl.clear();
      _customerPhoneCtrl.clear();
    });
  }

  Future<void> _selectBusiness() async {
    final businesses = await _profileService.getBusinesses();
    if (!mounted) return;
    final selected = await showModalBottomSheet<InvoiceBusinessProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _BusinessSelectionSheet(
        businesses: businesses,
        selectedId: _selectedBusinessId,
      ),
    );
    if (selected != null && mounted) _applyBusiness(selected);
  }

  Future<void> _selectCustomer() async {
    final customers = await _profileService.getCustomers();
    if (!mounted) return;
    final selected = await showModalBottomSheet<InvoiceCustomerProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CustomerSelectionSheet(
        customers: customers,
        selectedId: _selectedCustomerId,
      ),
    );
    if (selected != null && mounted) _applyCustomer(selected);
  }

  Future<void> _openDataManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InvoiceDataManagementScreen(),
      ),
    );
    if (!mounted) return;
    final businessId = _selectedBusinessId;
    final customerId = _selectedCustomerId;
    if (businessId != null) {
      final business = await _profileService.getBusiness(businessId);
      if (business != null && mounted) _applyBusiness(business);
    }
    if (customerId != null) {
      final customer = await _profileService.getCustomer(customerId);
      if (customer != null && mounted) _applyCustomer(customer);
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistReusableData() async {
    final now = DateTime.now();

    if (_preferences.autoSaveBusinesses || _selectedBusinessId != null) {
      InvoiceBusinessProfile? existing = _selectedBusiness;
      if (_selectedBusinessId == null) {
        existing = await _profileService.findMatchingBusiness(
          name: _businessNameCtrl.text,
          address: _businessAddressCtrl.text,
          email: _optional(_businessEmailCtrl),
          phone: _optional(_businessPhoneCtrl),
        );
      }
      final business = InvoiceBusinessProfile(
        id: _selectedBusinessId ?? existing?.id ?? _uuid.v4(),
        name: _businessNameCtrl.text.trim(),
        address: _businessAddressCtrl.text.trim(),
        email: _optional(_businessEmailCtrl),
        phone: _optional(_businessPhoneCtrl),
        taxId: _optional(_businessTaxIdCtrl),
        logoPath: _logoPath,
        backgroundImagePath: _backgroundImagePath,
        templateStyle: _templateStyle,
        accentColorValue: _accentColorValue,
        backgroundOpacity: _backgroundOpacity,
        currencySymbol: _currencySymbol,
        defaultTaxRate: math.max(0, _number(_taxCtrl)),
        paymentInfo: _paymentCtrl.text.trim(),
        terms: _optional(_termsCtrl),
        customerNote: _optional(_notesCtrl),
        footerText: _optional(_footerCtrl),
        isDefault: existing?.isDefault ?? false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _profileService.upsertBusiness(business);
      _selectedBusinessId = business.id;
      _selectedBusiness = business;
    }

    if (_preferences.autoSaveCustomers || _selectedCustomerId != null) {
      InvoiceCustomerProfile? existing = _selectedCustomer;
      if (_selectedCustomerId == null) {
        existing = await _profileService.findMatchingCustomer(
          name: _customerNameCtrl.text,
          address: _customerAddressCtrl.text,
          email: _optional(_customerEmailCtrl),
          phone: _optional(_customerPhoneCtrl),
        );
      }
      final customer = InvoiceCustomerProfile(
        id: _selectedCustomerId ?? existing?.id ?? _uuid.v4(),
        name: _customerNameCtrl.text.trim(),
        company: existing?.company,
        address: _customerAddressCtrl.text.trim(),
        email: _optional(_customerEmailCtrl),
        phone: _optional(_customerPhoneCtrl),
        taxId: existing?.taxId,
        notes: existing?.notes,
        usageCount: existing?.usageCount ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastUsedAt: existing?.lastUsedAt,
      );
      final shouldRecordUsage = !_customerUsageRecorded;
      await _profileService.upsertCustomer(
        customer,
        markUsed: shouldRecordUsage,
      );
      _selectedCustomerId = customer.id;
      _customerUsageRecorded = true;
      _selectedCustomer = customer.copyWith(
        usageCount: customer.usageCount + (shouldRecordUsage ? 1 : 0),
        lastUsedAt: shouldRecordUsage ? now : customer.lastUsedAt,
      );
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate =
        DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final neutral = context.themeColors.neutral;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(_accentColorValue),
            brightness: Theme.of(context).brightness,
          ),
          dialogBackgroundColor: neutral.card,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => controller.text = _formatDate(picked));
    }
  }

  Future<void> _pickBrandAsset({required bool background}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return;

    final selected = result.single;
    final documents = await getApplicationDocumentsDirectory();
    final assetsDirectory = Directory(p.join(documents.path, 'invoice_assets'));
    await assetsDirectory.create(recursive: true);

    final extension = p.extension(selected.name).isEmpty
        ? '.png'
        : p.extension(selected.name).toLowerCase();
    final fileName =
        '${background ? 'background' : 'logo'}_'
        '${DateTime.now().microsecondsSinceEpoch}$extension';
    final target = File(p.join(assetsDirectory.path, fileName));
    final bytes = await selected.readAsBytes();
    await target.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    setState(() {
      if (background) {
        _backgroundImagePath = target.path;
      } else {
        _logoPath = target.path;
      }
    });
  }

  Future<void> _openItemEditor({InvoiceItem? item}) async {
    final description = TextEditingController(text: item?.description ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final unit = TextEditingController(text: item?.unit ?? 'item');
    final quantity = TextEditingController(
      text: item == null ? '1' : _cleanNumber(item.quantity),
    );
    final price = TextEditingController(
      text: item == null ? '' : _cleanNumber(item.unitPrice),
    );
    final discount = TextEditingController(
      text: item == null ? '0' : _cleanNumber(item.discountPercent),
    );

    final result = await showModalBottomSheet<InvoiceItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.themeColors.neutral.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final neutral = sheetContext.themeColors.neutral;
            final qty = double.tryParse(quantity.text.trim()) ?? 0;
            final rate = double.tryParse(price.text.trim()) ?? 0;
            final discountValue = (double.tryParse(discount.text.trim()) ?? 0)
                .clamp(0, 100);
            final total = qty * rate * (1 - discountValue / 100);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: neutral.divider,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      item == null ? 'Add line item' : 'Edit line item',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      description,
                      'Description',
                      required: true,
                      icon: Icons.inventory_2_outlined,
                    ),
                    Row(
                      children: [
                        Expanded(child: _field(sku, 'SKU / code')),
                        const SizedBox(width: 12),
                        Expanded(child: _field(unit, 'Unit')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            quantity,
                            'Quantity',
                            required: true,
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            price,
                            'Unit price',
                            required: true,
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    _field(
                      discount,
                      'Item discount %',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color(_accentColorValue).withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Line total: $_currencySymbol${total.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(_accentColorValue),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Color(_accentColorValue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final parsedQuantity = double.tryParse(
                            quantity.text.trim(),
                          );
                          final parsedPrice = double.tryParse(
                            price.text.trim(),
                          );
                          if (description.text.trim().isEmpty ||
                              parsedQuantity == null ||
                              parsedQuantity <= 0 ||
                              parsedPrice == null ||
                              parsedPrice < 0) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter a description, valid quantity and price.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.of(sheetContext).pop(
                            InvoiceItem(
                              id: item?.id ?? _uuid.v4(),
                              description: description.text.trim(),
                              sku: sku.text.trim().isEmpty
                                  ? null
                                  : sku.text.trim(),
                              unit: unit.text.trim().isEmpty
                                  ? 'item'
                                  : unit.text.trim(),
                              quantity: parsedQuantity,
                              unitPrice: parsedPrice,
                              discountPercent:
                                  (double.tryParse(discount.text.trim()) ?? 0)
                                      .clamp(0, 100)
                                      .toDouble(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: Text(item == null ? 'Add item' : 'Update item'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    description.dispose();
    sku.dispose();
    unit.dispose();
    quantity.dispose();
    price.dispose();
    discount.dispose();

    if (result == null || !mounted) return;
    setState(() {
      final existingIndex = _items.indexWhere((value) => value.id == result.id);
      if (existingIndex == -1) {
        _items.add(result);
      } else {
        _items[existingIndex] = result;
      }
    });
  }

  Invoice _buildInvoice() {
    return Invoice(
      id: _invoiceId,
      number: _numberCtrl.text.trim(),
      date: DateTime.parse(_dateCtrl.text.trim()),
      dueDate: DateTime.parse(_dueDateCtrl.text.trim()),
      businessId: _selectedBusinessId,
      customerId: _selectedCustomerId,
      businessName: _businessNameCtrl.text.trim(),
      businessAddress: _businessAddressCtrl.text.trim(),
      businessEmail: _optional(_businessEmailCtrl),
      businessPhone: _optional(_businessPhoneCtrl),
      businessTaxId: _optional(_businessTaxIdCtrl),
      customerName: _customerNameCtrl.text.trim(),
      customerAddress: _customerAddressCtrl.text.trim(),
      customerEmail: _optional(_customerEmailCtrl),
      customerPhone: _optional(_customerPhoneCtrl),
      purchaseOrderNumber: _optional(_poNumberCtrl),
      items: List.unmodifiable(_items),
      currencySymbol: _currencySymbol,
      taxRate: math.max(0, _number(_taxCtrl)),
      discountType: _discountType,
      discountValue: math.max(0, _number(_discountCtrl)),
      shippingAmount: math.max(0, _number(_shippingCtrl)),
      paidAmount: math.max(0, _number(_paidCtrl)),
      status: _status,
      paymentInfo: _paymentCtrl.text.trim(),
      terms: _optional(_termsCtrl),
      notes: _optional(_notesCtrl),
      footerText: _optional(_footerCtrl),
      logoPath: _logoPath,
      backgroundImagePath: _backgroundImagePath,
      templateStyle: _templateStyle,
      accentColorValue: _accentColorValue,
      backgroundOpacity: _backgroundOpacity,
    );
  }

  Future<void> _save({bool preview = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _showMessage('Add at least one invoice item.');
      return;
    }

    if (widget.invoice == null) {
      _currencySymbol = ref.read(currencyProvider).symbol;
    }

    setState(() => _saving = true);
    try {
      await _persistReusableData();
      final invoice = _buildInvoice();
      final notifier = ref.read(invoicesProvider.notifier);
      if (widget.invoice == null) {
        await notifier.addInvoice(invoice);
      } else {
        await notifier.updateInvoice(invoice);
      }

      if (!mounted) return;
      if (preview) {
        await PdfInvoiceService.generateAndPreview(invoice, context);
      } else {
        if (widget.desktopEmbedded) {
          Navigator.of(context).pop();
        } else {
          context.pop();
        }
      }
    } catch (error) {
      if (mounted) _showMessage('Invoice could not be saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: Text(
          widget.invoice == null ? 'Create invoice' : 'Edit invoice',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Manage businesses, customers and defaults',
            onPressed: _saving ? null : _openDataManager,
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : () => _save(),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.save_outlined, color: accent),
          ),
        ],
      ),
      body: DesktopContentFrame(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _introBanner(accent),
            _section(
              title: 'Invoice details',
              icon: Icons.receipt_long_outlined,
              children: [
                _field(
                  _numberCtrl,
                  'Invoice number',
                  required: true,
                  icon: Icons.tag,
                ),
                Row(
                  children: [
                    Expanded(child: _dateField(_dateCtrl, 'Invoice date')),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField(_dueDateCtrl, 'Due date')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_poNumberCtrl, 'PO / reference')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await context.push(RoutesStr.settings);
                          if (!mounted || widget.invoice != null) return;
                          setState(() {
                            _currencySymbol = ref.read(currencyProvider).symbol;
                          });
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            suffixIcon: Icon(Icons.settings_outlined),
                          ),
                          child: Text(
                            '$_currencySymbol • app setting',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Invoice status',
                  value: _statusOptions.contains(_status) ? _status : 'draft',
                  values: _statusOptions,
                  display: _statusLabel,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ],
            ),
            _section(
              title: 'Business & branding',
              icon: Icons.storefront_outlined,
              children: [
                _profileActions(
                  selectedLabel: _selectedBusiness == null
                      ? 'New business details'
                      : _selectedBusiness!.name,
                  saved: _selectedBusinessId != null,
                  autoSave: _preferences.autoSaveBusinesses,
                  selectLabel: 'Use saved business',
                  onSelect: _selectBusiness,
                  onNew: _startNewBusiness,
                ),
                _field(
                  _businessNameCtrl,
                  'Business / sender name',
                  required: true,
                  icon: Icons.business_outlined,
                ),
                _field(
                  _businessAddressCtrl,
                  'Business address',
                  required: true,
                  maxLines: 2,
                  icon: Icons.location_on_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _businessEmailCtrl,
                        'Business email',
                        keyboard: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _businessPhoneCtrl,
                        'Business phone',
                        keyboard: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                _field(_businessTaxIdCtrl, 'Tax / registration ID'),
                _assetPicker(
                  title: 'Header logo',
                  subtitle: 'Shown beside your business details.',
                  path: _logoPath,
                  onPick: () => _pickBrandAsset(background: false),
                  onRemove: () => setState(() => _logoPath = null),
                ),
                const SizedBox(height: 12),
                _assetPicker(
                  title: 'Background logo or image',
                  subtitle: 'Printed as a light full-page watermark.',
                  path: _backgroundImagePath,
                  onPick: () => _pickBrandAsset(background: true),
                  onRemove: () => setState(() => _backgroundImagePath = null),
                ),
                if (_backgroundImagePath != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Background opacity: ${(_backgroundOpacity * 100).round()}%',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Slider(
                    value: _backgroundOpacity,
                    min: 0.02,
                    max: 0.20,
                    divisions: 18,
                    activeColor: accent,
                    onChanged: (value) =>
                        setState(() => _backgroundOpacity = value),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'PDF style',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['modern', 'classic', 'minimal']
                      .map(
                        (style) => ChoiceChip(
                          label: Text(_titleCase(style)),
                          selected: _templateStyle == style,
                          selectedColor: accent.withOpacity(.16),
                          side: BorderSide(
                            color: _templateStyle == style
                                ? accent
                                : neutral.divider,
                          ),
                          onSelected: (_) =>
                              setState(() => _templateStyle = style),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                Text(
                  'Accent color',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _accentColors
                      .map((colorValue) {
                        final selected = colorValue == _accentColorValue;
                        return InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () =>
                              setState(() => _accentColorValue = colorValue),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? neutral.textPrimary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: selected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
            _section(
              title: 'Bill to',
              icon: Icons.person_outline,
              children: [
                _profileActions(
                  selectedLabel: _selectedCustomer == null
                      ? 'New customer details'
                      : _selectedCustomer!.displayName,
                  saved: _selectedCustomerId != null,
                  autoSave: _preferences.autoSaveCustomers,
                  selectLabel: 'Use existing customer',
                  onSelect: _selectCustomer,
                  onNew: _startNewCustomer,
                ),
                _field(
                  _customerNameCtrl,
                  'Customer name',
                  required: true,
                  icon: Icons.person_outline,
                ),
                _field(
                  _customerAddressCtrl,
                  'Customer address',
                  required: true,
                  maxLines: 2,
                  icon: Icons.location_on_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _customerEmailCtrl,
                        'Customer email',
                        keyboard: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _customerPhoneCtrl,
                        'Customer phone',
                        keyboard: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _section(
              title: 'Line items',
              icon: Icons.format_list_bulleted,
              trailing: TextButton.icon(
                onPressed: () => _openItemEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
              children: [
                if (_items.isEmpty) _emptyItems() else ..._items.map(_itemCard),
              ],
            ),
            _section(
              title: 'Totals & payment',
              icon: Icons.calculate_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _taxCtrl,
                        'Tax %',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        label: 'Discount type',
                        value: _discountType,
                        values: const ['percentage', 'fixed'],
                        display: (value) =>
                            value == 'fixed' ? 'Fixed amount' : 'Percentage',
                        onChanged: (value) =>
                            setState(() => _discountType = value),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _discountCtrl,
                        _discountType == 'fixed'
                            ? 'Invoice discount amount'
                            : 'Invoice discount %',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _shippingCtrl,
                        'Shipping / extra charge',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                _field(
                  _paidCtrl,
                  'Amount already paid',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _totalsCard(),
              ],
            ),
            _section(
              title: 'Payment instructions & notes',
              icon: Icons.description_outlined,
              children: [
                _field(
                  _paymentCtrl,
                  'Payment information',
                  required: true,
                  maxLines: 3,
                  hint: 'Bank details, wallet, cash instructions, etc.',
                ),
                _field(
                  _termsCtrl,
                  'Terms and conditions',
                  maxLines: 3,
                  hint: 'Late fee, return policy, payment deadline, etc.',
                ),
                _field(_notesCtrl, 'Customer note', maxLines: 3),
                _field(
                  _footerCtrl,
                  'Footer message',
                  maxLines: 2,
                  hint: 'Thank you for your business.',
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : () => _save(preview: true),
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('Save & preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : () => _save(),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save invoice'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _profileActions({
    required String selectedLabel,
    required bool saved,
    required bool autoSave,
    required String selectLabel,
    required VoidCallback onSelect,
    required VoidCallback onNew,
  }) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                saved ? Icons.cloud_done_outlined : Icons.edit_note_outlined,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_loadingProfiles)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  saved
                      ? 'Linked profile'
                      : autoSave
                      ? 'Saves with invoice'
                      : 'Auto-save off',
                  style: TextStyle(color: neutral.textSecondary, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadingProfiles ? null : onSelect,
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: Text(selectLabel),
              ),
              TextButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Enter new'),
              ),
              TextButton.icon(
                onPressed: _openDataManager,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Manage'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _introBanner(Color accent) {
    final neutral = context.themeColors.neutral;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(.18), accent.withOpacity(.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Professional invoice editor',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Reuse saved businesses and customers, then customize calculations and PDF appearance.',
                  style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _assetPicker({
    required String title,
    required String subtitle,
    required String? path,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);
    final exists = path != null && File(path).existsSync();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: exists
                ? Image.file(File(path), fit: BoxFit.cover)
                : Icon(Icons.image_outlined, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  exists ? p.basename(path) : subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: exists ? 'Replace image' : 'Choose image',
            onPressed: onPick,
            icon: Icon(Icons.folder_open_outlined, color: accent),
          ),
          if (exists)
            IconButton(
              tooltip: 'Remove image',
              onPressed: onRemove,
              icon: Icon(Icons.close, color: AppColors.danger),
            ),
        ],
      ),
    );
  }

  Widget _emptyItems() {
    final neutral = context.themeColors.neutral;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_outlined,
            color: neutral.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No line items yet',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add products, services, quantities and item discounts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: neutral.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _openItemEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Add first item'),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(InvoiceItem item) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_cleanNumber(item.quantity)} ${item.unit} × '
                  '$_currencySymbol${item.unitPrice.toStringAsFixed(2)}'
                  '${item.discountPercent > 0 ? ' • ${_cleanNumber(item.discountPercent)}% off' : ''}',
                  style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                ),
                if (item.sku != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_currencySymbol${item.total.toStringAsFixed(2)}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit item',
                    onPressed: () => _openItemEditor(item: item),
                    icon: Icon(Icons.edit_outlined, color: accent, size: 19),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete item',
                    onPressed: () => setState(() => _items.remove(item)),
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsCard() {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(.20)),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          if (_invoiceDiscount > 0)
            _totalRow('Invoice discount', -_invoiceDiscount),
          if (_tax > 0)
            _totalRow('Tax (${_number(_taxCtrl).toStringAsFixed(1)}%)', _tax),
          if (_number(_shippingCtrl) > 0)
            _totalRow('Shipping / extra', _number(_shippingCtrl)),
          Divider(color: neutral.divider),
          _totalRow('Invoice total', _total, strong: true),
          if (_number(_paidCtrl) > 0) _totalRow('Paid', -_number(_paidCtrl)),
          const SizedBox(height: 4),
          _totalRow('Balance due', _balance, strong: true, accent: true),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool strong = false,
    bool accent = false,
  }) {
    final neutral = context.themeColors.neutral;
    final color = accent ? Color(_accentColorValue) : neutral.textPrimary;
    final prefix = value < 0 ? '-' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? color : neutral.textSecondary,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$prefix$_currencySymbol${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(color: neutral.textPrimary),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          return null;
        },
        decoration: _inputDecoration(label: label, icon: icon, hint: hint),
      ),
    );
  }

  Widget _dateField(TextEditingController controller, String label) {
    final neutral = context.themeColors.neutral;
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required' : null,
      style: TextStyle(color: neutral.textPrimary),
      decoration: _inputDecoration(
        label: label,
        icon: Icons.calendar_today_outlined,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    String Function(String)? display,
  }) {
    final neutral = context.themeColors.neutral;
    return DropdownButtonFormField<String>(
      value: values.contains(value) ? value : values.first,
      isExpanded: true,
      dropdownColor: neutral.card,
      style: TextStyle(color: neutral.textPrimary),
      decoration: _inputDecoration(label: label),
      items: values
          .map(
            (entry) => DropdownMenuItem(
              value: entry,
              child: Text(display?.call(entry) ?? entry),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: neutral.textSecondary),
      hintStyle: TextStyle(color: neutral.textSecondary.withOpacity(.75)),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: neutral.textSecondary),
      filled: true,
      fillColor: neutral.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: neutral.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.danger),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'partially_paid':
        return 'Partially paid';
      default:
        return _titleCase(value);
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
  }
}

