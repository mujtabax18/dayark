import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_chat_sync.dart';
import 'package:metersystem/services/device_sync/local_sync_tls.dart';

import 'ai_chat_store_test.dart' show conversation;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('chat sync exchanges snapshots only after opt-in and paired-token authentication over pinned TLS', () async {
    final a = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    final b = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    await a.setSyncEnabled(true);
    await a.save(conversation('shared', share: true));
    await a.save(conversation('private'));
    var revoked = false;
    final exchange = AiChatSyncExchange(
      store: b,
      authorize: (id, token) async =>
          !revoked && id == 'paired' && token == 'synthetic-token',
    );
    final identity = await LocalSyncTls.generateEphemeralForTesting();
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      identity.serverContext,
    );
    server.listen((req) async {
      final reply = await exchange.exchange(
        jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>,
      );
      req.response.headers.contentType = ContentType.json;
      req.response.statusCode = reply.status;
      req.response.write(jsonEncode(reply.body));
      await req.response.close();
    });
    final client = LocalSyncTls.pinnedClient(identity.fingerprint);
    Future<(int, Map<String, dynamic>)> send(String token) async {
      final req = await client.postUrl(
        Uri(
          scheme: 'https',
          host: '127.0.0.1',
          port: server.port,
          path: '/ai-chat/sync',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'deviceId': 'paired',
          'token': token,
          'snapshot': await a.syncSnapshot(),
        }),
      );
      final res = await req.close();
      return (
        res.statusCode,
        jsonDecode(await utf8.decoder.bind(res).join()) as Map<String, dynamic>,
      );
    }

    try {
      expect((await send('synthetic-token')).$1, 403);
      expect(await b.list(), isEmpty);
      await b.setSyncEnabled(true);
      expect((await send('wrong-token')).$1, 403);
      expect(await b.list(), isEmpty);
      final result = await send('synthetic-token');
      expect(result.$1, 200);
      await a.mergeSync(
        Map<String, dynamic>.from(result.$2['snapshot'] as Map),
      );
      expect((await b.list()).single.id, 'shared');
      expect(jsonEncode(result.$2), isNot(contains('private-local-profile')));
      revoked = true;
      expect((await send('synthetic-token')).$1, 403);
      expect(
        (await exchange.exchange({
          'deviceId': 'paired',
          'token': 'synthetic-token',
          'snapshot': {},
        })).status,
        403,
      );
    } finally {
      client.close(force: true);
      await server.close(force: true);
      await a.close();
      await b.close();
    }
  });
}
