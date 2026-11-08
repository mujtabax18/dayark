part of '../InvoiceDataManagementScreen.dart';

class _InvoiceDataManagementScreenState
    extends State<InvoiceDataManagementScreen> {
  late final InvoiceProfileService _service;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _service = InvoiceProfileService(DatabaseService());
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoice data'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Businesses', icon: Icon(Icons.storefront_outlined)),
              Tab(text: 'Customers', icon: Icon(Icons.people_outline)),
              Tab(text: 'Defaults', icon: Icon(Icons.tune_outlined)),
            ],
          ),
        ),
        body: DesktopContentFrame(
          child: TabBarView(
          children: [
            _BusinessesTab(
              key: ValueKey('businesses-$_refreshKey'),
              service: _service,
              onChanged: _refresh,
            ),
            _CustomersTab(
              key: ValueKey('customers-$_refreshKey'),
              service: _service,
              onChanged: _refresh,
            ),
            _PreferencesTab(
              key: ValueKey('preferences-$_refreshKey'),
              service: _service,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _BusinessesTab extends StatelessWidget {
  const _BusinessesTab({
    super.key,
    required this.service,
    required this.onChanged,
  });

  final InvoiceProfileService service;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvoiceBusinessProfile>>(
      future: service.getBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(message: snapshot.error.toString());
        }
        final businesses = snapshot.data ?? const [];
        return Scaffold(
          body: businesses.isEmpty
              ? const _EmptyView(
                  icon: Icons.storefront_outlined,
                  title: 'No saved businesses',
                  message: 'Add a business once, then reuse its branding and invoice defaults.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: _BusinessAvatar(business: business),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (business.isDefault)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('Default'),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            [
                                  business.address,
                                  if (business.phone != null) business.phone!,
                                  if (business.email != null) business.email!,
                                ]
                                .where((value) => value.trim().isNotEmpty)
                                .join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit') {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _BusinessEditorScreen(
                                    service: service,
                                    business: business,
                                  ),
                                ),
                              );
                              onChanged();
                            } else if (action == 'default') {
                              await service.setDefaultBusiness(business.id);
                              onChanged();
                            } else if (action == 'delete') {
                              final confirmed = await _confirmDelete(
                                context,
                                title: 'Delete business?',
                                message: 'Existing invoices keep their saved business snapshot. Future invoices will no longer show this profile.',
                              );
                              if (confirmed) {
                                await service.deleteBusiness(business.id);
                                onChanged();
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            if (!business.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Text('Make default'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _BusinessEditorScreen(
                                service: service,
                                business: business,
                              ),
                            ),
                          );
                          onChanged();
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _BusinessEditorScreen(service: service),
                ),
              );
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add business'),
          ),
        );
      },
    );
  }
}

class _CustomersTab extends StatefulWidget {
  const _CustomersTab({
    super.key,
    required this.service,
    required this.onChanged,
  });

  final InvoiceProfileService service;
  final VoidCallback onChanged;

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search name, company, phone or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InvoiceCustomerProfile>>(
              future: widget.service.getCustomers(query: _query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorView(message: snapshot.error.toString());
                }
                final customers = snapshot.data ?? const [];
                if (customers.isEmpty) {
                  return _EmptyView(
                    icon: Icons.people_outline,
                    title: _query.trim().isEmpty
                        ? 'No saved customers'
                        : 'No customers found',
                    message: _query.trim().isEmpty
                        ? 'Customers entered on invoices are saved automatically.'
                        : 'Try another search.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            customer.name.trim().isEmpty
                                ? '?'
                                : customer.name.trim()[0].toUpperCase(),
                          ),
                        ),
                        title: Text(customer.displayName),
                        subtitle: Text(
                          [
                            customer.address,
                            if (customer.phone != null) customer.phone!,
                            if (customer.email != null) customer.email!,
                            if (customer.usageCount > 0)
                              'Used ${customer.usageCount} time${customer.usageCount == 1 ? '' : 's'}',
                          ].where((value) => value.trim().isNotEmpty).join('\n'),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit') {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _CustomerEditorScreen(
                                    service: widget.service,
                                    customer: customer,
                                  ),
                                ),
                              );
                              widget.onChanged();
                            } else if (action == 'delete') {
                              final confirmed = await _confirmDelete(
                                context,
                                title: 'Delete customer?',
                                message: 'Existing invoices keep their saved customer snapshot.',
                              );
                              if (confirmed) {
                                await widget.service.deleteCustomer(
                                  customer.id,
                                );
                                widget.onChanged();
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _CustomerEditorScreen(
                                service: widget.service,
                                customer: customer,
                              ),
                            ),
                          );
                          widget.onChanged();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _CustomerEditorScreen(service: widget.service),
            ),
          );
          widget.onChanged();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add customer'),
      ),
    );
  }
}

class _PreferencesTab extends StatefulWidget {
  const _PreferencesTab({super.key, required this.service});

  final InvoiceProfileService service;

  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}

