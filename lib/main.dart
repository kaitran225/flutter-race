import 'package:flutter/material.dart';

import 'models/user.dart';
import 'screens/login_screen.dart';
import 'screens/race_screen.dart';
import 'services/session.dart';
import 'theme.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stop Race',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AuthGate(),
    );
  }
}

/// Swaps between the login and the race screen whenever the session changes.
/// The stored session is read once at start-up so a returning player skips the
/// login form.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    Session.instance.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: Session.instance,
      builder: (context, user, _) {
        if (user == null) return const LoginScreen();
        return RaceScreen(user: user);
      },
    );
  }
}
