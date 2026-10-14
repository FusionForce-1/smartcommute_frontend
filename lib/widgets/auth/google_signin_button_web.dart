import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import 'google_button_face.dart';

/// "Continue with Google" button drawn to the auth-screen design:
/// white, thin grey outline, G logo beside Poppins text, full width.
///
/// On web the sign-in popup can only be opened by Google's own rendered
/// button (google_sign_in v7 has no authenticate() on web), and that button
/// can't be restyled. So the design is drawn in Flutter and Google's button
/// sits on top of it, nearly transparent, to receive the click. The result
/// arrives through GoogleAuthService's event stream as before.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.height = 52});

  /// Visual height of the button; the Login mockup uses ~35.
  final double height;

  /// Google renders its "large" button 40px tall and at most 400px wide.
  static const double _googleHeight = 40;
  static const double _googleMaxWidth = 400;

  /// Not 0 — a fully transparent Opacity skips painting its child, which
  /// would remove Google's button from the page and make it unclickable.
  static const double _overlayOpacity = 0.01;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final googleWidth = width.clamp(200.0, _googleMaxWidth);
        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                // Taps never reach it (Google's overlay takes them), but a
                // non-null onPressed keeps it from rendering disabled.
                child: GoogleButtonFace(onPressed: () {}),
              ),
              Opacity(
                opacity: _overlayOpacity,
                // Stretch Google's 40px button to cover the full 52px face.
                child: Transform.scale(
                  scaleX: width / googleWidth,
                  scaleY: height / _googleHeight,
                  child: SizedBox(
                    height: _googleHeight,
                    width: googleWidth,
                    child: web.renderButton(
                      configuration: web.GSIButtonConfiguration(
                        type: web.GSIButtonType.standard,
                        theme: web.GSIButtonTheme.outline,
                        size: web.GSIButtonSize.large,
                        text: web.GSIButtonText.continueWith,
                        shape: web.GSIButtonShape.rectangular,
                        minimumWidth: googleWidth,
                        locale: 'en',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
