import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/services/device_sync/local_sync_tls.dart';

void main() {
  const goodFingerprint =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('valid SHA-256 certificate pins are mandatory', () {
    expect(LocalSyncTls.isValidFingerprint(goodFingerprint), isTrue);
    expect(LocalSyncTls.isValidFingerprint(''), isFalse);
    expect(LocalSyncTls.isValidFingerprint(null), isFalse);
    expect(LocalSyncTls.isValidFingerprint('bad'), isFalse);
    expect(LocalSyncTls.isValidFingerprint('A'.padRight(64, 'A')), isFalse);
  });

  test('unenrolled peers fail closed without falling back to HTTP', () {
    expect(() => LocalSyncTls.pinnedClient(null), throwsStateError);
    expect(() => LocalSyncTls.pinnedClient(''), throwsStateError);
    expect(() => LocalSyncTls.pinnedClient('0000000000'), throwsStateError);
  });

  test('every sync endpoint is HTTPS on the single fixed port', () {
    expect(LocalSyncTls.syncPort, 39393);
    for (final path in [
      '/secondary-invite', '/pair', '/bootstrap', '/bootstrap/ack',
      '/sync', '/sync/ack', '/logout',
    ]) {
      final uri = LocalSyncTls.endpoint('192.168.1.2', LocalSyncTls.syncPort, path);
      expect(uri.scheme, 'https');
      expect(uri.host, '192.168.1.2');
      expect(uri.port, 39393);
      expect(uri.path, path);
    }
    expect(
      () => LocalSyncTls.endpoint('192.168.1.2', 49494, '/pair'),
      throwsFormatException,
    );
    expect(
      () => LocalSyncTls.endpoint('192.168.1.2', 0, '/pair'),
      throwsFormatException,
    );
  });

  test('newly generated v2 certificate completes real HTTPS handshake', () async {
    // This regression test catches CANNOT_PARSE_LEAF_CERT caused by invalid
    // DER certificates before users try pairing Android and Linux.
    final identity = await LocalSyncTls.generateEphemeralForTesting();
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0, // Loopback test only; production always uses TCP 39393.
      identity.serverContext,
    );
    server.listen((request) async {
      request.response.write('TLS works');
      await request.response.close();
    });
    final client = LocalSyncTls.pinnedClient(identity.fingerprint);
    try {
      final response = await client.getUrl(Uri(
        scheme: 'https',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        path: '/health',
      )).then((request) => request.close()).timeout(const Duration(seconds: 10));
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.transform(utf8.decoder).join(),
          'TLS works');
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  test('a mismatched certificate pin is never accepted', () async {
    final identity = await LocalSyncTls.generateEphemeralForTesting();
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0, // Test-only random loopback port, not used by the application server.
      identity.serverContext,
    );
    server.listen((request) async { await request.response.close(); });
    final invalidPin = identity.fingerprint == goodFingerprint
        ? ''.padRight(64, 'f')
        : goodFingerprint;
    final client = LocalSyncTls.pinnedClient(invalidPin);
    try {
      await expectLater(
        client.getUrl(Uri(
          scheme: 'https',
          host: '127.0.0.1',
          port: server.port,
          path: '/health',
        )).timeout(const Duration(seconds: 10)),
        throwsA(isA<HandshakeException>()),
      );
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
