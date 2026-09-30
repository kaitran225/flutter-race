// Smoke test for the login screen that greets a player without an account.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/main.dart';
import 'package:game/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    Session.instance.value = null;
  });

  testWidgets('shows the login form on a fresh install', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();

    expect(find.text('Stop Race'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
  });

  testWidgets('rejects a short password before calling the service',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GameApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'player');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'ab');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pump();

    expect(find.text('At least 4 characters'), findsOneWidget);
    expect(Session.instance.value, isNull);
  });
}
