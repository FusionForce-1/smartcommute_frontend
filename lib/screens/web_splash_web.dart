// Web: asks web/index.html to fade out its HTML loading screen.

import 'dart:js_interop';

@JS('smartCommuteRemoveSplash')
external JSFunction? get _removeSplash;

void removeWebSplash() {
  // Missing when the page is an older index.html — then there is nothing
  // to remove.
  _removeSplash?.callAsFunction();
}
