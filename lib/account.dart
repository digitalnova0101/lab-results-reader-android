import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';
import 'state.dart';

/// Optional "Sign in with Google": keeps the plan and saved summaries on every device.
class Account {
  static String _ready = '';

  static Future<void> _init(String clientId) async {
    if (_ready == clientId) return;
    // serverClientId = the Web client ID, so Google gives us an ID token our server can check.
    await GoogleSignIn.instance.initialize(serverClientId: clientId);
    _ready = clientId;
  }

  /// Returns an error message, or null when signed in (or the person closed the Google sheet).
  static Future<String?> signIn() async {
    final s = AppState.I;
    if (s.googleClientId.isEmpty) await s.syncStatus();
    if (s.googleClientId.isEmpty) return "Sign in with Google isn't available yet.";
    try {
      await _init(s.googleClientId);
      final user = await GoogleSignIn.instance.authenticate();
      final idToken = user.authentication.idToken;
      if (idToken == null || idToken.isEmpty) return "Google didn't confirm your sign-in. Please try again.";
      final d = await Api.post({'action': 'signin', 'id_token': idToken});
      final st = d['status'];
      s.setAuth('${d['auth']}', st is Map ? st['account'] : null);
      s.saveHistory = true;
      // Summaries already on this phone go up to the account too.
      for (final e in s.history) {
        if (!s.pendingUp.contains(e.id)) s.pendingUp.add(e.id);
      }
      s.applyStatus(st);
      await s.syncHistory();
      return null;
    } on GoogleSignInException catch (e) {
      final why = (e.description ?? '').trim();
      if (e.code == GoogleSignInExceptionCode.canceled && (why.isEmpty || why.toLowerCase().contains('cancelled by the user'))) {
        return 'Sign-in was canceled.';
      }
      return "Google sign-in didn't work. Please try again. (${e.code.name}${why.isNotEmpty ? ': $why' : ''})";
    } on ApiError catch (e) {
      return errorText(e);
    } catch (e) {
      return "Google sign-in didn't work. Please try again.";
    }
  }

  static Future<void> signOut() async {
    try {
      final d = await Api.post({'action': 'signout'});
      AppState.I.signedOutLocally();
      AppState.I.applyStatus(d['status']);
    } catch (_) {
      AppState.I.signedOutLocally();
      AppState.I.syncStatus();
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Returns an error message, or null when the account was deleted.
  static Future<String?> deleteAccount() async {
    try {
      final d = await Api.post({'action': 'delete_account'});
      AppState.I.signedOutLocally();
      AppState.I.applyStatus(d['status']);
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
      return null;
    } on ApiError catch (e) {
      return errorText(e);
    }
  }
}
