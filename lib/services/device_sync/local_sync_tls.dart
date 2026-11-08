// DayArk secure LAN sync identity (v2).
// Each installation generates its own RSA key and standards-compliant X.509
// certificate. QR pairing establishes an out-of-band SHA-256 certificate pin.
// Never disable validation or fall back to HTTP when the TLS handshake fails.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalSyncTls {
  const LocalSyncTls._(this.serverContext, this.fingerprint);

  // Fixed across Android, iOS, Linux, macOS, and Windows. Never bind to port 0.
  static const int syncPort = 39393;
  static const int identityVersion = 2;

  final SecurityContext serverContext;
  final String fingerprint;

  static final RegExp _fingerprintFormat = RegExp(r'^[0-9a-f]{64}$');

  static bool isValidFingerprint(String? value) =>
      value != null && _fingerprintFormat.hasMatch(value);

  static Future<LocalSyncTls> loadOrCreate() async {
    final dir = await getApplicationSupportDirectory();
    // v1 used third-party ASN.1 certificate generation which could produce a
    // malformed leaf certificate rejected by Android's TLS parser. A separate
    // filename automatically rotates that broken identity exactly once.
    final identityFile = File(p.join(dir.path, 'dayark_local_sync_tls_v2.json'));
    Map<String, dynamic> material;
    if (await identityFile.exists()) {
      await _protectIdentityFile(identityFile);
      material = jsonDecode(await identityFile.readAsString()) as Map<String, dynamic>;
    } else {
      material = await Isolate.run(_generateLocalTlsIdentityV2);
      // On platforms where filesystem permissions are supported, protect the
      // file *before* the private key is written to disk.
      await identityFile.create(recursive: true, exclusive: true);
      try {
        await _protectIdentityFile(identityFile);
        await identityFile.writeAsString(jsonEncode(material), flush: true);
      } catch (_) {
        await identityFile.delete();
        rethrow;
      }
    }
    return _fromMaterial(material);
  }

  static Future<void> _protectIdentityFile(File identityFile) async {
    if (Platform.isLinux || Platform.isMacOS) {
      final permissions = await Process.run('chmod', ['600', identityFile.path]);
      if (permissions.exitCode != 0) {
        throw StateError('Unable to secure local sync TLS private key file.');
      }
    }
  }

  static LocalSyncTls _fromMaterial(Map<String, dynamic> material) {
    final certificate = material['certificate'] as String;
    final privateKey = material['privateKey'] as String;
    // Parsing both PEM blocks catches corrupt identity files early rather than
    // producing an obscure exception while another device tries to pair.
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(certificate))
      ..usePrivateKeyBytes(utf8.encode(privateKey));
    final fingerprint = sha256.convert(CryptoUtils.getBytesFromPEMString(certificate)).toString();
    return LocalSyncTls._(context, fingerprint);
  }

  // Allows the integration test to exercise a real TLS handshake without
  // reading or changing the user's installed private key/database.
  static Future<LocalSyncTls> generateEphemeralForTesting() async =>
      _fromMaterial(await Isolate.run(_generateLocalTlsIdentityV2));

  /// Unpinned peers fail closed. The callback accepts only the certificate
  /// whose SHA-256 *DER* fingerprint was exchanged in the trusted pairing QR.
  static HttpClient pinnedClient(String? fingerprint, {Duration? timeout}) {
    if (!isValidFingerprint(fingerprint)) {
      throw StateError(
        'Secure LAN sync requires a verified device fingerprint. '
        'Re-pair the devices using a fresh QR on the updated apps.',
      );
    }
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = timeout ?? const Duration(seconds: 5);
    client.badCertificateCallback = (certificate, host, port) =>
        sha256.convert(certificate.der).toString() == fingerprint;
    return client;
  }

  static Uri endpoint(String host, int port, String path) {
    if (port != syncPort) {
      throw FormatException(
        'Unsupported LAN sync port $port. Both devices must use '
        'TCP $syncPort; create a new pairing QR on the updated app.',
      );
    }
    return Uri(scheme: 'https', host: host, port: syncPort, path: path);
  }
}

