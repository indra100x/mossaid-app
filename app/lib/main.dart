import 'package:flutter/material.dart';

void main() {
  runApp(const MossaidApp());
}

class MossaidApp extends StatelessWidget {
  const MossaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mossaid',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mossaid'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Mossaid — Marketplace Skeleton'),
            SizedBox(height: 8),
            Text('Flutter app ready for Phase 0'),
          ],
        ),
      ),
    );
  }
}
