import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/screens/Settings/components/backup_password_dialog.dart';

void main() {
  testWidgets('restore dialog closes without using disposed controllers', (
    tester,
  ) async {
    String? selectedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedPassword = await BackupPasswordDialog.restore(context);
              },
              child: const Text('Open restore'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'my backup password');
    await tester.tap(find.text('Unlock and restore'));
    await tester.pumpAndSettle();

    expect(selectedPassword, 'my backup password');
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create dialog validates passwords and disposes after close', (
    tester,
  ) async {
    String? selectedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedPassword = await BackupPasswordDialog.create(context);
              },
              child: const Text('Open create'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'secure password 123');
    await tester.enterText(find.byType(TextField).last, 'different password');
    await tester.tap(find.text('Continue to save'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      'secure password 123',
    );
    await tester.tap(find.text('Continue to save'));
    await tester.pumpAndSettle();
    expect(selectedPassword, 'secure password 123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry message is visible and dismissing cleans up controller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? selectedPassword = 'unchanged';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedPassword = await BackupPasswordDialog.restore(
                  context,
                  errorText: 'The previous password did not unlock this backup.',
                );
              },
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('The previous password did not unlock this backup.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selectedPassword, isNull);
    expect(tester.takeException(), isNull);
  });
}
