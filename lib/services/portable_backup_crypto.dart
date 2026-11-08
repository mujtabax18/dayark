import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// DayArk v1 encrypted container. This is NOT a ZIP file on disk:
/// magic(8) + version(1) + salt(16) + nonce(12) + ciphertext + GCM tag(16).
/// Everything after the header is authenticated; the header is AES-GCM AAD.
/// The encrypted payload is the existing portable ZIP format (unchanged).
class PortableBackupCrypto {
  static const String _magic = 'DAYARKB1';
  static const int _version = 1;
  static const int _saltSize = 16;
  static const int _nonceSize = 12;
  static const int _tagSize = 16;
  static const int _headerSize = 8 + 1 + _saltSize + _nonceSize;
  static const int _iterations = 210000;

  /// AES-GCM cannot distinguish an incorrect password from altered ciphertext.
  static const String authenticationFailureMessage =
      'Incorrect backup password or modified/corrupted backup. No data was restored.';

  static bool isEncrypted(List<int> bytes) => hasMagic(bytes);

  /// For use when inspecting the first bytes of a backup. Never use the
  /// extension alone to decide whether a backup is encrypted.
  static bool hasMagic(List<int> bytes) {
    const magic = <int>[68, 65, 89, 65, 82, 75, 66, 49];
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static Uint8List _randomBytes(int count) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(count, (_) => random.nextInt(256)),
    );
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> encrypt(Uint8List zipBytes, String password) async {
    if (password.length < 12) {
      throw const FormatException(
        'Use a backup password of at least 12 characters.',
      );
    }
    final salt = _randomBytes(_saltSize);
    final nonce = _randomBytes(_nonceSize);
    final header = Uint8List.fromList([
      ...ascii.encode(_magic),
      _version,
      ...salt,
      ...nonce,
    ]);
    final key = await _deriveKey(password, salt);
    final encrypted = await AesGcm.with256bits().encrypt(
      zipBytes,
      secretKey: key,
      nonce: nonce,
      aad: header,
    );
    return Uint8List.fromList([
      ...header,
      ...encrypted.cipherText,
      ...encrypted.mac.bytes,
    ]);
  }

  static Future<Uint8List> decrypt(
    Uint8List packageBytes,
    String password,
  ) async {
    if (!hasMagic(packageBytes)) {
      throw const FormatException(
        'This is an older unencrypted backup. Open Legacy Backup & Compatibility.',
      );
    }
    if (packageBytes.length < _headerSize + _tagSize ||
        packageBytes[8] != _version) {
      throw const FormatException(
        'Invalid or unsupported encrypted backup header.',
      );
    }
    final header = packageBytes.sublist(0, _headerSize);
    final salt = packageBytes.sublist(9, 9 + _saltSize);
    final nonce = packageBytes.sublist(9 + _saltSize, _headerSize);
    final ciphertext = packageBytes.sublist(
      _headerSize,
      packageBytes.length - _tagSize,
    );
    final mac = packageBytes.sublist(packageBytes.length - _tagSize);
    try {
      final key = await _deriveKey(password, salt);
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: header,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        authenticationFailureMessage,
      );
    }
  }
}

/// Device-local safety backups must not be saved in plaintext or with a
/// hard-coded password. A random secret stays in the OS secure key store.
/// Losing the OS key store makes these automatic backups unrecoverable, so
/// users should also create portable backups with their own password.
class LocalBackupSecret {
  static const String _storageKey = 'dayark_local_backup_v1_secret';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<String>? _pendingSecret;

  static Future<String> getOrCreate() => _pendingSecret ??= _loadOrCreate();

  static Future<String> _loadOrCreate() async {
    try {
      final existing = await _secureStorage.read(key: _storageKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final value = base64UrlEncode(bytes);
      await _secureStorage.write(key: _storageKey, value: value);
      return value;
    } catch (_) {
      _pendingSecret = null; // Allow a retry if the OS keyring unlocks.
      rethrow;
    }
  }

  static Future<String> requireExisting() async {
    final existing = await _secureStorage.read(key: _storageKey);
    if (existing == null || existing.isEmpty) {
      throw StateError(
        'The local safety-backup key is missing from secure storage. '
        'This backup cannot be decrypted on this device.',
      );
    }
    return existing;
  }
}
