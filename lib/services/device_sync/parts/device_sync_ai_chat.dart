part of '../device_sync_service.dart';

extension AiChatDeviceSync on DeviceSyncService {
  static const _maxChatSyncBytes = 32 * 1024 * 1024;
  Future<Map<String, dynamic>> _chatBody(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(
      DeviceSyncService._networkTimeout,
    )) {
      if (bytes.length + chunk.length > _maxChatSyncBytes) {
        throw const FormatException('Chat sync batch is too large.');
      }
      bytes.add(chunk);
    }
    return jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
  }

  /// Both devices and every exported conversation opt in. Manual sync and the
  /// existing lightweight LAN timer share this authenticated exchange.
  Future<String> syncAiChats() => _syncAiChats();

  Future<String> _syncAiChats({bool ensureNetworking = true}) async {
    if (!_initialized || aiChatSyncState.role == SyncRole.standalone) {
      throw StateError('Pair this device through Device Sync first.');
    }
    final chats = await sharedAiChatStore();
    if (!await chats.syncEnabled) throw StateError('Chat sync is disabled.');
    if (ensureNetworking) await startNetworking();
    final db = await _db;
    final peers = await db.query('sync_devices', where: 'revoked=0');
    var completed = 0;
    for (final peer in peers) {
      final host = peer['host']?.toString() ?? '';
      final port = (peer['port'] as num?)?.toInt() ?? 0;
      if (host.isEmpty || port <= 0) continue;
      HttpClient? client;
      try {
        client = LocalSyncTls.pinnedClient(peer['tls_fingerprint']?.toString());
        final snapshot = await chats.syncSnapshot();
        final data = utf8.encode(
          jsonEncode({
            'deviceId': aiChatSyncState.deviceId,
            'token': peer['token'],
            'snapshot': snapshot,
          }),
        );
        if (data.length > _maxChatSyncBytes) {
          throw const AiChatSyncLimit();
        }
        final req = await client
            .postUrl(LocalSyncTls.endpoint(host, port, '/ai-chat/sync'))
            .timeout(DeviceSyncService._networkTimeout);
        req.headers.contentType = ContentType.json;
        req.add(data);
        final response = await req.close().timeout(
          DeviceSyncService._networkTimeout,
        );
        final body = await _chatBody(response);
        if (response.statusCode == 413) throw const AiChatSyncLimit();
        if (response.statusCode != 200) continue;
        await chats.mergeSync(
          Map<String, dynamic>.from(body['snapshot'] as Map),
        );
        completed++;
      } on AiChatSyncLimit {
        rethrow;
      } catch (_) {
        // One unavailable or outdated peer must not prevent other paired devices from syncing.
      } finally {
        client?.close(force: true);
      }
    }
    return completed == 0
        ? 'No chats exchanged. Enable chat sync on both paired devices and check their connection.'
        : 'Shared chats synchronized with $completed paired device${completed == 1 ? '' : 's'}.';
  }

  Future<void> _serveAiChatSync(HttpRequest request) async {
    final chats = await sharedAiChatStore();
    if (!await chats.syncEnabled) {
      DeviceSyncService._json(request.response, 403, {
        'error': 'Chat sync is disabled.',
      });
      return;
    }
    try {
      final body = await _chatBody(request);
      final exchange = AiChatSyncExchange(
        store: chats,
        authorize: (deviceId, token) async =>
            aiChatSyncState.role != SyncRole.standalone &&
            await _authenticatedPeer(await _db, deviceId, token) != null,
      );
      final result = await exchange.exchange(body);
      DeviceSyncService._json(request.response, result.status, result.body);
    } catch (_) {
      DeviceSyncService._json(request.response, 400, {
        'error': 'Invalid or oversized chat sync request.',
      });
    }
  }
}
