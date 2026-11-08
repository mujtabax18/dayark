part of '../family_relationship_canvas.dart';

class _FamilyRelationshipCanvasState extends State<FamilyRelationshipCanvas> {
  final TransformationController _transformation = TransformationController();
  late _FamilyLayout _lastLayout;
  Size _viewport = Size.zero;
  String? _lastCameraKey;
  late bool _threeDimensional = widget.initial3D;

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      _lastLayout = _FamilyLayout(widget.members, widget.relationships, _focusId);
    }
  }

  @override
  void didUpdateWidget(covariant FamilyRelationshipCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.members.isNotEmpty &&
        (!identical(widget.members, oldWidget.members) ||
         !identical(widget.relationships, oldWidget.relationships) ||
         widget.focusedMemberId != oldWidget.focusedMemberId ||
         oldWidget.members.isEmpty)) {
      // Graph layout is expensive: never recompute for unrelated UI rebuilds
      // such as loading indicators, navigation, or theme updates.
      _lastLayout = _FamilyLayout(widget.members, widget.relationships, _focusId);
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  int get _focusId {
    final desired = widget.focusedMemberId;
    if (desired != null && widget.members.any((person) => person.id == desired)) {
      return desired;
    }
    return widget.members.first.id;
  }

  void _centerOnFocus({bool force = false}) {
    if (_viewport == Size.zero || widget.members.isEmpty) return;
    final layout = _lastLayout;
    final center = layout.cardCenters[_focusId];
    if (center == null) return;
    final key = '${_focusId}_${widget.members.length}_${widget.relationships.length}_'
        '${_viewport.width.toInt()}_${_viewport.height.toInt()}';
    if (!force && key == _lastCameraKey) return;
    _lastCameraKey = key;
    final scale = math.min(.94,
        math.max(.40, _viewport.width / (_FamilyLayout.nodeWidth * 2.25)));
    _setCamera(center: center, scale: scale);
  }

  void _setCamera({required Offset center, required double scale}) {
    if (_viewport == Size.zero) return;
    _transformation.value = Matrix4.identity()
      ..translate(_viewport.width / 2 - center.dx * scale,
          _viewport.height / 2 - center.dy * scale)
      ..scale(scale);
  }

  void _fitTree() {
    if (_viewport == Size.zero) return;
    final layout = _lastLayout;
    // Show the entire family graph, including connections and card padding.
    final scale = math.min(_viewport.width / layout.width,
        _viewport.height / layout.height).clamp(.12, 1.4).toDouble();
    _setCamera(center: Offset(layout.width / 2, layout.height / 2), scale: scale);
    _lastCameraKey = '${_focusId}_${widget.members.length}_${widget.relationships.length}_'
        '${_viewport.width.toInt()}_${_viewport.height.toInt()}';
  }

  void _zoom(double factor) {
    if (_viewport == Size.zero) return;
    final matrix = _transformation.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(.12, 3.5).toDouble();
    final change = nextScale / currentScale;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    _transformation.value = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(change)
      ..translate(-center.dx, -center.dy)
      ..multiply(matrix);
  }

  void _pan(Offset delta) {
    final matrix = _transformation.value.clone();
    _transformation.value = Matrix4.identity()
      ..translate(delta.dx, delta.dy)
      ..multiply(matrix);
  }

  void _openFullscreen() {
    var selectedId = _focusId;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StatefulBuilder(
        builder: (context, setFullscreenState) => Scaffold(
          appBar: AppBar(title: const Text('Family tree · Explore')),
          body: SafeArea(child: FamilyRelationshipCanvas(
            members: widget.members,
            relationships: widget.relationships,
            focusedMemberId: selectedId,
            fullscreen: true,
            initial3D: _threeDimensional,
            onFocus: (id) {
              setFullscreenState(() => selectedId = id);
              widget.onFocus(id);
            },
            onDetails: (person) {
              Navigator.of(context).pop();
              widget.onDetails(person);
            },
            onAddRelative: (person, role) {
              Navigator.of(context).pop();
              widget.onAddRelative(person, role);
            },
          )),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) return const SizedBox.shrink();
    final focusId = _focusId;
    final layout = _lastLayout;
    final theme = Theme.of(context);
    final controls = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ChoiceChip(label: const Text('2D'), selected: !_threeDimensional,
            onSelected: (_) => setState(() => _threeDimensional = false)),
        const SizedBox(width: 6),
        ChoiceChip(label: const Text('3D'), selected: _threeDimensional,
            tooltip: 'Perspective cards and depth-styled connections',
            onSelected: (_) => setState(() => _threeDimensional = true)),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.remove_rounded),
            onPressed: () => _zoom(.8)),
        IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.add_rounded),
            onPressed: () => _zoom(1.25)),
        IconButton(tooltip: 'Show whole family', icon: const Icon(Icons.fit_screen_outlined),
            onPressed: _fitTree),
        IconButton(tooltip: 'Center selected person',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: () => _centerOnFocus(force: true)),
        if (!widget.fullscreen)
          IconButton(tooltip: 'Open full-screen family tree',
              icon: const Icon(Icons.fullscreen_rounded), onPressed: _openFullscreen),
        PopupMenuButton<String>(
          tooltip: 'Move tree',
          icon: const Icon(Icons.pan_tool_alt_outlined),
          onSelected: (direction) {
            switch (direction) {
              case 'left': _pan(const Offset(-130, 0)); break;
              case 'right': _pan(const Offset(130, 0)); break;
              case 'up': _pan(const Offset(0, -130)); break;
              case 'down': _pan(const Offset(0, 130)); break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'up', child: Text('Move up')),
            PopupMenuItem(value: 'down', child: Text('Move down')),
            PopupMenuItem(value: 'left', child: Text('Move left')),
            PopupMenuItem(value: 'right', child: Text('Move right')),
          ],
        ),
      ]),
    );

    final viewer = LayoutBuilder(builder: (context, constraints) {
      _viewport = Size(constraints.maxWidth, constraints.maxHeight);
      final cameraKey = '${_focusId}_${widget.members.length}_'
          '${widget.relationships.length}_${_viewport.width.toInt()}_'
          '${_viewport.height.toInt()}';
      if (cameraKey != _lastCameraKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _centerOnFocus();
        });
      }
      return ClipRRect(
        borderRadius: widget.fullscreen ? BorderRadius.zero : AppRadius.medium,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerLowest,
          child: InteractiveViewer(
            transformationController: _transformation,
            boundaryMargin: const EdgeInsets.all(900),
            constrained: false,
            panEnabled: true,
            scaleEnabled: true,
            trackpadScrollCausesScale: false,
            minScale: .12,
            maxScale: 3.5,
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(children: [
                Positioned.fill(child: RepaintBoundary(child: IgnorePointer(
                  child: CustomPaint(painter: _FamilyEdgesPainter(
                    centers: layout.cardCenters,
                    relationships: widget.relationships,
                    background: theme.colorScheme.outlineVariant,
                    depthMode: _threeDimensional,
                  )),
                ))),
                ...widget.members.map((person) {
                  final position = layout.positions[person.id]!;
                  return Positioned(
                    left: position.dx, top: position.dy,
                    child: _FamilyNode(
                      person: person,
                      selected: person.id == focusId,
                      depthMode: _threeDimensional,
                      onFocus: () => widget.onFocus(person.id),
                      onDetails: () => widget.onDetails(person),
                      onAdd: (role) => widget.onAddRelative(person, role),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ),
      );
    });

    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Align(alignment: Alignment.centerLeft, child: Text(
          'Drag to move · Pinch or scroll to zoom · Tap a person to focus',
          style: theme.textTheme.bodySmall,
        )),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: controls),
      const SizedBox(height: 6),
      if (widget.fullscreen) Expanded(child: viewer)
      else SizedBox(
        height: (MediaQuery.sizeOf(context).height * .57).clamp(340.0, 640.0),
        child: viewer,
      ),
      if (!widget.fullscreen) ...[
        const SizedBox(height: 8),
        const _RelationshipLegend(),
      ],
      const SizedBox(height: 5),
      Text('Parents ↑  ·  Children ↓  ·  Siblings ←  ·  Partners →',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 5),
    ]);
  }
}

