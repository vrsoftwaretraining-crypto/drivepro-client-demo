// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/models/schedule_slot.dart';

String fmtDay(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);
String fmtRange(ScheduleSlot s) => '${fmtTime(s.startAt)} – ${fmtTime(s.endAt)}';
String fmtDuration(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60} hr' : (minutes > 60 ? '${minutes ~/ 60} hr ${minutes % 60} min' : '$minutes min');

Color statusColor(String status) {
  switch (status) {
    case 'available':
      return const Color(0xFF1B8A5A);
    case 'booked':
    case 'pending':
      return const Color(0xFFE07A00);
    case 'confirmed':
    case 'completed':
      return const Color(0xFF2F5BD3);
    default:
      return const Color(0xFF8A8F9C);
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Available';
    case 'booked':
      return 'Booked';
    case 'pending':
      return 'Awaiting confirmation';
    case 'confirmed':
      return 'Confirmed';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(statusLabel(status), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// "Label: value" row with an icon, used in slot and booking cards.
class InfoLine extends StatelessWidget {
  const InfoLine(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ]),
    );
  }
}
