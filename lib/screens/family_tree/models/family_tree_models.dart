class FamilyPhoto {
  const FamilyPhoto({
    required this.id,
    required this.path,
    required this.createdAt,
  });

  final int id;
  final String path;
  final DateTime createdAt;

  factory FamilyPhoto.fromMap(Map<String, Object?> map) => FamilyPhoto(
        id: map['id'] as int,
        path: (map['image_path'] as String?) ?? '',
        createdAt: _date(map['created_at']) ?? DateTime.now(),
      );
}

class FamilyTree {
  const FamilyTree({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyTree.fromMap(Map<String, Object?> map) => FamilyTree(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        coverImagePath: map['cover_image_path'] as String?,
        createdAt: _date(map['created_at']) ?? DateTime.now(),
        updatedAt: _date(map['updated_at']) ?? DateTime.now(),
      );
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.treeId,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.gender,
    required this.birthDate,
    required this.deathDate,
    required this.phone,
    required this.email,
    required this.address,
    required this.occupation,
    required this.description,
    required this.notes,
    required this.profileImagePath,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int treeId;
  final String firstName;
  final String lastName;
  final String nickname;
  final String gender;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String phone;
  final String email;
  final String address;
  final String occupation;
  final String description;
  final String notes;
  final String? profileImagePath;
  /// Additional photos; the legacy profile image remains the cover.
  final List<FamilyPhoto> photos;
  List<String> get imagePaths => [
        if (profileImagePath != null && profileImagePath!.isNotEmpty)
          profileImagePath!,
        ...photos.where((photo) => photo.path != profileImagePath)
            .map((photo) => photo.path),
      ];
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'Unnamed person' : value;
  }

  String get displayName => nickname.trim().isEmpty ? fullName : '$fullName ($nickname)';

  factory FamilyMember.fromMap(
    Map<String, Object?> map, {List<FamilyPhoto> photos = const []}
  ) => FamilyMember(
        photos: photos,
        id: map['id'] as int,
        treeId: map['tree_id'] as int,
        firstName: (map['first_name'] as String?) ?? '',
        lastName: (map['last_name'] as String?) ?? '',
        nickname: (map['nickname'] as String?) ?? '',
        gender: (map['gender'] as String?) ?? 'unspecified',
        birthDate: _date(map['birth_date']),
        deathDate: _date(map['death_date']),
        phone: (map['phone'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        occupation: (map['occupation'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        notes: (map['notes'] as String?) ?? '',
        profileImagePath: map['profile_image_path'] as String?,
        createdAt: _date(map['created_at']) ?? DateTime.now(),
        updatedAt: _date(map['updated_at']) ?? DateTime.now(),
      );
}

class FamilyRelationship {
  const FamilyRelationship({
    required this.id,
    required this.treeId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.type,
    required this.createdAt,
  });

  final int id;
  final int treeId;
  final int fromMemberId;
  final int toMemberId;
  final String type;
  final DateTime createdAt;

  factory FamilyRelationship.fromMap(Map<String, Object?> map) =>
      FamilyRelationship(
        id: map['id'] as int,
        treeId: map['tree_id'] as int,
        fromMemberId: map['from_member_id'] as int,
        toMemberId: map['to_member_id'] as int,
        type: (map['relationship_type'] as String?) ?? 'other',
        createdAt: _date(map['created_at']) ?? DateTime.now(),
      );
}

class FamilyMemory {
  const FamilyMemory({
    required this.id,
    required this.treeId,
    required this.memberId,
    required this.title,
    required this.description,
    required this.memoryDate,
    required this.mediaType,
    required this.mediaPath,
    this.photos = const [],
    this.participantIds = const [],
    this.eventId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int treeId;
  final int? memberId;
  final String title;
  final String description;
  final DateTime? memoryDate;
  final String mediaType;
  final String? mediaPath;
  /// Additional album photos. [mediaPath] is the legacy/cover photo.
  final List<FamilyPhoto> photos;
  /// Other tagged family members; memberId remains the primary person.
  final List<int> participantIds;
  /// Optional life event this album belongs to.
  final int? eventId;
  List<String> get imagePaths => [
        if (mediaPath != null && mediaPath!.isNotEmpty) mediaPath!,
        ...photos.map((photo) => photo.path),
      ];
  Set<int> get linkedMemberIds => {
        if (memberId != null) memberId!,
        ...participantIds,
      };
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyMemory.fromMap(
    Map<String, Object?> map, {
    List<FamilyPhoto> photos = const [],
    List<int> participantIds = const [],
  }) => FamilyMemory(
        photos: photos,
        participantIds: participantIds,
        eventId: map['event_id'] as int?,
        id: map['id'] as int,
        treeId: map['tree_id'] as int,
        memberId: map['member_id'] as int?,
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        memoryDate: _date(map['memory_date']),
        mediaType: (map['media_type'] as String?) ?? 'text',
        mediaPath: map['media_path'] as String?,
        createdAt: _date(map['created_at']) ?? DateTime.now(),
        updatedAt: _date(map['updated_at']) ?? DateTime.now(),
      );
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
