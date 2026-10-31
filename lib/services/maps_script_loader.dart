// Loads the Google Maps JavaScript API on demand (web only). Mobile embeds
// the Maps SDK natively, so the stub there completes immediately.
export 'maps_script_loader_stub.dart'
    if (dart.library.js_interop) 'maps_script_loader_web.dart';
