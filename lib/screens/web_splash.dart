// lib/screens/web_splash.dart
//
// On web, web/index.html shows the loading screen in HTML from the very
// first moment and keeps it up until the app is ready, so commuters see
// ONE loading screen instead of the HTML one swapping for Flutter's.
// Native apps have no HTML page, so there it does nothing.
export 'web_splash_stub.dart' if (dart.library.js_interop) 'web_splash_web.dart';
