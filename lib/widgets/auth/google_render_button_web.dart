import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: Google's own rendered button, the only thing that can open the
/// sign-in popup on web (google_sign_in v7 has no authenticate() there).
Widget? renderGoogleButton(double width) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.continueWith,
      shape: web.GSIButtonShape.rectangular,
      minimumWidth: width,
      locale: 'en',
    ),
  );
}
