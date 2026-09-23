// File generated via manual extraction from android/app/google-services.json
// Scoped to Android only per instructions — iOS will be added after GoogleService-Info.plist
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform - '
      'you can reconfigure this by running the FlutterFire CLI again.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArhdYvFoTSsyREAzH1K1QvTkwC5u9i7y4',
    appId: '1:159697024184:android:e72f6d9e152fce6421f04d',
    messagingSenderId: '159697024184',
    projectId: 'mossaid-app',
    storageBucket: 'mossaid-app.firebasestorage.app',
  );
}
