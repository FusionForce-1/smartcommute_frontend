// Google signin button web
import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import 'google_button_face.dart';

/// Google sign in button
class GoogleSignInButton extends StatelessWidget {
  /// Create Google sign in
  const GoogleSignInButton({super.key, this.height = 52});

  final double height;

  static const double _googleHeight = 40;
  static const double _googleMaxWidth = 400;

  static const double _overlayOpacity = 0.01;

  /// Build the widget
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
                child: GoogleButtonFace(onPressed: () {}),
              ),
              Opacity(
                opacity: _overlayOpacity,
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
