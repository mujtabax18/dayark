class MediaEditHistory {
  const MediaEditHistory({
    this.id,
    required this.mediaId,
    required this.action,
    required this.version,
    required this.sourcePath,
    required this.outputPath,
    this.metadataJson,
    required this.createdAt,
  });

  final int? id;
  final int mediaId;
  final String action;
  final int version;
  final String sourcePath;
  final String outputPath;
  final String? metadataJson;
  final String createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'media_id': mediaId,
      'action': action,
      'version': version,
      'source_path': sourcePath,
      'output_path': outputPath,
      'metadata_json': metadataJson,
      'created_at': createdAt,
    };
  }

  factory MediaEditHistory.fromMap(Map<String, dynamic> map) {
    return MediaEditHistory(
      id: _asInt(map['id']),
      mediaId: _asInt(map['media_id']) ?? 0,
      action: map['action']?.toString() ?? 'edit',
      version: _asInt(map['version']) ?? 1,
      sourcePath: map['source_path']?.toString() ?? '',
      outputPath: map['output_path']?.toString() ?? '',
      metadataJson: map['metadata_json']?.toString(),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
