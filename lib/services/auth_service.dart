import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Local, single account authentication backed by shared preferences.
///
/// The first successful sign-in creates the account; every later sign-in must
/// match the stored credentials. The balance lives here too so it survives an
/// app restart.
class AuthService {
  static const String _usernameKey = 'auth.username';
  static const String _balanceKey = 'auth.balance';
  static const String _sessionKey = 'auth.session';
  static const String _saltKey = 'auth.salt';

  static const double startingBalance = 1000.0;
  static const int minPasswordLength = 4;

  /// Obfuscated password storage: enough to keep a plain password out of the
  /// preference file without pretending to be real cryptography.
  static String _obfuscate(String value) {
    final salt = value.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff);
    final mixed = value.codeUnits.fold<int>(
      salt,
      (a, b) => ((a * 33) ^ (b + 7)) & 0x7fffffff,
    );
    return '$salt.$mixed';
  }

  static Future<bool> accountExists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey) != null;
  }

  /// Returns the signed-in user, or null when the credentials do not match.
  /// On a fresh install the first call registers the account instead.
  static Future<User?> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final name = username.trim();

    if (name.isEmpty || password.length < minPasswordLength) return null;

    final storedName = prefs.getString(_usernameKey);
    final storedHash = prefs.getString(_saltKey);

    if (storedName == null) {
      await prefs.setString(_usernameKey, name);
      await prefs.setString(_saltKey, _obfuscate(password));
      await prefs.setDouble(_balanceKey, startingBalance);
      return _persistSession(name);
    }

    if (storedName != name || storedHash != _obfuscate(password)) return null;
    return _persistSession(name);
  }

  static Future<User> _persistSession(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, name);
    final balance = prefs.getDouble(_balanceKey) ?? startingBalance;
    return User(username: name, balance: balance);
  }

  /// Restores the user of the previous session, or null when signed out.
  static Future<User?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_sessionKey);
    if (name == null) return null;
    if (prefs.getString(_usernameKey) != name) {
      await prefs.remove(_sessionKey);
      return null;
    }
    return User(
      username: name,
      balance: prefs.getDouble(_balanceKey) ?? startingBalance,
    );
  }

  static Future<void> saveBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = balance < 0 ? 0.0 : double.parse(balance.toStringAsFixed(2));
    await prefs.setDouble(_balanceKey, safe);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Wipes the account, balance included. Used by the reset action.
  static Future<void> resetAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_saltKey);
    await prefs.remove(_balanceKey);
    await prefs.remove(_sessionKey);
  }
}
