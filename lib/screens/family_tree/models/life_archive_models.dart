/// Social and life-event records are distinct from genealogy relationships.
/// This preserves existing family data and keeps multi-type connections safe.
class LifeConnection {
  const LifeConnection({required this.id, required this.treeId,
    required this.fromMemberId, required this.toMemberId, required this.type,
    required this.label, required this.notes, this.startedAt, this.endedAt});
  final int id, treeId, fromMemberId, toMemberId;
  final String type, label, notes;
  final DateTime? startedAt, endedAt;

  static const types = <String, String>{
    'friend': 'Friend', 'best_friend': 'Best friend',
    'childhood_friend': 'Childhood friend', 'family_friend': 'Family friend',
    'colleague': 'Colleague', 'mentor': 'Mentor', 'manager': 'Manager',
    'business_partner': 'Business partner', 'classmate': 'Classmate',
    'teacher': 'Teacher', 'neighbor': 'Neighbor',
    'romantic_partner': 'Romantic partner', 'former_partner': 'Former partner',
    'custom': 'Custom connection',
  };
  static const directedTypes = {'mentor', 'manager', 'teacher'};
  bool get isDirected => directedTypes.contains(type);
  String get displayLabel => type == 'custom' && label.trim().isNotEmpty
      ? label.trim() : (types[type] ?? type);

  factory LifeConnection.fromMap(Map<String, Object?> map) => LifeConnection(
    id: map['id'] as int, treeId: map['tree_id'] as int,
    fromMemberId: map['from_member_id'] as int,
    toMemberId: map['to_member_id'] as int,
    type: (map['connection_type'] as String?) ?? 'friend',
    label: (map['custom_label'] as String?) ?? '',
    notes: (map['notes'] as String?) ?? '',
    startedAt: DateTime.tryParse(map['started_at']?.toString() ?? ''),
    endedAt: DateTime.tryParse(map['ended_at']?.toString() ?? ''),
  );
}

class LifeEvent {
  const LifeEvent({required this.id, required this.treeId, required this.title,
    required this.type, required this.description, required this.location,
    this.eventDate, this.participantIds = const [], this.albumCount = 0});
  final int id, treeId;
  final String title, type, description, location;
  final DateTime? eventDate;
  final List<int> participantIds;
  final int albumCount;

  static const types = <String, String>{
    'milestone': 'Milestone', 'birthday': 'Birthday',
    'graduation': 'Graduation', 'wedding': 'Wedding', 'celebration': 'Celebration',
    'travel': 'Travel', 'meeting': 'Meeting', 'work': 'Work',
    'achievement': 'Achievement', 'other': 'Other',
  };
  String get displayType => types[type] ?? type;
  factory LifeEvent.fromMap(Map<String, Object?> map,
      {List<int> participantIds = const [], int albumCount = 0}) => LifeEvent(
    id: map['id'] as int, treeId: map['tree_id'] as int,
    title: (map['title'] as String?) ?? '',
    type: (map['event_type'] as String?) ?? 'milestone',
    description: (map['description'] as String?) ?? '',
    location: (map['location'] as String?) ?? '',
    eventDate: DateTime.tryParse(map['event_date']?.toString() ?? ''),
    participantIds: participantIds, albumCount: albumCount,
  );
}
