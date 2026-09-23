// File generated via flutterfire configure scoped to Android then iOS
// Android: from android/app/google-services.json, iOS: from ios/Runner/GoogleService-Info.plist
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArhdYvFoTSsyREAzH1K1QvTkwC5u9i7y4',
    appId: '1:159697024184:android:e72f6d9e152fce6421f04d',
    messagingSenderId: '159697024184',
    projectId: 'mossaid-app',
    storageBucket: 'mossaid-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwoEDYkEBZaIJCMsqozYYvZYxTaDm4-vw',
    appId: '1:159697024184:ios:cf2df039f7fe7cb421f04d',
    messagingSenderId: '159697024184',
    projectId: 'mossaid-app',
    storageBucket: 'mossaid-app.firebasestorage.app',
    iosBundleId: 'mossaid-app-ios',
  );
}
