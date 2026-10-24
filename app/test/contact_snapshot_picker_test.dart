import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/presentation/widgets/contact_snapshot_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('github.com/QuisApp/flutter_contacts');

  testWidgets(
    'multiple numbers require selection; cancellation yields no snapshot',
    (tester) async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            switch (call.method) {
              case 'requestPermission':
                return true;
              case 'openExternalPick':
                return 'synthetic-id';
              case 'select':
                return [
                  <String, Object>{
                    'id': 'synthetic-id',
                    'name': <String, Object>{'first': 'Test'},
                    'phones': [
                      <String, String>{'number': '9876543210'},
                      <String, String>{'number': '+16502530000'},
                    ],
                  },
                ];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      ContactSnapshot? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await selectContactSnapshot(context);
                },
                child: const Text('Pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a phone number'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('9876543210'));
      await tester.pumpAndSettle();
      expect(find.text('Country for national numbers'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(methods, isNot(contains('getContacts')));
    },
  );
}
