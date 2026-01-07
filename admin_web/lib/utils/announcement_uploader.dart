// Conditional export so that web platforms use the dart:html-based
// implementation, and other platforms (Android/iOS/desktop) use a
// safe stub that simply returns null.

export 'announcement_uploader_stub.dart'
    if (dart.library.html) 'announcement_uploader_web.dart';
