import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lenden_tracker/main.dart' as app;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline first launch and root navigation', (tester) async {
    expect(
      (await getApplicationDocumentsDirectory()).path,
      contains('.acceptance'),
    );
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final create = find.text('Create private ledger');
    if (create.evaluate().isNotEmpty) {
      await tester.tap(create);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    expect(find.text('LenDen Tracker'), findsWidgets);
    await tester.tap(find.text('Loans').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
