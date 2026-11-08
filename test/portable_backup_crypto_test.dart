import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/services/portable_backup_crypto.dart';

void main() {
  test('encrypted backup roundtrip preserves data and format', () async {
    final data = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
    const password = 'safe backup password';
    final encrypted = await PortableBackupCrypto.encrypt(data, password);

    expect(PortableBackupCrypto.hasMagic(encrypted), isTrue);
    expect(PortableBackupCrypto.isEncrypted(encrypted), isTrue);
    expect(
      await PortableBackupCrypto.decrypt(encrypted, password),
      orderedEquals(data),
    );
  });

  test('wrong password cannot decrypt an encrypted backup', () async {
    final encrypted = await PortableBackupCrypto.encrypt(
      Uint8List.fromList([1, 2, 3, 4]),
      'correct backup password',
    );

    await expectLater(
      PortableBackupCrypto.decrypt(encrypted, 'incorrect password'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          PortableBackupCrypto.authenticationFailureMessage,
        ),
      ),
    );
  });

  test('modified ciphertext cannot be restored', () async {
    final encrypted = await PortableBackupCrypto.encrypt(
      Uint8List.fromList([1, 2, 3, 4]),
      'correct backup password',
    );
    final tampered = Uint8List.fromList(encrypted);
    tampered[40] ^= 1;

    await expectLater(
      PortableBackupCrypto.decrypt(tampered, 'correct backup password'),
      throwsA(isA<FormatException>()),
    );
  });
}
