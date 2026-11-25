// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

/// One bookable driving slot that the ADMIN creates in the Schedule module.
/// Stored in `schedule_slots`. It holds no personal data, so the public website can read it.
class ScheduleSlot {
  const ScheduleSlot({
    this.id = '',
    required this.startAt,
    required this.durationMinutes,
    required this.location,
    required this.vehicleId,
    required this.vehicleName,
    required this.instructorId,
    required this.instructorName,
    this.courseName = '',
    this.courseDuration = '',
    this.fee = 0,
    this.status = 'available',
    this.bookingId = '',
  });

  final String id;
  final DateTime startAt;
  final int durationMinutes;
  final String location;
  final String vehicleId;
  final String vehicleName;
  final String instructorId;
  final String instructorName;
  final String courseName;
  final String courseDuration;
  final num fee;

  /// available | booked | cancelled | completed
  final String status;
  final String bookingId;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));
  bool get isOpen => status == 'available' && startAt.isAfter(DateTime.now());

  factory ScheduleSlot.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleSlot(
      id: id,
      startAt: (map['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      location: map['location'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      vehicleName: map['vehicleName'] as String? ?? '',
      instructorId: map['instructorId'] as String? ?? '',
      instructorName: map['instructorName'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      courseDuration: map['courseDuration'] as String? ?? '',
      fee: map['fee'] as num? ?? 0,
      status: map['status'] as String? ?? 'available',
      bookingId: map['bookingId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'startAt': Timestamp.fromDate(startAt),
        'durationMinutes': durationMinutes,
        'location': location.trim(),
        'vehicleId': vehicleId,
        'vehicleName': vehicleName,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'courseName': courseName.trim(),
        'courseDuration': courseDuration.trim(),
        'fee': fee,
        'status': status,
        'bookingId': bookingId,
      };
}

/// A student's (or visitor's) booking of one slot. Stored in `slot_bookings`
/// (private: only the school admin and the student who made it can read it).
class SlotBooking {
  const SlotBooking({
    this.id = '',
    required this.slotId,
    required this.name,
    required this.phone,
    this.email = '',
    this.notes = '',
    this.studentUserId = '',
    this.studentId = '',
    this.status = 'pending',
    required this.startAt,
    required this.durationMinutes,
    required this.location,
    required this.vehicleName,
    required this.instructorId,
    required this.instructorName,
    this.courseName = '',
    this.lessonId = '',
    this.createdAt,
  });

  final String id;
  final String slotId;
  final String name;
  final String phone;
  final String email;
  final String notes;

  /// Login uid of the student ('' for a visitor without a login).
  final String studentUserId;

  /// Document id in `students` ('' when the booker is not registered yet).
  final String studentId;

  /// pending | confirmed | cancelled
  final String status;
  final DateTime startAt;
  final int durationMinutes;
  final String location;
  final String vehicleName;
  final String instructorId;
  final String instructorName;
  final String courseName;
  final String lessonId;
  final DateTime? createdAt;

  factory SlotBooking.fromMap(String id, Map<String, dynamic> map) {
    return SlotBooking(
      id: id,
      slotId: map['slotId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      studentUserId: map['studentUserId'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      startAt: (map['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      location: map['location'] as String? ?? '',
      vehicleName: map['vehicleName'] as String? ?? '',
      instructorId: map['instructorId'] as String? ?? '',
      instructorName: map['instructorName'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      lessonId: map['lessonId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
