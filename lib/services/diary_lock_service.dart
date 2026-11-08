import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class DiaryLockService {
  DiaryLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _enabledKey = 'personal_diary_lock_enabled_v2';
  static const _saltKey = 'personal_diary_pin_salt_v2';
  static const _hashKey = 'personal_diary_pin_hash_v2';
  static const _recoverySaltKey = 'personal_diary_recovery_salt_v2';
  static const _recoveryHashKey = 'personal_diary_recovery_hash_v2';
  static const _deviceRecoveryKey = 'personal_diary_device_recovery_v2';

  // Previous keys are retained for a transparent migration from the first
  // advanced-diary bundle.
  static const _legacyEnabledKey = 'personal_diary_lock_enabled_v1';
  static const _legacySaltKey = 'personal_diary_pin_salt_v1';
  static const _legacyHashKey = 'personal_diary_pin_hash_v1';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<bool> isEnabled() async {
    await _migrateLegacyPinIfNeeded();
    return await _storage.read(key: _enabledKey) == 'true';
  }

  Future<bool> isDeviceRecoveryEnabled() async {
    return await _storage.read(key: _deviceRecoveryKey) != 'false';
  }

  Future<void> setDeviceRecoveryEnabled(bool enabled) async {
    await _storage.write(key: _deviceRecoveryKey, value: enabled.toString());
  }

  Future<bool> hasRecoveryCode() async {
    final salt = await _storage.read(key: _recoverySaltKey);
    final hash = await _storage.read(key: _recoveryHashKey);
    return salt != null && hash != null;
  }

  /// Enables the diary PIN and returns a one-time recovery code.
  ///
  /// The recovery code is only returned in plain text once. Only a salted hash
  /// remains in secure storage, so the user must save the displayed code.
  Future<String> enable(
    String pin, {
    bool deviceRecoveryEnabled = true,
  }) async {
    _validatePin(pin);

    final pinSalt = _createSalt();
    final recoveryCode = _createRecoveryCode();
    final recoverySalt = _createSalt();

    await _storage.write(key: _saltKey, value: pinSalt);
    await _storage.write(key: _hashKey, value: _hash(pin, pinSalt));
    await _storage.write(key: _recoverySaltKey, value: recoverySalt);
    await _storage.write(
      key: _recoveryHashKey,
      value: _hash(_normalizeRecoveryCode(recoveryCode), recoverySalt),
    );
    await _storage.write(key: _deviceRecoveryKey, value: '$deviceRecoveryEnabled');
    await _storage.write(key: _enabledKey, value: 'true');

    await _deleteLegacyKeys();
    return recoveryCode;
  }

  Future<bool> verify(String pin) async {
    await _migrateLegacyPinIfNeeded();
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;
    return _constantTimeEquals(_hash(pin, salt), expected);
  }

  Future<bool> verifyRecoveryCode(String recoveryCode) async {
    final salt = await _storage.read(key: _recoverySaltKey);
    final expected = await _storage.read(key: _recoveryHashKey);
    if (salt == null || expected == null) return false;

    final normalized = _normalizeRecoveryCode(recoveryCode);
    if (normalized.length != 16) return false;
    return _constantTimeEquals(_hash(normalized, salt), expected);
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verify(currentPin)) {
      throw const DiaryLockException('Current diary PIN is incorrect.');
    }
    _validatePin(newPin);

    final salt = _createSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(newPin, salt));
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<String> regenerateRecoveryCode({required String currentPin}) async {
    if (!await verify(currentPin)) {
      throw const DiaryLockException('Current diary PIN is incorrect.');
    }

    final code = _createRecoveryCode();
    final salt = _createSalt();
    await _storage.write(key: _recoverySaltKey, value: salt);
    await _storage.write(
      key: _recoveryHashKey,
      value: _hash(_normalizeRecoveryCode(code), salt),
    );
    return code;
  }

  Future<bool> isDeviceAuthenticationAvailable() async {
    try {
      return await _localAuthentication.isDeviceSupported();
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Uses only the phone's local security prompt. No account, network, SMS,
  /// or backend is involved.
  Future<bool> authenticateWithDevice() async {
    if (!await isDeviceRecoveryEnabled()) return false;
    if (!await isDeviceAuthenticationAvailable()) return false;

    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Unlock your private diary',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      throw DiaryLockException(_friendlyLocalAuthMessage(error));
    } catch (_) {
      throw const DiaryLockException(
        'Device authentication is not available right now.',
      );
    }
  }

  Future<void> disableWithCurrentPin(String currentPin) async {
    if (!await verify(currentPin)) {
      throw const DiaryLockException('Diary PIN is incorrect.');
    }
    await _clearLockData();
  }

  Future<void> disableWithRecoveryCode(String recoveryCode) async {
    if (!await verifyRecoveryCode(recoveryCode)) {
      throw const DiaryLockException('The recovery code is incorrect.');
    }
    await _clearLockData();
  }

  Future<bool> recoverWithDeviceAuthentication() async {
    final authenticated = await authenticateWithDevice();
    if (!authenticated) return false;
    await _clearLockData();
    return true;
  }

  Future<void> _clearLockData() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _recoverySaltKey);
    await _storage.delete(key: _recoveryHashKey);
    await _storage.delete(key: _deviceRecoveryKey);
    await _deleteLegacyKeys();
  }

  Future<void> _migrateLegacyPinIfNeeded() async {
    final currentEnabled = await _storage.read(key: _enabledKey);
    if (currentEnabled != null) return;

    final legacyEnabled = await _storage.read(key: _legacyEnabledKey);
    final legacySalt = await _storage.read(key: _legacySaltKey);
    final legacyHash = await _storage.read(key: _legacyHashKey);
    if (legacyEnabled != 'true' || legacySalt == null || legacyHash == null) {
      return;
    }

    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _saltKey, value: legacySalt);
    await _storage.write(key: _hashKey, value: legacyHash);
    await _storage.write(key: _deviceRecoveryKey, value: 'true');
    await _deleteLegacyKeys();
  }

  Future<void> _deleteLegacyKeys() async {
    await _storage.delete(key: _legacyEnabledKey);
    await _storage.delete(key: _legacySaltKey);
    await _storage.delete(key: _legacyHashKey);
  }

  static void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const DiaryLockException('Use a 4 to 6 digit PIN.');
    }
  }

  static String _createSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _createRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final characters = List<String>.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    );
    return List<String>.generate(
      4,
      (index) => characters.skip(index * 4).take(4).join(),
    ).join('-');
  }

  static String _normalizeRecoveryCode(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String _hash(String value, String salt) {
    // Keep the same salted SHA-256 format used by the previous diary bundle so
    // existing local PINs continue to work after removing Firebase.
    return sha256.convert(utf8.encode('$salt:$value')).toString();
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  static String _friendlyLocalAuthMessage(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Set up a phone PIN, pattern, password, fingerprint, or Face ID first.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Device authentication is temporarily locked. Try again later.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Device authentication is locked. Unlock the phone normally first.';
      case LocalAuthExceptionCode.authInProgress:
        return 'Device authentication is already in progress.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Device authentication was cancelled.';
      default:
        return 'Device authentication could not be completed.';
    }
  }
}

class DiaryLockException implements Exception {
  const DiaryLockException(this.message);

  final String message;

  @override
  String toString() => message;
}
