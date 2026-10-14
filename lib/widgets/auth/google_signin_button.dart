// The web button depends on google_sign_in_web (dart:js_interop /
// dart:ui_web), which doesn't exist on Android/iOS and breaks the native
// build. Pick the implementation per platform at compile time.
export 'google_signin_button_native.dart'
    if (dart.library.js_interop) 'google_signin_button_web.dart';
