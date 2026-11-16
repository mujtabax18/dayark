import 'dart:convert';
import 'dart:typed_data';

import '../core/ai_attachments.dart';
import '../models/ai_models.dart';

enum AiChatMessageState { complete, pending, failed, stopped }

class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.message,
    required this.createdAt,
    this.state = AiChatMessageState.complete,
    this.provider,
    this.model,
    this.error,
  });
  final String id;
  final AiMessage message;
  final DateTime createdAt;
  final AiChatMessageState state;
  final String? provider, model, error;
  AiChatMessage copyWith({
    AiMessage? message,
    AiChatMessageState? state,
    String? error,
  }) => AiChatMessage(
    id: id,
    message: message ?? this.message,
    createdAt: createdAt,
    state: state ?? this.state,
    provider: provider,
    model: model,
    error: error,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': message.role.name,
    'text': message.text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
    'provider': provider,
    'model': model,
    'error': error,
    'attachments': message.attachments
        .map(
          (a) => {
            'id': a.id,
            'kind': a.kind.name,
            'mimeType': a.mimeType,
            'name': a.name,
            'data': base64Encode(a.bytes!),
          },
        )
        .toList(),
  };
  factory AiChatMessage.fromJson(Map<String, dynamic> j) {
    final role = AiRole.values.byName(j['role'] as String);
    if (role == AiRole.system) {
      throw const FormatException(
        'System messages are not conversation records.',
      );
    }
    final attachments = (j['attachments'] as List? ?? []).map((value) {
      final a = Map<String, dynamic>.from(value as Map);
      final attachment = AiAttachment(
        id: a['id'] as String,
        kind: AiAttachmentKind.values.byName(a['kind'] as String),
        mimeType: a['mimeType'] as String,
        uri: Uri(scheme: 'attachment', path: a['id'] as String),
        name: a['name'] as String?,
        bytes: Uint8List.fromList(base64Decode(a['data'] as String)),
      );
      validateAiAttachment(attachment);
      return attachment;
    }).toList();
    if (attachments.length > 8 ||
        (j['text'] as String).length > 4 * 1024 * 1024) {
      throw const FormatException('Message exceeds supported size.');
    }
    return AiChatMessage(
      id: j['id'] as String,
      message: AiMessage(
        role: role,
        text: j['text'] as String,
        attachments: attachments,
      ),
      createdAt: DateTime.parse(j['createdAt'] as String),
      state: AiChatMessageState.values.byName(j['state'] as String),
      provider: j['provider'] as String?,
      model: j['model'] as String?,
      error: j['error'] as String?,
    );
  }
}

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    Iterable<AiChatMessage> messages = const [],
    this.folder = '',
    this.pinned = false,
    this.archived = false,
    this.deleted = false,
    this.shareWithDevices = false,
    this.profileId,
    this.revision = 0,
    this.origin = '',
    Map<String, int> clock = const {},
  }) : messages = List.unmodifiable(messages),
       clock = Map.unmodifiable(clock) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id) ||
        title.length > 200 ||
        folder.length > 100 ||
        this.messages.length > 2000 ||
        revision < 0 ||
        revision > 253402300799999999 ||
        this.clock.length > 100 ||
        this.clock.values.any((v) => v < 0)) {
      throw const FormatException('Invalid conversation.');
    }
  }
  final String id, title, folder, origin;
  final String? profileId;
  final List<AiChatMessage> messages;
  final bool pinned, archived, deleted, shareWithDevices;
  final DateTime updatedAt;
  final int revision;
  final Map<String, int> clock;
  AiConversation copyWith({
    String? id,
    String? title,
    String? folder,
    String? profileId,
    Iterable<AiChatMessage>? messages,
    bool? pinned,
    bool? archived,
    bool? deleted,
    bool? shareWithDevices,
    DateTime? updatedAt,
    int? revision,
    String? origin,
    Map<String, int>? clock,
  }) => AiConversation(
    id: id ?? this.id,
    title: title ?? this.title,
    folder: folder ?? this.folder,
    profileId: profileId ?? this.profileId,
    messages: messages ?? this.messages,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
    deleted: deleted ?? this.deleted,
    shareWithDevices: shareWithDevices ?? this.shareWithDevices,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    origin: origin ?? this.origin,
    clock: clock ?? this.clock,
  );
  Map<String, dynamic> toJson({bool sync = false}) => {
    'version': 1,
    'id': id,
    'title': title,
    'folder': folder,
    'pinned': pinned,
    'archived': archived,
    'deleted': deleted,
    'shareWithDevices': shareWithDevices,
    if (!sync) 'profileId': profileId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'origin': origin,
    'clock': clock,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
  factory AiConversation.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported chat version.');
    }
    return AiConversation(
      id: j['id'] as String,
      title: j['title'] as String,
      folder: j['folder'] as String? ?? '',
      pinned: j['pinned'] == true,
      archived: j['archived'] == true,
      deleted: j['deleted'] == true,
      shareWithDevices: j['shareWithDevices'] == true,
      profileId: j['profileId'] as String?,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      revision: j['revision'] as int,
      origin: j['origin'] as String,
      clock: Map<String, int>.from(j['clock'] as Map),
      messages: (j['messages'] as List).map(
        (m) => AiChatMessage.fromJson(Map<String, dynamic>.from(m as Map)),
      ),
    );
  }
}
