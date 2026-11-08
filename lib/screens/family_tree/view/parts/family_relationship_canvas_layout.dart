part of '../family_relationship_canvas.dart';

/// Lays out people as *household units* rather than claiming a grid slot for
/// each person independently. A spouse/partner must never be separated from
/// their partner by a sibling, child, or any other member.
///
/// Parent links remain directional (parent above child), while siblings remain
/// on the same generation. Each person still has exactly one rendered node.
/// The layout does not modify or infer any stored family relationships.
class _FamilyLayout {
  _FamilyLayout(
    List<FamilyMember> members,
    List<FamilyRelationship> relationships,
    int focusId,
  ) {
    final memberIds = members.map((member) => member.id).toSet();

    // Build atomic horizontal units for couples. Unioning also keeps multiple
    // partners contiguous without duplicating anyone's card.
    final leaders = <int, int>{for (final id in memberIds) id: id};
    int root(int id) {
      var current = id;
      while (leaders[current] != current) {
        current = leaders[current]!;
      }
      while (leaders[id] != current) {
        final next = leaders[id]!;
        leaders[id] = current;
        id = next;
      }
      return current;
    }

    for (final relationship in relationships) {
      if (relationship.type != 'spouse' && relationship.type != 'partner') {
        continue;
      }
      final from = relationship.fromMemberId;
      final to = relationship.toMemberId;
      if (!memberIds.contains(from) || !memberIds.contains(to)) continue;
      final a = root(from);
      final b = root(to);
      if (a != b) {
        if (a < b) {
          leaders[b] = a;
        } else {
          leaders[a] = b;
        }
      }
    }

    final units = <int, List<int>>{};
    for (final member in members) {
      units.putIfAbsent(root(member.id), () => <int>[]).add(member.id);
    }
    final unitOf = <int, int>{};
    for (final entry in units.entries) {
      // The original member/ID order is stable even when the focused node
      // changes, so the couple doesn't unexpectedly flip left/right.
      entry.value.sort();
      for (final id in entry.value) {
        unitOf[id] = entry.key;
      }
    }

    final adjacency = <int, List<_FamilyUnitEdge>>{};
    for (final relationship in relationships) {
      final source = unitOf[relationship.fromMemberId];
      final target = unitOf[relationship.toMemberId];
      if (source == null || target == null || source == target) continue;
      final vertical = relationship.type == 'parent' ||
          relationship.type == 'guardian';
      final sibling = relationship.type == 'sibling';
      // Couples are already one unit. A sibling may be on either side, but
      // cannot enter a couple's reserved contiguous positions.
      final side = sibling ? -1 : vertical ? 0 : 1;
      final priority = vertical ? 0 : sibling ? 1 : 2;
      adjacency.putIfAbsent(source, () => <_FamilyUnitEdge>[]).add(
        _FamilyUnitEdge(target, vertical ? 1 : 0, side, priority),
      );
      adjacency.putIfAbsent(target, () => <_FamilyUnitEdge>[]).add(
        _FamilyUnitEdge(source, vertical ? -1 : 0, side, priority),
      );
    }
    for (final edges in adjacency.values) {
      edges.sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
      });
    }

    final focusUnit = unitOf[focusId] ?? units.keys.first;
    final slots = <int, (int, int)>{focusUnit: (0, 0)};
    final occupied = <String>{};
    void occupy(int row, int firstColumn, int count) {
      for (var offset = 0; offset < count; offset++) {
        occupied.add('$row:${firstColumn + offset}');
      }
    }
    occupy(0, 0, units[focusUnit]!.length);

    final pending = <int>[focusUnit];
    for (var i = 0; i < pending.length; i++) {
      final current = pending[i];
      final currentSlot = slots[current]!;
      final width = units[current]!.length;
      for (final edge in adjacency[current] ?? const <_FamilyUnitEdge>[]) {
        if (slots.containsKey(edge.id)) continue;
        final neighborWidth = units[edge.id]!.length;
        final row = currentSlot.$1 + edge.level;
        final desiredColumn = edge.level != 0
            // Align the *centers* of parent/child household units.
            ? currentSlot.$2 + ((width - neighborWidth) / 2).round()
            : edge.side < 0
                ? currentSlot.$2 - neighborWidth
                : currentSlot.$2 + width;
        final column = _openBlock(
          occupied, row, desiredColumn, neighborWidth, edge.side,
        );
        slots[edge.id] = (row, column);
        occupy(row, column, neighborWidth);
        pending.add(edge.id);
      }
    }

    // Preserve disconnected people as separate, visible groups below the tree.
    var orphanRow = slots.values.map((slot) => slot.$1).reduce(math.max) + 2;
    for (final entry in units.entries) {
      if (slots.containsKey(entry.key)) continue;
      final width = entry.value.length;
      final column = _openBlock(occupied, orphanRow, 0, width, 1);
      slots[entry.key] = (orphanRow, column);
      occupy(orphanRow, column, width);
      if (column >= 3) orphanRow++;
    }

    // Spouses sit closer together than separate sibling/household units.
    // Keep hit areas from touching: coupleGap > nodeWidth.
    final raw = <int, Offset>{};
    for (final entry in units.entries) {
      final slot = slots[entry.key]!;
      for (var i = 0; i < entry.value.length; i++) {
        raw[entry.value[i]] = Offset(
          slot.$2 * horizontalGap + i * coupleGap,
          slot.$1 * verticalGap,
        );
      }
    }
    final minX = raw.values.map((point) => point.dx).reduce(math.min);
    final maxX = raw.values.map((point) => point.dx).reduce(math.max);
    final minY = raw.values.map((point) => point.dy).reduce(math.min);
    final maxY = raw.values.map((point) => point.dy).reduce(math.max);
    width = math.max(430.0, maxX - minX + nodeWidth + 160);
    height = math.max(340.0, maxY - minY + nodeHeight + 150);
    for (final entry in raw.entries) {
      final topLeft = Offset(
        75 + entry.value.dx - minX,
        65 + entry.value.dy - minY,
      );
      positions[entry.key] = topLeft;
      cardCenters[entry.key] = topLeft + const Offset(98, 76);
    }
  }

  static const nodeWidth = 196.0;
  static const nodeHeight = 152.0;
  static const coupleGap = 206.0;
  static const horizontalGap = 238.0;
  static const verticalGap = 185.0;

  late final double width;
  late final double height;
  final positions = <int, Offset>{};
  final cardCenters = <int, Offset>{};

  static int _openBlock(
    Set<String> occupied,
    int row,
    int ideal,
    int width,
    int side,
  ) {
    bool available(int column) {
      for (var offset = 0; offset < width; offset++) {
        if (occupied.contains('$row:${column + offset}')) return false;
      }
      return true;
    }

    if (available(ideal)) return ideal;
    for (var distance = 1; distance < 10000; distance++) {
      final first = side < 0 ? ideal - distance : ideal + distance;
      final second = side < 0 ? ideal + distance : ideal - distance;
      if (available(first)) return first;
      if (available(second)) return second;
    }
    throw StateError('Unable to position family household.');
  }
}

class _FamilyUnitEdge {
  const _FamilyUnitEdge(this.id, this.level, this.side, this.priority);

  final int id;
  final int level;
  final int side;
  final int priority;
}
