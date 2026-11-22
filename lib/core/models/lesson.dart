// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class DrivingLesson {
  const DrivingLesson({
    this.id = '',
    required this.studentId,
    required this.studentName,
    required this.instructorId,
    required this.instructorName,
    required this.vehicleId,
    required this.vehicleRegistration,
    required this.startAt,
    required this.durationMinutes,
    this.notes = '',
    this.status = 'scheduled',
  });

  final String id;
  final String studentId;
  final String studentName;
  final String instructorId;
  final String instructorName;
  final String vehicleId;
  final String vehicleRegistration;
  final DateTime startAt;
  final int durationMinutes;
  final String notes;
  final String status;

  factory DrivingLesson.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['startAt'] as Timestamp?;
    return DrivingLesson(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      instructorId: map['instructorId'] as String? ?? '',
      instructorName: map['instructorName'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      vehicleRegistration: map['vehicleRegistration'] as String? ?? '',
      startAt: timestamp?.toDate() ?? DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'vehicleId': vehicleId,
        'vehicleRegistration': vehicleRegistration,
        'startAt': Timestamp.fromDate(startAt),
        'durationMinutes': durationMinutes,
        'notes': notes.trim(),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
