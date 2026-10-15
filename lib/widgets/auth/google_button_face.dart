import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

/// The drawn "Continue with Google" face shared by the web and native
/// GoogleSignInButton implementations.
class GoogleButtonFace extends StatelessWidget {
  const GoogleButtonFace({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Built on OutlinedButton so it inherits the theme's size, padding and
    // corner radius — identical to "Continue as Guest". Only the colours
    // differ.
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: Color(0xFFDADCE0), width: 1.4),
      ),
      // Scales down on narrow phones / large text instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppIcons.googleAsset, width: 24, height: 24),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
