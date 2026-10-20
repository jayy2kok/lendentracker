import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/presentation/screens/reminder/reminder_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.lendentracker.lenden_tracker/whatsapp_share',
  );
  final calls = <String>[];
  var availability = 'available';

  setUp(() {
    calls.clear();
    availability = 'available';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'availability') return availability;
          if (call.method == 'shareImage') return true;
          throw MissingPluginException();
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> showReminder(WidgetTester tester) async {
    final now = DateTime(2026, 10, 20);
    final loan = Loan(
      id: 1,
      personId: 1,
      direction: LoanDirection.lent,
      principalMinor: 10000,
      currency: 'INR',
      startDate: '2026-01-01',
      maturityDate: '2026-12-01',
      interestMethod: InterestMethod.none,
      paymentSchedule: PaymentSchedule.atMaturity,
      status: LoanStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderLoanProvider(1).overrideWith(
            (ref) async => ReminderPreviewData(
              item: LoanListItem(loan, 'Alice'),
              phone: '+155****4567',
              outstandingPrincipalMinor: 10000,
              nextDueDate: '2026-12-01',
              duePrincipalMinor: 10000,
              scheduledPrincipalMinor: 10000,
              scheduledInterestMinor: 0,
              dueInterestMinor: 0,
              currentDueMinor: 10000,
            ),
          ),
        ],
        child: const MaterialApp(home: ReminderPreviewScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Share via another app'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'installed image handler exposes WhatsApp and its recipient picker',
    (tester) async {
      await showReminder(tester);
      expect(calls, contains('availability'));
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(
        find.textContaining('WhatsApp opens its own recipient picker'),
        findsOneWidget,
      );
      expect(find.textContaining('not detected'), findsNothing);
      expect(find.text('Share via another app'), findsOneWidget);
    },
  );

  testWidgets('missing WhatsApp retains generic sharing and explains absence', (
    tester,
  ) async {
    availability = 'missing';
    await showReminder(tester);
    expect(find.text('Share via WhatsApp'), findsNothing);
    expect(find.textContaining('WhatsApp is not installed'), findsOneWidget);
    expect(find.text('Share via another app'), findsOneWidget);
  });

  testWidgets('installed without image handler retains generic chooser', (
    tester,
  ) async {
    availability = 'noHandler';
    await showReminder(tester);
    expect(find.text('Share via WhatsApp'), findsNothing);
    expect(
      find.textContaining('cannot handle reminder images'),
      findsOneWidget,
    );
    expect(find.text('Share via another app'), findsOneWidget);
  });

  testWidgets('platform check failure does not falsely report missing', (
    tester,
  ) async {
    availability = 'unknown';
    await showReminder(tester);
    expect(find.text('Share via WhatsApp'), findsNothing);
    expect(find.textContaining('not detected'), findsNothing);
    expect(find.text('Share via another app'), findsOneWidget);
  });
}
