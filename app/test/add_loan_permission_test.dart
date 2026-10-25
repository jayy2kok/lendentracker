import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/presentation/screens/add_loan/add_loan_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_contacts');

  testWidgets('Denied contact access does not open the picker', (tester) async {
    var pickerOpened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'permissions.check' ||
              call.method == 'permissions.request') {
            return 'denied';
          }
          if (call.method == 'native.showPicker') pickerOpened = true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddLoanFlow())),
    );
    await tester.tap(find.text('Choose contact'));
    await tester.pumpAndSettle();

    expect(pickerOpened, isFalse);
    expect(find.textContaining('Existing loans remain accessible'), findsOneWidget);
  });
}
