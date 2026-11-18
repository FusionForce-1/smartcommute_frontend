// Web splash web
import 'dart:js_interop';

@JS('smartCommuteRemoveSplash')
external JSFunction? get _removeSplash;

/// Remove web splash
void removeWebSplash() {
  _removeSplash?.callAsFunction();
}
