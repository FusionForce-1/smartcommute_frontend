// lib/widgets/auth/google_signin_button.dart
//
// NOT one of the 11 official E3 reusable widgets — screen-composition helper
// for the "Continue with Google" button shown on Login and Register.
//
// This widget only renders the button and fires [onPressed]. The actual
// google_sign_in flow + POST /auth/google call belongs to Francis
// (F1 ApiService.loginWithGoogle / F3 AuthProvider.loginWithGoogle) — see the
// TODO markers in the screens that use this button.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "G" glyph approximation so this widget needs no image asset.
          // Swap for the official Google "G" logo asset if brand guidelines require it.
          Text(
            'G',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4285F4),
            ),
          ),
          SizedBox(width: 10),
          Text('Continue with Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
