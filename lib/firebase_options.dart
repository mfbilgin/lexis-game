// File generated based on Firebase console configuration
// Project: lexis-2026

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA3QBVCd4V2BVLBAKbp18K7VWsG8DHEzuo',
    appId: '1:298358456490:android:04e59d8cecd11109c290d3',
    messagingSenderId: '298358456490',
    projectId: 'lexis-2026',
    storageBucket: 'lexis-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB1LH5rY01O-qyX-Zz_8miTrG1r2Rm36So',
    appId: '1:298358456490:ios:7a903e935d5b89c1c290d3',
    messagingSenderId: '298358456490',
    projectId: 'lexis-2026',
    storageBucket: 'lexis-2026.firebasestorage.app',
    iosBundleId: 'com.mfbilgin.lexis',
  );
}
