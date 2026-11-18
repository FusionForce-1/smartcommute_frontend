// Google signin button native
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_button_face.dart';

/// Google sign in button
class GoogleSignInButton extends StatelessWidget {
  /// Create Google sign in
  const GoogleSignInButton({super.key, this.height = 52});

  final double height;

  /// Sign in
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

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GoogleButtonFace(onPressed: () => _signIn(context)),
    );
  }
}
