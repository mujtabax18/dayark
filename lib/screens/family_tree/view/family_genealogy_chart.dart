import 'dart:io';

import 'package:flutter/material.dart';
import 'package:genealogy_chart/genealogy_chart.dart' as genealogy;

import '../models/family_tree_models.dart' as dayark;
import '../services/family_chart_adapter.dart';

/// The default full-viewport, pinch-to-zoom genealogy view. All mutations still
/// go through the existing DayArk sheets/repository; the chart is view-only.
class FamilyGenealogyChart extends StatefulWidget {
  const FamilyGenealogyChart({
    super.key,
    required this.members,
    required this.relationships,
    required this.focusedMemberId,
    required this.onFocus,
    required this.onDetails,
    required this.onAddRelative,
  });

  final List<dayark.FamilyMember> members;
  final List<dayark.FamilyRelationship> relationships;
  final int? focusedMemberId;
  final ValueChanged<int> onFocus;
  final ValueChanged<dayark.FamilyMember> onDetails;
  final void Function(dayark.FamilyMember, String) onAddRelative;

  @override
  State<FamilyGenealogyChart> createState() => _FamilyGenealogyChartState();
}

class _FamilyGenealogyChartState extends State<FamilyGenealogyChart> {
  final genealogy.GenealogyChartController<genealogy.FamilyMember> _controller =
      genealogy.GenealogyChartController<genealogy.FamilyMember>();

  late FamilyChartSnapshot _snapshot;
  Map<String, Offset> _positions = const {};
  Map<String, Size> _nodeSizes = const {};
  Size _viewport = Size.zero;
  int _layoutRevision = 0;
  bool _compact = false;
  bool _didInitialFit = false;
  int? _selectedId;

  genealogy.FamilyTreeLayout get _layout => genealogy.FamilyTreeLayout(
        generationHeight: _compact ? 138 : 205,
        siblingSpacing: _compact ? 34 : 42,
        spouseSpacing: _compact ? 17 : 22,
        branchSpacing: _compact ? 68 : 95,
        compactGenerations: true,
        maxDepth: null,
      );

  @override
  void initState() {
    super.initState();
    _selectedId = widget.focusedMemberId;
    _rebuildSnapshot();
  }

