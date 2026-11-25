// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/school_service.dart';
import '../../../core/services/backend.dart';

/// One bookable time window on a given day (all times are India time, IST).
class SlotWindow {
  const SlotWindow({
    required this.startUtc,
    required this.minutes,
    required this.startMinuteOfDay,
  });

  final DateTime startUtc;
  final int minutes;
  final int startMinuteOfDay;

  DateTime get endUtc => startUtc.add(Duration(minutes: minutes));

  static String _fmt(int minuteOfDay) {
    final h24 = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ap = h24 >= 12 ? 'PM' : 'AM';
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ap';
  }

  String get label =>
      '${_fmt(startMinuteOfDay)} – ${_fmt(startMinuteOfDay + minutes)}';
}

enum SlotState { available, booked, past, notWorking }

class PublicCatalog {
  PublicCatalog({
    required this.vehicles,
    required this.instructors,
    required this.occupied,
    required this.school,
  });

  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> instructors;
  List<Map<String, dynamic>> occupied;
  final Map<String, dynamic> school;

  static const _istOffset = Duration(hours: 5, minutes: 30);

  /// Reads the public mirrors straight from Firestore (no Cloud Functions).
  static Future<PublicCatalog> load() async {
    final db = Backend.firestore;
    final results = await Future.wait([
      db.collection('public_vehicles').where('active', isEqualTo: true).get(),
      db.collection('public_instructors').where('active', isEqualTo: true).get(),
      db.collection('public_info').doc('school').get(),
      db
          .collection('booking_slots')
          .where('startAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
          .get(),
    ]);
    List<Map<String, dynamic>> docs(Object q) => (q as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList();
    final slotDocs = (results[3] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map((d) => d.data());
    return PublicCatalog(
      vehicles: docs(results[0]),
      instructors: docs(results[1]),
      occupied: SchoolService.parseOccupied(slotDocs),
      school: (results[2] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {},
    );
  }

  /// How many slots this instructor already has on the given IST date.
  int loadOn(Map<String, dynamic> instructor, DateTime date) {
    var n = 0;
    for (final item in occupied) {
      if (item['instructorId'] != instructor['id']) continue;
      final start = DateTime.tryParse(item['startAt'] as String? ?? '');
      if (start == null) continue;
      final ist = start.add(_istOffset);
      if (ist.year == date.year && ist.month == date.month && ist.day == date.day) n++;
    }
    return n;
  }

  /// "Any instructor" mode: every instructor free for this slot.
  List<Map<String, dynamic>> freeInstructors(SlotWindow slot) => [
        for (final i in instructors)
          if (stateOf(i, slot) == SlotState.available) i,
      ];

  String get schoolName =>
      (school['name'] as String?)?.trim().isNotEmpty == true
          ? school['name'] as String
          : 'DrivePro Driving School';
  String get phone => school['phone'] as String? ?? '';
  String get location => school['location'] as String? ?? '';
  String get address => school['address'] as String? ?? '';
  String get mapUrl => school['mapUrl'] as String? ?? '';
  String get notes => school['notes'] as String? ?? '';

  int _clock(String? raw, int fallback) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch((raw ?? '').trim());
    if (m == null) return fallback;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  int get slotMinutes => (school['slotMinutes'] as num?)?.toInt() ?? 120;

  /// Slots for a calendar date, e.g. 06:00-08:00 ... 18:00-20:00 for 2-hour slots.
  List<SlotWindow> slotsFor(DateTime date) {
    final open = _clock(school['openTime'] as String?, 6 * 60);
    final close = _clock(school['closeTime'] as String?, 20 * 60);
    final len = slotMinutes <= 0 ? 120 : slotMinutes;
    final out = <SlotWindow>[];
    for (var start = open; start + len <= close; start += len) {
      final istMidnightUtc =
          DateTime.utc(date.year, date.month, date.day).subtract(_istOffset);
      out.add(SlotWindow(
        startUtc: istMidnightUtc.add(Duration(minutes: start)),
        minutes: len,
        startMinuteOfDay: start,
      ));
    }
    return out;
  }

  int get slotsPerDay => slotsFor(DateTime.now()).length;

  Map<String, dynamic>? vehicleOf(Map<String, dynamic> instructor) {
    final id = instructor['assignedVehicleId'] as String? ?? '';
    for (final v in vehicles) {
      if (v['id'] == id) return v;
    }
    return null;
  }

  Map<String, dynamic>? instructorOfVehicle(Map<String, dynamic> vehicle) {
    for (final i in instructors) {
      if (i['assignedVehicleId'] == vehicle['id']) return i;
    }
    return null;
  }

  bool _worksOn(Map<String, dynamic> instructor, SlotWindow slot) {
    final days = (instructor['workingDays'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase())
        .toList();
    if (days.isNotEmpty) {
      final ist = slot.startUtc.add(_istOffset);
      const names = [
        'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday',
        'saturday',
      ];
      final name = names[ist.weekday % 7];
      if (!days.any((d) => d == name || d == name.substring(0, 3))) {
        return false;
      }
    }
    final raw = (instructor['workingHours'] as String? ?? '').trim();
    final parts = raw.split(RegExp(r'\s*-\s*'));
    if (parts.length == 2) {
      final a = _parseClock(parts[0]);
      final b = _parseClock(parts[1]);
      if (a != null && b != null) {
        return slot.startMinuteOfDay >= a &&
            slot.startMinuteOfDay + slot.minutes <= b;
      }
    }
    return true;
  }

  int? _parseClock(String value) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false)
        .firstMatch(value.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = (m.group(3) ?? '').toUpperCase();
    if (ap.isNotEmpty) h = h % 12 + (ap == 'PM' ? 12 : 0);
    return h * 60 + min;
  }

  SlotState stateOf(Map<String, dynamic> instructor, SlotWindow slot) {
    if (!slot.startUtc.isAfter(DateTime.now().toUtc())) return SlotState.past;
    if (!_worksOn(instructor, slot)) return SlotState.notWorking;
    final vehicleId = instructor['assignedVehicleId'] as String? ?? '';
    for (final item in occupied) {
      final start = DateTime.tryParse(item['startAt'] as String? ?? '');
      if (start == null) continue;
      final mins = (item['durationMinutes'] as num?)?.toInt() ?? 60;
      final end = start.add(Duration(minutes: mins));
      final overlaps = slot.startUtc.isBefore(end) && start.isBefore(slot.endUtc);
      if (!overlaps) continue;
      if (item['instructorId'] == instructor['id'] ||
          (vehicleId.isNotEmpty && item['vehicleId'] == vehicleId)) {
        return SlotState.booked;
      }
    }
    return SlotState.available;
  }

  /// Total slots for one day across all instructors, and how many are free.
  ({int total, int free}) summaryFor(DateTime date) {
    final slots = slotsFor(date);
    var free = 0;
    for (final i in instructors) {
      for (final s in slots) {
        if (stateOf(i, s) == SlotState.available) free++;
      }
    }
    return (total: slots.length * instructors.length, free: free);
  }
}
