part of '../invoice_desktop_dashboard.dart';

enum _InvoiceDesktopSection {
  all,
  draft,
  outstanding,
  paid,
  data,
  detail,
  create,
  edit,
}

class _InvoiceDesktopDashboardState
    extends ConsumerState<InvoiceDesktopDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<String> _filter = ValueNotifier<String>('all');

  _InvoiceDesktopSection _section = _InvoiceDesktopSection.all;
  String? _selectedInvoiceId;
  int _navigationToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await ref.read(invoicesProvider.notifier).loadInvoices();
    if (!mounted) return;

    final editInvoice = widget.initialEditInvoice;
    if (editInvoice != null) {
      _openEdit(editInvoice, returnToDetail: false);
      return;
    }

    if (widget.openCreateOnStart) {
      _openCreate();
      return;
    }

    final invoiceId = widget.initialInvoiceId;
    if (invoiceId != null) {
      final invoice = ref.read(invoicesProvider.notifier).getById(invoiceId);
      if (invoice != null) {
        if (widget.openEditOnStart) {
          _openEdit(invoice, returnToDetail: false);
        } else {
          _openInvoice(invoice);
        }
      }
    }
  }

  void _returnToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _selectFilter(String filter, _InvoiceDesktopSection section) {
    _navigationToken++;
    _returnToRoot();
    _filter.value = filter;
    setState(() {
      _section = section;
      _selectedInvoiceId = null;
    });
  }

  void _openCreate() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    setState(() {
      _section = _InvoiceDesktopSection.create;
      _selectedInvoiceId = null;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/invoices-desktop/new'),
            builder: (_) => const InvoiceFormScreen(desktopEmbedded: true),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      _restoreFilterSection();
    });
  }

  void _openInvoice(Invoice invoice) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    _returnToRoot();
    setState(() {
      _section = _InvoiceDesktopSection.detail;
      _selectedInvoiceId = invoice.id;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/invoices-desktop/${invoice.id}'),
            builder: (_) => InvoiceViewScreen(
              id: invoice.id,
              desktopEmbedded: true,
              onEdit: (value) => _openEdit(value, returnToDetail: true),
            ),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      _restoreFilterSection();
    });
  }

  void _openEdit(Invoice invoice, {required bool returnToDetail}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    setState(() {
      _section = _InvoiceDesktopSection.edit;
      _selectedInvoiceId = invoice.id;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: '/invoices-desktop/${invoice.id}/edit',
            ),
            builder: (_) => InvoiceFormScreen(
              invoice: invoice,
              desktopEmbedded: true,
            ),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      if (returnToDetail && navigator.canPop()) {
        setState(() => _section = _InvoiceDesktopSection.detail);
      } else {
        _restoreFilterSection();
      }
    });
  }

  void _openDataManager() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    _returnToRoot();
    setState(() {
      _section = _InvoiceDesktopSection.data;
      _selectedInvoiceId = null;
    });
    navigator
        .push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/invoices-desktop/data'),
            builder: (_) => const InvoiceDataManagementScreen(),
          ),
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      _restoreFilterSection();
    });
  }

  void _restoreFilterSection() {
    final section = switch (_filter.value) {
      'draft' => _InvoiceDesktopSection.draft,
      'outstanding' => _InvoiceDesktopSection.outstanding,
      'paid' => _InvoiceDesktopSection.paid,
      _ => _InvoiceDesktopSection.all,
    };
    setState(() {
      _section = section;
      _selectedInvoiceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _InvoiceModuleSidebar(
            invoices: invoices,
            section: _section,
            selectedInvoiceId: _selectedInvoiceId,
            onAll: () => _selectFilter('all', _InvoiceDesktopSection.all),
            onDraft: () =>
                _selectFilter('draft', _InvoiceDesktopSection.draft),
            onOutstanding: () => _selectFilter(
              'outstanding',
              _InvoiceDesktopSection.outstanding,
            ),
            onPaid: () => _selectFilter('paid', _InvoiceDesktopSection.paid),
            onCreate: _openCreate,
            onData: _openDataManager,
            onInvoice: _openInvoice,
            onBackToDashboard: () {
              final desktopScope = DesktopNavigationScope.maybeOf(context);
              if (desktopScope != null) {
                desktopScope.onDashboard();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withOpacity(.72),
          ),
          Expanded(
            child: ClipRect(
              child: Navigator(
                key: _navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/invoices-desktop'),
                  builder: (_) => ValueListenableBuilder<String>(
                    valueListenable: _filter,
                    builder: (context, filter, __) => InvoiceListScreen(
                      key: ValueKey('invoice-list-$filter'),
                      desktopEmbedded: true,
                      filter: filter,
                      onCreateInvoice: _openCreate,
                      onOpenInvoice: _openInvoice,
                      onManageData: _openDataManager,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceModuleSidebar extends StatelessWidget {
  const _InvoiceModuleSidebar({
    required this.invoices,
    required this.section,
    required this.selectedInvoiceId,
    required this.onAll,
    required this.onDraft,
    required this.onOutstanding,
    required this.onPaid,
    required this.onCreate,
    required this.onData,
    required this.onInvoice,
    required this.onBackToDashboard,
  });

  final List<Invoice> invoices;
  final _InvoiceDesktopSection section;
  final String? selectedInvoiceId;
  final VoidCallback onAll;
  final VoidCallback onDraft;
  final VoidCallback onOutstanding;
  final VoidCallback onPaid;
  final VoidCallback onCreate;
  final VoidCallback onData;
  final ValueChanged<Invoice> onInvoice;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paid = invoices.where((invoice) => invoice.isPaid).length;
    final drafts = invoices
        .where((invoice) => !invoice.isPaid && invoice.status == 'draft')
        .length;
    final outstanding = invoices
        .where((invoice) => !invoice.isPaid && invoice.status != 'draft')
        .length;
    final recent = [...invoices]
      ..sort((a, b) => b.date.compareTo(a.date));

    return SizedBox(
      width: 278,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.invoice.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.invoice,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoices',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${invoices.length} saved invoices',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.invoice,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('New invoice'),
              ),
              const SizedBox(height: 18),
              const _SidebarLabel(text: 'WORKSPACE'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: Icons.receipt_long_outlined,
                label: 'All invoices',
                badge: '${invoices.length}',
                selected: section == _InvoiceDesktopSection.all,
                onTap: onAll,
              ),
              _SidebarItem(
                icon: Icons.edit_note_outlined,
                label: 'Drafts',
                badge: '$drafts',
                selected: section == _InvoiceDesktopSection.draft,
                onTap: onDraft,
              ),
              _SidebarItem(
                icon: Icons.schedule_outlined,
                label: 'Outstanding',
                badge: '$outstanding',
                selected: section == _InvoiceDesktopSection.outstanding,
                onTap: onOutstanding,
              ),
              _SidebarItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'Paid',
                badge: '$paid',
                selected: section == _InvoiceDesktopSection.paid,
                onTap: onPaid,
              ),
              _SidebarItem(
                icon: Icons.manage_accounts_outlined,
                label: 'Invoice data',
                selected: section == _InvoiceDesktopSection.data,
                onTap: onData,
              ),
              const SizedBox(height: 12),
              const _SidebarLabel(text: 'RECENT INVOICES'),
              const SizedBox(height: 5),
              Expanded(
                child: recent.isEmpty
                    ? Center(
                        child: Text(
                          'No invoices yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final invoice = recent[index];
                          return _RecentInvoiceItem(
                            invoice: invoice,
                            selected: selectedInvoiceId == invoice.id &&
                                (section == _InvoiceDesktopSection.detail ||
                                    section == _InvoiceDesktopSection.edit),
                            onTap: () => onInvoice(invoice),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Back to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
      ),
    );
  }
}

