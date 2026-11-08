import 'package:genealogy_chart/genealogy_chart.dart' as genealogy;

import '../models/family_tree_models.dart' as dayark;

/// Converts DayArk's persisted relations to genealogy_chart's view models.
/// This adapter never writes to the database or invents family members.
class FamilyChartSnapshot {
  FamilyChartSnapshot({
    required this.members,
    required this.memberByChartId,
    required this.hasSupplementaryLinks,
  });

  final List<genealogy.FamilyMember> members;
  final Map<String, dayark.FamilyMember> memberByChartId;

  /// Some relationships cannot be represented accurately by the package's
  /// family mode (such as guardian or sibling links with no recorded parent).
  /// The Classic canvas retains every original edge.
  final bool hasSupplementaryLinks;

  static FamilyChartSnapshot fromDayArk({
    required List<dayark.FamilyMember> people,
    required List<dayark.FamilyRelationship> relationships,
    required int? focusedMemberId,
  }) {
    if (people.isEmpty) {
      return FamilyChartSnapshot(
        members: const [],
        memberByChartId: const {},
        hasSupplementaryLinks: false,
      );
    }
    final byId = {for (final member in people) member.id: member};
    final ids = byId.keys.toSet();
    final parentsOf = <int, Set<int>>{};
    final spousesOf = <int, Set<int>>{};
    final childrenOf = <int, Set<int>>{};
    final siblings = <(int, int)>[];

    for (final relation in relationships) {
      final from = relation.fromMemberId;
      final to = relation.toMemberId;
      if (from == to || !ids.contains(from) || !ids.contains(to)) continue;
      switch (relation.type) {
        case 'parent':
          // DayArk stores parent -> child, never the reverse. Guardians
          // are not treated as biological parents in this projection.
          parentsOf.putIfAbsent(to, () => <int>{}).add(from);
          childrenOf.putIfAbsent(from, () => <int>{}).add(to);
          break;
        case 'spouse':
        case 'partner':
          spousesOf.putIfAbsent(from, () => <int>{}).add(to);
          spousesOf.putIfAbsent(to, () => <int>{}).add(from);
          break;
        case 'sibling':
          siblings.add((from, to));
          break;
      }
    }

    // Build indivisible marriage/partnership units. A sibling must never be
    // inserted between partners while calculating generation or display order.
    final leader = {for (final id in ids) id: id};
    int root(int id) {
      var current = id;
      while (leader[current] != current) {
        current = leader[current]!;
      }
      while (leader[id] != current) {
        final next = leader[id]!;
        leader[id] = current;
        id = next;
      }
      return current;
    }

    for (final pair in spousesOf.entries) {
      for (final partner in pair.value) {
        final left = root(pair.key);
        final right = root(partner);
        if (left != right) leader[right] = left;
      }
    }
    final groups = <int, List<int>>{};
    for (final member in people) {
      groups.putIfAbsent(root(member.id), () => []).add(member.id);
    }

    // Generations are constraints between whole partner units. Applying a
    // parent edge to one spouse cannot accidentally move them onto different
    // rows; the earliest consistent assignment wins if legacy data cycles.
    final adjacency = <int, List<(int, int)>>{};
    void link(int a, int b, int difference) {
      if (a == b) return;
      adjacency.putIfAbsent(a, () => []).add((b, difference));
      adjacency.putIfAbsent(b, () => []).add((a, -difference));
    }
    for (final entry in childrenOf.entries) {
      for (final child in entry.value) {
        link(root(entry.key), root(child), 1);
      }
    }
    for (final pair in siblings) {
      link(root(pair.$1), root(pair.$2), 0);
    }

    final generations = <int, int>{};
    final focus = focusedMemberId != null && ids.contains(focusedMemberId)
        ? focusedMemberId
        : people.first.id;
    final starts = <int>[
      root(focus),
      ...groups.keys.where((unit) => unit != root(focus)),
    ];
    for (final start in starts) {
      if (generations.containsKey(start)) continue;
      generations[start] = 0;
      final queue = <int>[start];
      for (var i = 0; i < queue.length; i++) {
        final current = queue[i];
        for (final edge in adjacency[current] ?? const <(int, int)>[]) {
          if (!generations.containsKey(edge.$1)) {
            generations[edge.$1] = generations[current]! + edge.$2;
            queue.add(edge.$1);
          }
        }
      }
    }

    // Place each household contiguously in the input list. The package's
    // family layout claims spouses in list order, so this is significant.
    final orderedIds = <int>[];
    final focusUnit = root(focus);
    final unitOrder = [
      focusUnit,
      ...groups.keys.where((unit) => unit != focusUnit),
    ];
    for (final unit in unitOrder) {
      final household = [...groups[unit]!];
      if (unit == focusUnit && household.remove(focus)) household.insert(0, focus);
      orderedIds.addAll(household);
    }

    final siblingWithoutCommonParent = siblings.any((pair) {
      final firstParents = parentsOf[pair.$1] ?? const <int>{};
      final secondParents = parentsOf[pair.$2] ?? const <int>{};
      return firstParents.intersection(secondParents).isEmpty;
    });
    final hasOtherConnections = relationships.any((link) =>
        link.type != 'parent' &&
        link.type != 'spouse' &&
        link.type != 'partner' &&
        link.type != 'sibling');

    final result = <genealogy.FamilyMember>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final member = byId[orderedIds[i]]!;
      final parentIds = (parentsOf[member.id] ?? const <int>{}).toList()..sort();
      final spouseIds = (spousesOf[member.id] ?? const <int>{}).toList()..sort();
      final childIds = (childrenOf[member.id] ?? const <int>{}).toList()..sort();
      result.add(genealogy.FamilyMember(
        id: member.id.toString(),
        name: member.fullName,
        firstName: member.firstName,
        lastName: member.lastName,
        // Do not use `avatar` here: the package's built-in nodes load URLs,
        // while DayArk stores local paths. Our custom chart node uses FileImage.
        status: member.deathDate == null
            ? genealogy.MemberStatus.offline
            : genealogy.MemberStatus.deceased,
        relationship: member.id == focus
            ? genealogy.FamilyRelationship.self
            : spousesOf[focus]?.contains(member.id) == true
                ? genealogy.FamilyRelationship.spouse
                : genealogy.FamilyRelationship.other,
        gender: switch (member.gender.toLowerCase()) {
          'male' => genealogy.Gender.male,
          'female' => genealogy.Gender.female,
          'other' => genealogy.Gender.other,
          _ => genealogy.Gender.unknown,
        },
        generation: generations[root(member.id)] ?? 0,
        position: i,
        parentIds: parentIds.map((id) => id.toString()).toList(),
        spouseIds: spouseIds.map((id) => id.toString()).toList(),
        childrenIds: childIds.map((id) => id.toString()).toList(),
        birthDate: member.birthDate,
        deathDate: member.deathDate,
        bio: member.description,
        location: member.address,
        metadata: {'dayarkMemberId': member.id},
      ));
    }
    return FamilyChartSnapshot(
      members: result,
      memberByChartId: {
        for (final member in people) member.id.toString(): member,
      },
      hasSupplementaryLinks: siblingWithoutCommonParent || hasOtherConnections,
    );
  }
}
