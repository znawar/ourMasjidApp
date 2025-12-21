import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:web:7eeb9b9b9b9b9b9b',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    authDomain: 'ourmasjidapp.firebaseapp.com',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:android:4412a70b49d41c7ef7eeb9',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:ios:4412a70b49d41c7ef7eeb9',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
    iosBundleId: 'com.example.masjidconnect',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:ios:4412a70b49d41c7ef7eeb9',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
    iosBundleId: 'com.example.masjidconnect',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:web:7eeb9b9b9b9b9b9b',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCC5E0fkXPW59RVgRqIn4rG6PHY2-GSA68',
    appId: '1:729580665532:web:7eeb9b9b9b9b9b9b',
    messagingSenderId: '729580665532',
    projectId: 'ourmasjidapp',
    storageBucket: 'ourmasjidapp.firebasestorage.app',
  );
}
