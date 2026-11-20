import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/widgets/ai_response_text.dart';

void main() {
  testWidgets('code actions keep inline code intact and copy fenced source', (
    tester,
  ) async {
    final copies = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copies.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiResponseText(
            data: 'Use `value`.\n\n```dart\nprint("Hello");\n```',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(copies, ['print("Hello");']);
    expect(tester.takeException(), isNull);
  });
}
