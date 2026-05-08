import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class NastroiApp extends StatelessWidget {
  const NastroiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Настрой',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        fontFamily: null,
      ),
      home: const HomeScreen(),
    );
  }
}