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

    _authSubscription ??=
        _googleSignIn.authenticationEvents.listen(_handleAuthEvent);
  }

  Future<String?> signInAndGetIdToken() {
    _tokenCompleter = Completer<String?>();

    return _tokenCompleter!.future;
  }

  void _handleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;

      if (!_tokenCompleter!.isCompleted) {
        _tokenCompleter!.complete(idToken);
      }
    }

    if (event is GoogleSignInAuthenticationEventSignOut) {
      print('Google user signed out.');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}