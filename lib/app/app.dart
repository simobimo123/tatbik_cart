import 'package:flutter/material.dart';
import '../features/home/presentation/home_screen.dart';

class DeutschLernenApp extends StatelessWidget {
  const DeutschLernenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF5B5FEF);
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      secondary: const Color(0xFF16B8A6),
      surface: const Color(0xFFF7F8FC),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deutsch Lernen',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8FC),
          foregroundColor: Color(0xFF171A2A),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE9EAF2)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5E7EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
