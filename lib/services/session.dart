import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'auth_service.dart';

/// Holds the signed-in user for the whole app so the root widget can swap
/// between the login and the race screen without pushing routes.
class Session extends ValueNotifier<User?> {
  Session() : super(null);

  static final Session instance = Session();

  Future<void> restore() async {
    value = await AuthService.currentUser();
  }

  void signIn(User user) {
    value = user;
  }

  Future<void> signOut() async {
    await AuthService.logout();
    value = null;
  }

  Future<void> resetAccount() async {
    await AuthService.resetAccount();
    value = null;
  }
}
