import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_button_face.dart';

/// "Continue with Google" button for Android/iOS.
///
/// Unlike web, native platforms support authenticate(), so the drawn button
/// starts sign-in itself. authenticate() reports both success and failure
/// on GoogleSignIn.instance.authenticationEvents, which GoogleAuthService
/// already listens to — so the result reaches app_router the same way the
/// web popup's does, and nothing needs handling here.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.height = 52});

  /// Visual height of the button; the Login mockup uses ~35.
  final double height;

  Future<void> _signIn() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      // Already forwarded to the authenticationEvents stream.
      debugPrint('GoogleSignIn.authenticate() failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GoogleButtonFace(onPressed: _signIn),
    );
  }
}
