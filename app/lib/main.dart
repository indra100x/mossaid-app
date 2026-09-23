import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/phone_input_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ignore: avoid_print
  print('Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Foreground + background tap handlers registered early; permission is requested on login (Android 13+)
  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    // ignore: avoid_print
    print('FCM onMessage foreground: ${m.messageId} ${m.notification?.title}');
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    // ignore: avoid_print
    print('FCM onMessageOpenedApp tapped: ${m.messageId}');
  });
  // Terminated -> opened via notification
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? m) {
    if (m != null) {
      // ignore: avoid_print
      print('FCM getInitialMessage terminated: ${m.messageId}');
    }
  });
  runApp(const MossaidApp());
}

class MossaidApp extends StatelessWidget {
  const MossaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mossaid',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      locale: const Locale('fr'),
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const PhoneInputScreen(),
    );
  }
}
