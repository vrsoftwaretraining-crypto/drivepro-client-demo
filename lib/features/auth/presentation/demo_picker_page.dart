// Developed by @Ramana Code Softwares
//
// DEMO build only: first page. Open any part of DrivePro without a login or a server.

import 'package:flutter/material.dart';

class DemoPickerPage extends StatelessWidget {
  const DemoPickerPage({required this.onPick, super.key});

  /// 'admin' | 'instructor' | 'student' | 'public'
  final void Function(String view) onPick;

  static const _plum = Color(0xFF5C1738);
  static const _gold = Color(0xFFE4AE45);

  @override
  Widget build(BuildContext context) {
    Widget option(String label, String hint, IconData icon, String view, {bool primary = true}) {
      final child = Row(children: [
        Icon(icon, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(hint, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ]),
        ),
        const Icon(Icons.arrow_forward_rounded),
      ]);
      final pad = const EdgeInsets.symmetric(vertical: 14, horizontal: 18);
      return primary
          ? FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _plum, padding: pad, alignment: Alignment.centerLeft),
              onPressed: () => onPick(view),
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: _plum, padding: pad, alignment: Alignment.centerLeft, side: const BorderSide(color: _plum)),
              onPressed: () => onPick(view),
              child: child,
            );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.directions_car_filled_rounded, color: _plum, size: 54),
                const SizedBox(height: 8),
                const Text('DrivePro',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 38, fontWeight: FontWeight.bold, color: _plum)),
                const Text('DRIVING SCHOOL',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _gold, letterSpacing: 4, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 14),
                const Text('Preview with sample data. No login needed, nothing is saved.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 28),
                option('View as Admin', 'Students, payments, reports, settings', Icons.admin_panel_settings_outlined, 'admin'),
                const SizedBox(height: 12),
                option('View as Instructor', 'My lessons, students, attendance', Icons.badge_outlined, 'instructor'),
                const SizedBox(height: 12),
                option('View as Student', 'My lessons, payments, certificate', Icons.school_outlined, 'student'),
                const SizedBox(height: 12),
                option('Public website', 'Home page, slot booking, enquiry', Icons.public, 'public', primary: false),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
