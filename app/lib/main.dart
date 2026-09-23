import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/phone_input_screen.dart';

void main() {
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
