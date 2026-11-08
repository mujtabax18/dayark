part of '../AddGroceryItemWidget.dart';

class ExistingGroceryItemsSheet extends ConsumerStatefulWidget {
  const ExistingGroceryItemsSheet({
    super.key,
    required this.groceryId,
  });

  final int groceryId;

  @override
  ConsumerState<ExistingGroceryItemsSheet> createState() =>
      _ExistingGroceryItemsSheetState();
}

class _ExistingGroceryItemsSheetState
    extends ConsumerState<ExistingGroceryItemsSheet> {
  final _searchController = TextEditingController();
  final Set<int> _selectedIds = <int>{};
  String _selectedType = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredItems(
    List<Map<String, dynamic>> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final type = item['item_type']?.toString() ?? 'general';
      if (_selectedType != 'all' && type != _selectedType) return false;
      if (query.isEmpty) return true;

      final searchable = <String>[
        item['name']?.toString() ?? '',
        item['notes']?.toString() ?? '',
        item['source_plan_title']?.toString() ?? '',
        type,
        item['unit']?.toString() ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  void _toggleAll(List<Map<String, dynamic>> visibleItems) {
    final selectableIds = visibleItems
        .where((item) => !GroceryCatalog.boolFrom(item['already_in_plan']))
        .map((item) => (item['source_item_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    if (selectableIds.isEmpty) return;

    final allSelected = selectableIds.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(selectableIds);
      } else {
        _selectedIds.addAll(selectableIds);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      final added = await ref.read(dbServiceProvider).addExistingGroceryItemsToPlan(
            groceryId: widget.groceryId,
            sourceItemIds: _selectedIds.toList(),
          );
      refreshGroceryDashboard(ref, groceryId: widget.groceryId);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 1
                ? '1 existing item added as a new pending item.'
                : '$added existing items added as new pending items.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not add the selected items.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Theme.of(context).colorScheme.primary;
    final reusableAsync = ref.watch(
      reusableGroceryItemsProvider(widget.groceryId),
    );

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        color: neutral.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: neutral.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: CenteredFaIcon(
                        FontAwesomeIcons.listCheck,
                        size: 17,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add existing items',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Choose items used in previous grocery plans.',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: neutral.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.14)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CenteredFaIcon(
                      FontAwesomeIcons.circleInfo,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Only name, type, quantity, unit, notes and priority are copied. History, completion state, due dates and alerts are not copied.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search previous items or plans',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: CenteredFaIcon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: neutral.textSecondary,
                    ),
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.close, color: neutral.textSecondary),
                        ),
                  filled: true,
                  fillColor: neutral.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: neutral.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: neutral.divider),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: reusableAsync.when(
                data: (items) => _buildItems(context, items),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => _ExistingItemsError(
                  onRetry: () => ref.invalidate(
                    reusableGroceryItemsProvider(widget.groceryId),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: neutral.card,
                border: Border(top: BorderSide(color: neutral.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedIds.isEmpty
                            ? 'Select items to add'
                            : '${_selectedIds.length} selected',
                        style: TextStyle(
                          color: _selectedIds.isEmpty
                              ? neutral.textSecondary
                              : neutral.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _selectedIds.isEmpty || _saving ? null : _addSelected,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const CenteredFaIcon(FontAwesomeIcons.plus, size: 13),
                      label: Text(
                        _saving ? 'Adding...' : 'Add to plan',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(142, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final neutral = context.themeColors.neutral;
    if (items.isEmpty) {
      return _NoReusableItems(
        onCreateNew: () {
          final navigatorContext =
              Navigator.of(context, rootNavigator: true).context;
          Navigator.pop(context);
          Future<void>.delayed(Duration.zero, () {
            showGroceryItemEditor(
              navigatorContext,
              ref,
              groceryId: widget.groceryId,
            );
          });
        },
      );
    }

    final types = items
        .map((item) => item['item_type']?.toString() ?? 'general')
        .toSet()
        .toList()
      ..sort();
    final filtered = _filteredItems(items);
    final selectableVisible = filtered
        .where((item) => !GroceryCatalog.boolFrom(item['already_in_plan']))
        .map((item) => (item['source_item_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final allVisibleSelected = selectableVisible.isNotEmpty &&
        selectableVisible.every(_selectedIds.contains);

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: types.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final value = index == 0 ? 'all' : types[index - 1];
              final selected = value == _selectedType;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => setState(() => _selectedType = value),
                label: Text(
                  value == 'all'
                      ? 'All'
                      : _reusableCapitalize(value),
                ),
                labelStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : neutral.textSecondary,
                ),
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: neutral.card,
                side: BorderSide(color: neutral.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} reusable ${filtered.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: selectableVisible.isEmpty
                    ? null
                    : () => _toggleAll(filtered),
                icon: CenteredFaIcon(
                  allVisibleSelected
                      ? FontAwesomeIcons.minus
                      : FontAwesomeIcons.check,
                  size: 13,
                ),
                label: Text(allVisibleSelected ? 'Clear visible' : 'Select visible'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _NoExistingSearchResults()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final sourceId =
                        (item['source_item_id'] as num?)?.toInt();
                    final alreadyAdded =
                        GroceryCatalog.boolFrom(item['already_in_plan']);
                    final selected =
                        sourceId != null && _selectedIds.contains(sourceId);

                    return _ReusableItemTile(
                      item: item,
                      selected: selected,
                      alreadyAdded: alreadyAdded,
                      onTap: sourceId == null || alreadyAdded
                          ? null
                          : () => setState(() {
                                if (!_selectedIds.add(sourceId)) {
                                  _selectedIds.remove(sourceId);
                                }
                              }),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReusableItemTile extends StatelessWidget {
  const _ReusableItemTile({
    required this.item,
    required this.selected,
    required this.alreadyAdded,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final bool selected;
  final bool alreadyAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Theme.of(context).colorScheme.primary;
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
    final unit = item['unit']?.toString() ?? 'item';
    final type = item['item_type']?.toString() ?? 'general';
    final planTitle = item['source_plan_title']?.toString().trim() ?? '';
    final notes = item['notes']?.toString().trim() ?? '';

    return Material(
      color: alreadyAdded
          ? neutral.card.withOpacity(0.65)
          : selected
              ? accent.withOpacity(0.07)
              : neutral.card,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? accent.withOpacity(0.45) : neutral.divider,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: CenteredFaIcon(
                    _reusableItemTypeIcon(type),
                    size: 15,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? 'Grocery item',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: alreadyAdded
                                  ? neutral.textDisabled
                                  : neutral.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (alreadyAdded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'In plan',
                              style: TextStyle(
                                color: accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 9,
                      runSpacing: 5,
                      children: [
                        _ReusableMeta(
                          icon: FontAwesomeIcons.scaleBalanced,
                          text: '${_reusableFormatQuantity(quantity)} $unit',
                        ),
                        _ReusableMeta(
                          icon: FontAwesomeIcons.tags,
                          text: _reusableCapitalize(type),
                        ),
                        if (planTitle.isNotEmpty)
                          _ReusableMeta(
                            icon: FontAwesomeIcons.layerGroup,
                            text: planTitle,
                          ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: alreadyAdded ? true : selected,
                onChanged: onTap == null ? null : (_) => onTap!(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReusableMeta extends StatelessWidget {
  const _ReusableMeta({required this.icon, required this.text});

  final FaIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenteredFaIcon(icon, size: 8, color: neutral.textSecondary),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoReusableItems extends StatelessWidget {
  const _NoReusableItems({required this.onCreateNew});

  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CenteredFaIcon(
              FontAwesomeIcons.boxOpen,
              size: 34,
              color: neutral.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              'No previous items yet',
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Create a new grocery item first. It will become reusable in your future plans.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreateNew,
              icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 13),
              label: const Text('Create new item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoExistingSearchResults extends StatelessWidget {
  const _NoExistingSearchResults();

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CenteredFaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 28,
              color: neutral.textDisabled,
            ),
            const SizedBox(height: 10),
            Text(
              'No matching reusable items',
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingItemsError extends StatelessWidget {
  const _ExistingItemsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CenteredFaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 28,
              color: neutral.textDisabled,
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load previous grocery items.',
              style: TextStyle(color: neutral.textSecondary),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

FaIconData _reusableItemTypeIcon(String? type) {
  switch (type) {
    case 'food':
      return FontAwesomeIcons.utensils;
    case 'fruit_veg':
      return FontAwesomeIcons.carrot;
    case 'dairy':
      return FontAwesomeIcons.bottleWater;
    case 'meat':
      return FontAwesomeIcons.drumstickBite;
    case 'bakery':
      return FontAwesomeIcons.breadSlice;
    case 'drinks':
      return FontAwesomeIcons.bottleWater;
    case 'cleaning':
      return FontAwesomeIcons.soap;
    case 'personal_care':
      return FontAwesomeIcons.soap;
    case 'household':
      return FontAwesomeIcons.house;
    default:
      return FontAwesomeIcons.basketShopping;
  }
}

String _reusableCapitalize(String value) {
  if (value.isEmpty) return value;
  final normalized = value.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _reusableFormatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
