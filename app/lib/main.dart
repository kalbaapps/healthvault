import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/lock_gate.dart';

void main() => runApp(const HealthVaultApp());

class HealthVaultApp extends StatelessWidget {
  const HealthVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C86)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C86),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LockGate(child: HomeScreen()),
    );
  }
}
