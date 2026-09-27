import 'package:flutter/material.dart';
import '../features/home/presentation/home_screen.dart';

class DeutschLernenApp extends StatelessWidget {
  const DeutschLernenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deutsch Lernen',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: const HomeScreen(),
    );
  }
}
