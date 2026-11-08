part of '../InvoiceDataManagementScreen.dart';

class _PreferencesTabState extends State<_PreferencesTab> {
  InvoicePreferences? _preferences;
  bool _loading = true;
  bool _saving = false;

  static const _statuses = [
    'draft',
    'sent',
    'partially_paid',
    'paid',
    'overdue',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await widget.service.getPreferences();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final preferences = _preferences;
    if (preferences == null) return;
    setState(() => _saving = true);
    await widget.service.savePreferences(preferences);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invoice defaults saved.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final preferences = _preferences!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New invoice behavior',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value:
                      [
                        0,
                        7,
                        14,
                        15,
                        30,
                        45,
                        60,
                      ].contains(preferences.defaultDueDays)
                      ? preferences.defaultDueDays
                      : 7,
                  decoration: const InputDecoration(
                    labelText: 'Default due period',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Due immediately')),
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 14, child: Text('14 days')),
                    DropdownMenuItem(value: 15, child: Text('15 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days')),
                    DropdownMenuItem(value: 45, child: Text('45 days')),
                    DropdownMenuItem(value: 60, child: Text('60 days')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _preferences = preferences.copyWith(
                          defaultDueDays: value,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _statuses.contains(preferences.defaultStatus)
                      ? preferences.defaultStatus
                      : 'draft',
                  decoration: const InputDecoration(
                    labelText: 'Default status',
                  ),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_titleCase(status)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _preferences = preferences.copyWith(
                          defaultStatus: value,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Save new business details automatically'),
                subtitle: const Text(
                  'Business data entered on an invoice becomes reusable.',
                ),
                value: preferences.autoSaveBusinesses,
                onChanged: (value) => setState(() {
                  _preferences = preferences.copyWith(
                    autoSaveBusinesses: value,
                  );
                }),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Save new customers automatically'),
                subtitle: const Text(
                  'Customers entered on an invoice appear in the customer list.',
                ),
                value: preferences.autoSaveCustomers,
                onChanged: (value) => setState(() {
                  _preferences = preferences.copyWith(autoSaveCustomers: value);
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.backup_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Businesses, customers, defaults, logos and background images are included in the full app backup.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save defaults'),
        ),
      ],
    );
  }
}

class _BusinessEditorScreen extends ConsumerStatefulWidget {
  const _BusinessEditorScreen({required this.service, this.business});

  final InvoiceProfileService service;
  final InvoiceBusinessProfile? business;

  @override
  ConsumerState<_BusinessEditorScreen> createState() =>
      _BusinessEditorScreenState();
}

