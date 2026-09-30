// Walks the whole loop: sign in, place a bet, run a race, read the result.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/main.dart';
import 'package:game/widgets/race_result_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> signIn(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'player');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();
  }

  testWidgets('a full race pays out and returns to the track', (tester) async {
    await signIn(tester);

    expect(find.text('Race Day · #0'), findsOneWidget);
    expect(find.text(r'$1000.00'), findsWidgets);

    // Place a single bet on Blaze with the default 10 credit stake.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Place Bet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blaze'));
    await tester.pumpAndSettle();
    expect(find.textContaining('x · returns'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, r'Bet $10.00'));
    await tester.pumpAndSettle();

    expect(find.textContaining(r'$10.00 on Blaze'), findsOneWidget);

    // The stake leaves the balance when the race starts.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Race'));
    await tester.pump();
    expect(find.text(r'$990.00'), findsWidgets);

    // The race reveals 10 stops per racer one after the other.
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(RaceResultDialog).evaluate().isNotEmpty) break;
    }

    expect(find.byType(RaceResultDialog), findsOneWidget);
    expect(find.text('FINAL STANDS'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);

    // Exactly one racer is reported as the winner of the race.
    final standings = tester.widgetList<Text>(find.byType(Text));
    expect(standings.where((text) => text.data == 'takes the race').length, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Race Again'));
    await tester.pumpAndSettle();

    expect(find.byType(RaceResultDialog), findsNothing);
    expect(find.text('Race Day · #1'), findsOneWidget);
    // The bet is settled, so nothing is pending and the slip is gone.
    expect(find.textContaining('No bet this race'), findsOneWidget);
  });

  testWidgets('a race without a bet still reports a winner', (tester) async {
    await signIn(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Race'));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(RaceResultDialog).evaluate().isNotEmpty) break;
    }

    expect(find.text('NO BET'), findsOneWidget);
    expect(find.text(r'$1000.00'), findsWidgets);
  });
}
