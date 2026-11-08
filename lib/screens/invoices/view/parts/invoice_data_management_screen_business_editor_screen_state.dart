part of '../InvoiceDataManagementScreen.dart';

class _BusinessEditorScreenState extends ConsumerState<_BusinessEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _taxId;
  late final TextEditingController _taxRate;
  late final TextEditingController _payment;
  late final TextEditingController _terms;
  late final TextEditingController _note;
  late final TextEditingController _footer;
  late String _template;
  late int _accent;
  late double _opacity;
  late bool _isDefault;
  String? _logoPath;
  String? _backgroundPath;
  bool _saving = false;

  static const _colors = [
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
    final value = widget.business;
    _name = TextEditingController(text: value?.name ?? '');
    _address = TextEditingController(text: value?.address ?? '');
    _email = TextEditingController(text: value?.email ?? '');
    _phone = TextEditingController(text: value?.phone ?? '');
    _taxId = TextEditingController(text: value?.taxId ?? '');
    _taxRate = TextEditingController(text: _number(value?.defaultTaxRate ?? 0));
    _payment = TextEditingController(text: value?.paymentInfo ?? '');
    _terms = TextEditingController(text: value?.terms ?? '');
    _note = TextEditingController(text: value?.customerNote ?? '');
    _footer = TextEditingController(text: value?.footerText ?? '');
    _template = value?.templateStyle ?? 'modern';
    _accent = value?.accentColorValue ?? 0xFF2563EB;
    _opacity = value?.backgroundOpacity ?? 0.06;
    _isDefault = value?.isDefault ?? false;
    _logoPath = value?.logoPath;
    _backgroundPath = value?.backgroundImagePath;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _email,
      _phone,
      _taxId,
      _taxRate,
      _payment,
      _terms,
      _note,
      _footer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAsset({required bool background}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return;
    final selected = result.single;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'invoice_assets'));
    await directory.create(recursive: true);
    final extension = p.extension(selected.name).isEmpty
        ? '.png'
        : p.extension(selected.name).toLowerCase();
    final target = File(
      p.join(
        directory.path,
        '${background ? 'background' : 'logo'}_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    final bytes = await selected.readAsBytes();
    await target.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    setState(() {
      if (background) {
        _backgroundPath = target.path;
      } else {
        _logoPath = target.path;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.business;
    final business = InvoiceBusinessProfile(
      id: existing?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      address: _address.text.trim(),
      email: _optional(_email.text),
      phone: _optional(_phone.text),
      taxId: _optional(_taxId.text),
      logoPath: _logoPath,
      backgroundImagePath: _backgroundPath,
      templateStyle: _template,
      accentColorValue: _accent,
      backgroundOpacity: _opacity,
      currencySymbol: ref.read(currencyProvider).symbol,
      defaultTaxRate: double.tryParse(_taxRate.text.trim()) ?? 0,
      paymentInfo: _payment.text.trim(),
      terms: _optional(_terms.text),
      customerNote: _optional(_note.text),
      footerText: _optional(_footer.text),
      isDefault: _isDefault,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await widget.service.upsertBusiness(business);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_accent);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.business == null ? 'Add business' : 'Edit business'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormSection(
              title: 'Business details',
              children: [
                _requiredField(_name, 'Business name'),
                _requiredField(_address, 'Address', maxLines: 2),
                _field(
                  _email,
                  'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(_phone, 'Phone', keyboardType: TextInputType.phone),
                _field(_taxId, 'Tax / registration ID'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use as default business'),
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                ),
              ],
            ),
            _FormSection(
              title: 'Invoice defaults',
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(RoutesStr.settings),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      suffixIcon: Icon(Icons.settings_outlined),
                    ),
                    child: Text(
                      '${ref.watch(currencyProvider).symbol} • app setting',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  _taxRate,
                  'Default tax %',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _requiredField(_payment, 'Payment information', maxLines: 3),
                _field(_terms, 'Terms and conditions', maxLines: 3),
                _field(_note, 'Default customer note', maxLines: 3),
                _field(_footer, 'Footer message', maxLines: 2),
              ],
            ),
            _FormSection(
              title: 'Branding',
              children: [
                _AssetTile(
                  title: 'Header logo',
                  path: _logoPath,
                  onPick: () => _pickAsset(background: false),
                  onRemove: () => setState(() => _logoPath = null),
                ),
                const SizedBox(height: 10),
                _AssetTile(
                  title: 'Background watermark',
                  path: _backgroundPath,
                  onPick: () => _pickAsset(background: true),
                  onRemove: () => setState(() => _backgroundPath = null),
                ),
                if (_backgroundPath != null) ...[
                  const SizedBox(height: 8),
                  Text('Background opacity: ${(_opacity * 100).round()}%'),
                  Slider(
                    value: _opacity,
                    min: 0.02,
                    max: 0.20,
                    divisions: 18,
                    onChanged: (value) => setState(() => _opacity = value),
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'modern', label: Text('Modern')),
                    ButtonSegment(value: 'classic', label: Text('Classic')),
                    ButtonSegment(value: 'minimal', label: Text('Minimal')),
                  ],
                  selected: {_template},
                  onSelectionChanged: (value) {
                    setState(() => _template = value.first);
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors
                      .map((value) {
                        final selected = value == _accent;
                        return InkWell(
                          onTap: () => setState(() => _accent = value),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.onSurface
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
                const SizedBox(height: 8),
                Text(
                  'Selected accent',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save business'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerEditorScreen extends StatefulWidget {
  const _CustomerEditorScreen({required this.service, this.customer});

  final InvoiceProfileService service;
  final InvoiceCustomerProfile? customer;

  @override
  State<_CustomerEditorScreen> createState() => _CustomerEditorScreenState();
}

class _CustomerEditorScreenState extends State<_CustomerEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _address;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _taxId;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.customer;
    _name = TextEditingController(text: value?.name ?? '');
    _company = TextEditingController(text: value?.company ?? '');
    _address = TextEditingController(text: value?.address ?? '');
    _email = TextEditingController(text: value?.email ?? '');
    _phone = TextEditingController(text: value?.phone ?? '');
    _taxId = TextEditingController(text: value?.taxId ?? '');
    _notes = TextEditingController(text: value?.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _company,
      _address,
      _email,
      _phone,
      _taxId,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.customer;
    await widget.service.upsertCustomer(
      InvoiceCustomerProfile(
        id: existing?.id ?? _uuid.v4(),
        name: _name.text.trim(),
        company: _optional(_company.text),
        address: _address.text.trim(),
        email: _optional(_email.text),
        phone: _optional(_phone.text),
        taxId: _optional(_taxId.text),
        notes: _optional(_notes.text),
        usageCount: existing?.usageCount ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastUsedAt: existing?.lastUsedAt,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add customer' : 'Edit customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormSection(
              title: 'Customer details',
              children: [
                _requiredField(_name, 'Customer name'),
                _field(_company, 'Company / organization'),
                _requiredField(_address, 'Billing address', maxLines: 2),
                _field(
                  _email,
                  'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(_phone, 'Phone', keyboardType: TextInputType.phone),
                _field(_taxId, 'Tax / registration ID'),
                _field(_notes, 'Internal notes', maxLines: 3),
              ],
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.business});

  final InvoiceBusinessProfile business;

  @override
  Widget build(BuildContext context) {
    final path = business.logoPath;
    final hasFile = path != null && File(path).existsSync();
    return CircleAvatar(
      backgroundColor: Color(business.accentColorValue).withOpacity(.14),
      backgroundImage: hasFile ? FileImage(File(path)) : null,
      child: hasFile
          ? null
          : Icon(Icons.storefront, color: Color(business.accentColorValue)),
    );
  }
}

