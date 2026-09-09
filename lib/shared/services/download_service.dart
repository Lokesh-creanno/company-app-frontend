// Cross-platform file save/download.
// Picks the web (dart:html blob download) or io (temp file + OpenFile) impl.
export 'download_io.dart' if (dart.library.html) 'download_web.dart';
