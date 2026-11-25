// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'core/demo/demo_backend.dart';
import 'core/services/backend.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class DriveProApp extends StatelessWidget {
  const DriveProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DrivePro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: demoMode ? (context, child) => Column(children: [const _DemoBar(), Expanded(child: child ?? const SizedBox.shrink())]) : null,
      home: const AuthGate(),
    );
  }
}

/// Thin strip shown only in the DEMO build: tells the viewer how to sign in to each role.
class _DemoBar extends StatelessWidget {
  const _DemoBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE9B8),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            'CLIENT DEMO • Sample data only • Choose Admin, Instructor, Student or Public Website on the start screen. No credentials required.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A3300)),
          ),
        ),
      ),
    );
  }
}
