import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_button_face.dart';

/// "Continue with Google" button for Android/iOS.
///
/// Unlike web, native platforms support authenticate(), so the drawn button
/// starts sign-in itself. A successful sign-in arrives on
/// GoogleSignIn.instance.authenticationEvents, which GoogleAuthService
/// already listens to — so it reaches app_router the same way the web
/// popup's does. A failure (other than the user cancelling) is shown here.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.height = 52});

  /// Visual height of the button; the Login mockup uses ~35.
  final double height;

  Future<void> _signIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      messenger?.showSnackBar(SnackBar(
        content: Text('Google sign-in failed: ${e.description ?? e.code.name}'),
      ));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GoogleButtonFace(onPressed: () => _signIn(context)),
    );
  }
}
