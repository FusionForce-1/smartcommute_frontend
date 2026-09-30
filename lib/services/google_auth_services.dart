import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<GoogleSignInAuthenticationEvent>?
      _authSubscription;

  Completer<String?>? _tokenCompleter;

  Future<void> initialize() async {
    await _googleSignIn.initialize();

    _authSubscription ??= _googleSignIn.authenticationEvents.listen(
      _handleAuthEvent,
      // Google reports popup-closed, origin-not-allowed, etc. as stream
      // errors. Without this handler they were uncaught and the waiting
      // caller never heard back.
      onError: _handleAuthError,
    );
  }

  Future<String?> signInAndGetIdToken() {
    // Reuse a pending request instead of replacing it — replacing it
    // would leave the earlier caller waiting forever.
    final pending = _tokenCompleter;
    if (pending != null && !pending.isCompleted) return pending.future;

    _tokenCompleter = Completer<String?>();
    return _tokenCompleter!.future;
  }

  void _handleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;
      final completer = _tokenCompleter;

      if (completer != null && !completer.isCompleted) {
        if (idToken == null) {
          completer.completeError(
            const GoogleSignInException(
              code: GoogleSignInExceptionCode.unknownError,
              description: 'Google did not return an ID token.',
            ),
          );
        } else {
          completer.complete(idToken);
        }
      }
    }

    if (event is GoogleSignInAuthenticationEventSignOut) {
      print('Google user signed out.');
    }
  }

  void _handleAuthError(Object error) {
    final completer = _tokenCompleter;
    if (completer == null || completer.isCompleted) return;

    // User closing the popup isn't an error worth showing.
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      completer.complete(null);
    } else {
      completer.completeError(error);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}