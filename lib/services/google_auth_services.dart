// Google auth services
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../config/env_config.dart';

/// Google auth service
class GoogleAuthService {
  /// Create Google auth
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<GoogleSignInAuthenticationEvent>?
      _authSubscription;

  Completer<String?>? _tokenCompleter;

  /// Google auth initialize
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId: kIsWeb ? null : EnvConfig.googleWebClientId,
    );

    _authSubscription ??= _googleSignIn.authenticationEvents.listen(
      _handleAuthEvent,
      onError: _handleAuthError,
    );
  }

  /// Sign get ID token
  Future<String?> signInAndGetIdToken() {
    final pending = _tokenCompleter;
    if (pending != null && !pending.isCompleted) return pending.future;

    _tokenCompleter = Completer<String?>();
    return _tokenCompleter!.future;
  }

  /// Handle auth event
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
  }

  /// Handle auth error
  void _handleAuthError(Object error) {
    final completer = _tokenCompleter;
    if (completer == null || completer.isCompleted) return;

    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      completer.complete(null);
    } else {
      completer.completeError(error);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}