Map<String, dynamic> _generateLocalTlsIdentityV2() {
  final keys = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final privateKey = keys.privateKey as RSAPrivateKey;
  final publicKey = keys.publicKey as RSAPublicKey;

  // Construct RFC 5280 DER explicitly, avoiding noncanonical X.509 extension
  // encoding in the v1 helper. In particular, each extension's OCTET STRING
  // contains exactly one valid DER-encoded value. No external openssl command
  // (unavailable on Android/iOS) and no shared/bundled private key are used.
  final signatureAlgorithm = _derSeq([
    _der(0x06, [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b]),
    _der(0x05, const []),
  ]); // sha256WithRSAEncryption
  final rsaAlgorithm = _derSeq([
    _der(0x06, [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]),
    _der(0x05, const []),
  ]); // rsaEncryption
  final name = _derSeq([
    _der(0x31, _derSeq([
      _der(0x06, [0x55, 0x04, 0x03]), // commonName
      _der(0x0c, utf8.encode('DayArk Local Device Sync')),
    ])),
  ]);
  final now = DateTime.now().toUtc();
  final notBefore = now.subtract(const Duration(days: 1));
  final notAfter = now.add(const Duration(days: 3650));
  final validity = _derSeq([
    _der(0x17, ascii.encode(_utcTime(notBefore))),
    _der(0x17, ascii.encode(_utcTime(notAfter))),
  ]);
  final spki = _derSeq([
    rsaAlgorithm,
    _der(0x03, [
      0, // unused bits in BIT STRING
      ..._derSeq([_positiveInteger(publicKey.modulus!), _positiveInteger(publicKey.exponent!)]),
    ]),
  ]);

  // KeyUsage: digitalSignature + keyEncipherment, with five unused low bits.
  // ExtendedKeyUsage: serverAuth. BasicConstraints: CA=false. The SAN's fixed
  // DNS name is descriptive; identity authentication is through QR pinning.
  final extensions = _der(0xa3, _derSeq([
    _extension([0x55, 0x1d, 0x13], _derSeq([]), critical: true),
    _extension([0x55, 0x1d, 0x0f], _der(0x03, [5, 0xa0]), critical: true),
    _extension([0x55, 0x1d, 0x25], _derSeq([
      _der(0x06, [0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01]),
    ])),
    _extension([0x55, 0x1d, 0x11], _derSeq([
      _der(0x82, ascii.encode('dayark.local')),
    ])),
  ]));

  final random = Random.secure();
  final serial = List<int>.generate(16, (_) => random.nextInt(256));
  serial[0] = (serial[0] & 0x7f) | 0x01; // strictly positive ASN.1 INTEGER
  final tbsCertificate = _derSeq([
    _der(0xa0, _positiveInteger(BigInt.from(2))), // explicit v3
    _der(0x02, serial),
    signatureAlgorithm,
    name, // issuer
    validity,
    name, // subject (self-signed)
    spki,
    extensions,
  ]);
  final signature = CryptoUtils.rsaSign(
    privateKey,
    tbsCertificate,
    algorithmName: 'SHA-256/RSA',
  );
  final certificateDer = _derSeq([
    tbsCertificate,
    signatureAlgorithm,
    _der(0x03, [0, ...signature]),
  ]);
  final certificateB64 = base64.encode(certificateDer);
  final certificateLines = RegExp('.{1,64}')
      .allMatches(certificateB64)
      .map((m) => m.group(0)!)
      .join('\n');

  return <String, dynamic>{
    'certificate': '-----BEGIN CERTIFICATE-----\n$certificateLines\n-----END CERTIFICATE-----\n',
    'privateKey': CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
  };
}

// Minimal DER primitives for the small fixed X.509 schema above.
Uint8List _der(int tag, List<int> content) => Uint8List.fromList([
      tag,
      ..._derLength(content.length),
      ...content,
    ]);

List<int> _derLength(int count) {
  if (count < 128) return [count];
  final bytes = <int>[];
  var value = count;
  while (value > 0) {
    bytes.insert(0, value & 0xff);
    value >>= 8;
  }
  return [0x80 | bytes.length, ...bytes];
}

Uint8List _derSeq(List<List<int>> parts) =>
    _der(0x30, [for (final part in parts) ...part]);

Uint8List _positiveInteger(BigInt value) {
  if (value < BigInt.zero) throw ArgumentError.value(value);
  var digits = value.toRadixString(16);
  if (digits.length.isOdd) digits = '0$digits';
  final bytes = <int>[
    for (var i = 0; i < digits.length; i += 2)
      int.parse(digits.substring(i, i + 2), radix: 16),
  ];
  if ((bytes[0] & 0x80) != 0) bytes.insert(0, 0);
  return _der(0x02, bytes);
}

Uint8List _extension(List<int> oid, List<int> derValue, {bool critical = false}) =>
    _derSeq([
      _der(0x06, oid),
      if (critical) _der(0x01, [0xff]),
      _der(0x04, derValue),
    ]);

String _utcTime(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.year % 100)}${two(date.month)}${two(date.day)}'
      '${two(date.hour)}${two(date.minute)}${two(date.second)}Z';
}
