import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/services/portable_backup_crypto.dart';

void main() {
  const password = 'correct horse battery staple 2026';
  final payload = Uint8List.fromList(<int>[80, 75, 3, 4, 1, 2, 3, 4, 5, 6]);

  test('Encrypted backup roundtrips its complete ZIP payload', () async {
    final encrypted = await PortableBackupCrypto.encrypt(payload, password);
    expect(PortableBackupCrypto.hasMagic(encrypted), isTrue);
    expect(encrypted.sublist(0, 4), isNot(equals(payload.sublist(0, 4))));
    expect(await PortableBackupCrypto.decrypt(encrypted, password), payload);
  });

  test('Distinct backups with same password have unique salt and nonce', () async {
    final first = await PortableBackupCrypto.encrypt(payload, password);
    final second = await PortableBackupCrypto.encrypt(payload, password);
    expect(first, isNot(second));
    expect(await PortableBackupCrypto.decrypt(first, password), payload);
    expect(await PortableBackupCrypto.decrypt(second, password), payload);
  });

  test('Wrong password never provides decrypted data', () async {
    final encrypted = await PortableBackupCrypto.encrypt(payload, password);
    await expectLater(
      PortableBackupCrypto.decrypt(encrypted, 'incorrect password'),
      throwsFormatException,
    );
  });

  test('Tampering with ciphertext or authenticated header fails', () async {
    final bytes = await PortableBackupCrypto.encrypt(payload, password);
    final corruptedBody = Uint8List.fromList(bytes);
    corruptedBody[50] ^= 0x01;
    await expectLater(
      PortableBackupCrypto.decrypt(corruptedBody, password),
      throwsFormatException,
    );
    final corruptedSalt = Uint8List.fromList(bytes);
    corruptedSalt[10] ^= 0x01;
    await expectLater(
      PortableBackupCrypto.decrypt(corruptedSalt, password),
      throwsFormatException,
    );
  });

  test('Truncation and unencrypted ZIPs are rejected', () async {
    await expectLater(
      PortableBackupCrypto.decrypt(Uint8List.fromList([80, 75, 3, 4]), password),
      throwsFormatException,
    );
    final encrypted = await PortableBackupCrypto.encrypt(payload, password);
    await expectLater(
      PortableBackupCrypto.decrypt(encrypted.sublist(0, 34), password),
      throwsFormatException,
    );
  });

  test('Requires a backup password with at least 12 characters', () async {
    await expectLater(
      PortableBackupCrypto.encrypt(payload, 'short'),
      throwsFormatException,
    );
  });
}
