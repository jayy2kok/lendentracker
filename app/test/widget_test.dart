import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/presentation/screens/home/home_screen.dart';

void main() {
  testWidgets('Home separates currencies and directions', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        principalBalancesProvider.overrideWith((ref) async => [
          const PrincipalBalance(
            currency: 'INR', direction: LoanDirection.lent, amountMinor: 125050,
          ),
          const PrincipalBalance(
            currency: 'USD', direction: LoanDirection.borrowed, amountMinor: 2300,
          ),
        ]),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Owed to me · INR'), findsOneWidget);
    expect(find.text('I owe · USD'), findsOneWidget);
    expect(find.text('₹1,250.50'), findsOneWidget);
    expect(find.text('\$23.00'), findsOneWidget);
  });
}