  @override
  void didUpdateWidget(covariant FamilyGenealogyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.members, widget.members) ||
        !identical(oldWidget.relationships, widget.relationships)) {
      _rebuildSnapshot();
    } else if (oldWidget.focusedMemberId != widget.focusedMemberId) {
      _selectedId = widget.focusedMemberId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedId != null) _focusOn(_selectedId!);
      });
    }
  }

  void _rebuildSnapshot() {
    _snapshot = FamilyChartSnapshot.fromDayArk(
      people: widget.members,
      relationships: widget.relationships,
      focusedMemberId: widget.focusedMemberId,
    );
    _calculatePositions();
  }

  Future<void> _calculatePositions() async {
    final revision = ++_layoutRevision;
    final size = _compact ? const Size(60, 60) : const Size(160, 140);
    final members = _snapshot.members;
    final positions = await _layout.calculateLayout(
      [for (final member in members)
        genealogy.GraphNode<genealogy.FamilyMember>(
          id: member.id,
          data: member,
          size: size,
        ),
      ],
      [
        for (final member in members)
          for (final parent in member.parentIds)
            genealogy.GraphEdge(
              sourceId: parent,
              targetId: member.id,
              type: genealogy.EdgeType.parentChild,
            ),
      ],
      const Size(2000, 2000),
    );
    if (!mounted || revision != _layoutRevision) return;
    setState(() {
      _positions = positions;
      _nodeSizes = {for (final member in members) member.id: size};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _layoutRevision || _viewport == Size.zero) return;
      if (!_didInitialFit) {
        _didInitialFit = true;
        _fitAll();
      } else if (_selectedId != null) {
        _focusOn(_selectedId!);
      }
    });
  }

  void _fitAll() {
    if (_viewport == Size.zero || _positions.isEmpty) return;
    _controller.zoomToFit(
      _positions,
      _nodeSizes,
      _viewport,
      padding: const EdgeInsets.all(24),
    );
  }

  void _focusOn(int id) {
    if (_viewport == Size.zero || !_positions.containsKey('$id')) return;
    _controller.panToNode('$id', _positions, _nodeSizes,
        viewportSize: _viewport, animate: true);
    _controller.selectNode('$id');
  }

  void _zoom(double factor) {
    final scale = (_controller.scale * factor).clamp(0.08, 3.0).toDouble();
    _controller.zoomTo(scale,
      focalPoint: Offset(_viewport.width / 2, _viewport.height / 2));
  }

  void _select(dayark.FamilyMember member) {
    setState(() => _selectedId = member.id);
    _controller.selectNode('${member.id}');
    widget.onFocus(member.id);
  }

  void _showActions(dayark.FamilyMember member) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(member.fullName,
                style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text('Choose an action'),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined), title: const Text('Person, photos & albums'),
              onTap: () { Navigator.pop(sheetContext); widget.onDetails(member); },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded), title: const Text('Add parent'),
              onTap: () { Navigator.pop(sheetContext); widget.onAddRelative(member, 'parent'); },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded), title: const Text('Add child'),
              onTap: () { Navigator.pop(sheetContext); widget.onAddRelative(member, 'child'); },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded), title: const Text('Add sibling'),
              onTap: () { Navigator.pop(sheetContext); widget.onAddRelative(member, 'sibling'); },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded), title: const Text('Add spouse / partner'),
              onTap: () { Navigator.pop(sheetContext); widget.onAddRelative(member, 'spouse'); },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _layoutRevision++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _snapshot.memberByChartId['${_selectedId ?? widget.focusedMemberId}'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
        child: Row(children: [
          Expanded(child: Text('Drag to explore · Pinch to zoom',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall)),
          IconButton(
            tooltip: _compact ? 'Show photo cards' : 'Compact nodes',
            icon: Icon(_compact ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            onPressed: () {
              setState(() { _compact = !_compact; _didInitialFit = false; });
              _calculatePositions();
            },
          ),
          IconButton(tooltip: 'Zoom out',
            icon: const Icon(Icons.remove_rounded), onPressed: () => _zoom(.80)),
          IconButton(tooltip: 'Zoom in',
            icon: const Icon(Icons.add_rounded), onPressed: () => _zoom(1.25)),
          IconButton(tooltip: 'Fit whole family',
            icon: const Icon(Icons.fit_screen_outlined), onPressed: _fitAll),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: SizedBox(
          height: 45,
          child: genealogy.ChartSearchBar(
            controller: _controller,
            members: _snapshot.members,
            positions: _positions,
            nodeSizes: _nodeSizes,
            viewportSize: _viewport,
            hintText: 'Find someone in this family',
            onResultSelected: (result) {
              final member = _snapshot.memberByChartId[result.id];
              if (member == null) return;
              _select(member);
              _focusOn(member.id);
            },
          ),
        ),
      ),
      if (_snapshot.hasSupplementaryLinks)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Some sibling, guardian or extended links are shown in Classic view.',
            maxLines: 2, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall),
        ),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final nextViewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (nextViewport != _viewport) {
          _viewport = nextViewport;
          if (_positions.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitAll();
            });
          }
        }
        return ClipRect(child: genealogy.GenealogyChart<genealogy.FamilyMember>.family(
          // The Key forces layout recalculation when card/compact sizes change.
          key: ValueKey('${_compact}_${widget.members.length}_${widget.relationships.length}'),
          members: _snapshot.members,
          rootMemberId: widget.focusedMemberId?.toString(),
          familyController: _controller,
          familyNodeStyle: _compact
              ? genealogy.FamilyNodeStyle.compact
              : genealogy.FamilyNodeStyle.card,
          layout: _layout,
          theme: isDark ? genealogy.GenealogyChartTheme.dark
              : genealogy.GenealogyChartTheme.light,
          enablePan: true,
          enableZoom: true,
          enableDoubleTapZoom: true,
          enableDragDrop: false, // DB must stay authoritative (no unsaved edits).
          enableCollapse: false,
          enableSearch: true,
          minScale: .08,
          maxScale: 3,
          familyNodeBuilder: (context, chartMember, state) {
            final member = _snapshot.memberByChartId[chartMember.id]!;
            return _DayArkChartCard(
              member: member,
              compact: _compact,
              selected: state.isSelected || state.isHighlighted ||
                  member.id == _selectedId,
              onTap: () => _select(member),
              onLongPress: () => _showActions(member),
            );
          },
        ));
      })),
      if (selected != null)
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Expanded(child: Text(selected.fullName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => _showActions(selected),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Relatives'),
            ),
            TextButton.icon(
              onPressed: () => widget.onDetails(selected),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('Details'),
            ),
          ]),
        ),
    ]);
  }
}

class _DayArkChartCard extends StatelessWidget {
  const _DayArkChartCard({
    required this.member,
    required this.compact,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final dayark.FamilyMember member;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imagePath = member.profileImagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    Widget avatar(double radius) => CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: hasImage ? FileImage(File(imagePath!)) : null,
      onForegroundImageError: hasImage ? (_, __) {} : null,
      child: Text(member.firstName.isEmpty ? '?' : member.firstName[0].toUpperCase(),
        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
    );

    if (compact) {
      return Tooltip(
        message: member.fullName,
        child: GestureDetector(
          onTap: onTap, onLongPress: onLongPress,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 1),
            ),
            padding: const EdgeInsets.all(3),
            child: avatar(24),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress,
      child: Container(
        width: 160, height: 140,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1),
          boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .10),
            blurRadius: 9, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          avatar(23),
          const SizedBox(height: 7),
          Text(member.fullName, textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
          const SizedBox(height: 3),
          Text(member.deathDate != null
              ? '${member.birthDate?.year ?? '?'} – ${member.deathDate!.year}'
              : '${member.birthDate?.year ?? ''}${member.imagePaths.length > 1 ? '  ·  ${member.imagePaths.length} photos' : ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
