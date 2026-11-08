part of '../InvoiceFormScreen.dart';

class _BusinessSelectionSheet extends StatefulWidget {
  const _BusinessSelectionSheet({
    required this.businesses,
    required this.selectedId,
  });

  final List<InvoiceBusinessProfile> businesses;
  final String? selectedId;

  @override
  State<_BusinessSelectionSheet> createState() =>
      _BusinessSelectionSheetState();
}

class _BusinessSelectionSheetState extends State<_BusinessSelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.businesses
        .where((business) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          return business.name.toLowerCase().contains(query) ||
              business.address.toLowerCase().contains(query) ||
              (business.email ?? '').toLowerCase().contains(query) ||
              (business.phone ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose business',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: widget.businesses.length > 6,
              decoration: const InputDecoration(
                hintText: 'Search saved businesses',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No saved business matches your search.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final business = filtered[index];
                      final selected = business.id == widget.selectedId;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(business.accentColorValue)
                                .withOpacity(.14),
                            child: Icon(
                              Icons.storefront,
                              color: Color(business.accentColorValue),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(business.name)),
                              if (business.isDefault)
                                const Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('Default'),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            [
                                  business.address,
                                  if (business.phone != null) business.phone!,
                                ]
                                .where((value) => value.trim().isNotEmpty)
                                .join('\n'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(business),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectionSheet extends StatefulWidget {
  const _CustomerSelectionSheet({
    required this.customers,
    required this.selectedId,
  });

  final List<InvoiceCustomerProfile> customers;
  final String? selectedId;

  @override
  State<_CustomerSelectionSheet> createState() =>
      _CustomerSelectionSheetState();
}

class _CustomerSelectionSheetState extends State<_CustomerSelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((customer) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          return customer.name.toLowerCase().contains(query) ||
              (customer.company ?? '').toLowerCase().contains(query) ||
              customer.address.toLowerCase().contains(query) ||
              (customer.email ?? '').toLowerCase().contains(query) ||
              (customer.phone ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose customer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: widget.customers.length > 6,
              decoration: const InputDecoration(
                hintText: 'Search name, company, phone or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No saved customer found.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      final selected = customer.id == widget.selectedId;
                      return Card(
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
                                ]
                                .where((value) => value.trim().isNotEmpty)
                                .join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(customer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