class _FamilyNode extends StatelessWidget {
  const _FamilyNode({
    required this.person,
    required this.selected,
    required this.depthMode,
    required this.onFocus,
    required this.onDetails,
    required this.onAdd,
  });

  final FamilyMember person;
  final bool selected;
  final bool depthMode;
  final VoidCallback onFocus;
  final VoidCallback onDetails;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = person.profileImagePath != null &&
        person.profileImagePath!.isNotEmpty;
    return SizedBox(
      width: _FamilyLayout.nodeWidth,
      height: _FamilyLayout.nodeHeight,
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          left: 24, top: 23,
          width: 148, height: 106,
          child: Transform(
            alignment: Alignment.center,
            transform: depthMode
                ? (Matrix4.identity()
                    ..setEntry(3, 2, .0009)
                    ..rotateY(-.10)
                    ..rotateX(.065))
                : Matrix4.identity(),
            child: Material(
              color: selected ? scheme.primaryContainer : scheme.surface,
              elevation: selected ? (depthMode ? 13 : 4) : (depthMode ? 8 : 2),
              shadowColor: depthMode ? scheme.primary.withValues(alpha: .35) : null,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onFocus,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircleAvatar(radius: 19,
                        child: hasImage
                            ? ClipOval(child: Image.file(
                                File(person.profileImagePath!), width: 38, height: 38,
                                fit: BoxFit.cover, cacheWidth: 120,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.person_outline_rounded, size: 22),
                              ))
                            : const Icon(Icons.person_outline_rounded, size: 22)),
                      const SizedBox(height: 3),
                      Text(person.fullName,
                        textAlign: TextAlign.center, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.4, height: 1.08,
                          fontWeight: FontWeight.w800,
                          color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
                      if (person.birthDate != null)
                        Text('${person.birthDate!.year}',
                          style: TextStyle(fontSize: 9.5,
                            color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 0, left: 81, child: _RelationPort(
          tooltip: 'Add a parent to ${person.fullName}',
          color: _RelationColors.parent,
          icon: Icons.keyboard_arrow_up_rounded,
          onPressed: () => onAdd('parent'),
        )),
        Positioned(bottom: 0, left: 81, child: _RelationPort(
          tooltip: 'Add a child to ${person.fullName}',
          color: _RelationColors.parent,
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: () => onAdd('child'),
        )),
        Positioned(left: 0, top: 60, child: _RelationPort(
          tooltip: 'Add a sibling to ${person.fullName}',
          color: _RelationColors.sibling,
          icon: Icons.keyboard_arrow_left_rounded,
          onPressed: () => onAdd('sibling'),
        )),
        Positioned(right: 0, top: 60, child: _RelationPort(
          tooltip: 'Add a spouse to ${person.fullName}',
          color: _RelationColors.spouse,
          icon: Icons.keyboard_arrow_right_rounded,
          onPressed: () => onAdd('spouse'),
        )),
        Positioned(right: 10, top: 16, child: Material(
          color: scheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: onDetails,
            child: const SizedBox.square(dimension: 26,
              child: Icon(Icons.info_outline_rounded, size: 15))),
        )),
      ]),
    );
  }

}

