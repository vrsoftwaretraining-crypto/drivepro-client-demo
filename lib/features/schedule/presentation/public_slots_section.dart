// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';

import 'slot_board.dart';

/// Landing-page section: the live slot list, location wise. Anyone can book without a login.
/// It reads the same `schedule_slots` the admin edits, so it updates on its own when the admin adds,
/// edits or cancels a slot or when a student books one.
class PublicSlotsSection extends StatelessWidget {
  const PublicSlotsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF1DC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available driving slots', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2C2430))),
              SizedBox(height: 6),
              Text(
                'Pick your location, choose a time and book. Slots update live, and the school confirms your booking.',
                style: TextStyle(fontSize: 15, color: Color(0xFF5A4F5E)),
              ),
              SizedBox(height: 20),
              SlotBoard(),
            ],
          ),
        ),
      ),
    );
  }
}
