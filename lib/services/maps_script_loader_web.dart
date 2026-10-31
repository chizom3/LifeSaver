import 'dart:js_interop';

// Defined in web/maps_loader.js.
@JS('medimapLoadGoogleMaps')
external JSPromise<JSAny?> _loadGoogleMaps();

Future<void> ensureMapsScriptLoaded() async {
  await _loadGoogleMaps().toDart;
}