class _RelationPort extends StatelessWidget {
  const _RelationPort({required this.tooltip, required this.color,
    required this.icon, required this.onPressed});
  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(dimension: 34,
          child: Icon(icon, size: 24, color: Colors.white)),
      ),
    ),
  );
}

class _RelationColors {
  static const parent = Color(0xFF16856B);
  static const spouse = Color(0xFFDC5381);
  static const sibling = Color(0xFF5167C8);
  static const partner = Color(0xFF8D5DC1);
  static const guardian = Color(0xFFC28A28);
  static const other = Color(0xFF73808A);

  static Color of(String type) {
    switch (type) {
      case 'parent': return parent;
      case 'spouse': return spouse;
      case 'sibling': return sibling;
      case 'partner': return partner;
      case 'guardian': return guardian;
      default: return other;
    }
  }
}

class _RelationshipLegend extends StatelessWidget {
  const _RelationshipLegend();

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center, spacing: 14, runSpacing: 6,
    children: const [
      _LegendItem('Parent / child', _RelationColors.parent),
      _LegendItem('Spouse', _RelationColors.spouse),
      _LegendItem('Sibling', _RelationColors.sibling),
      _LegendItem('Partner', _RelationColors.partner),
      _LegendItem('Guardian', _RelationColors.guardian),
      _LegendItem('Other', _RelationColors.other),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 4, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
}

