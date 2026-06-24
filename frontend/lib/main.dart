import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PreguntaleApp());
}

class PreguntaleApp extends StatelessWidget {
  const PreguntaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pregúntale a tu plata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF161B22),
          primary: Color(0xFF00C896),
          onPrimary: Color(0xFF0D1117),
          secondary: Color(0xFF238636),
          onSurface: Color(0xFFE6EDF3),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00C896), width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFF8B949E)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
