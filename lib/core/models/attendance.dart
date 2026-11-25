// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class LessonAttendance {
  const LessonAttendance(
      {required this.id,
      required this.lessonId,
      required this.studentId,
      required this.studentName,
      required this.instructorName,
      required this.lessonAt,
      required this.status,
      this.notes = '',
      this.studentUserId = '',
      this.instructorUserId = '',});
  final String id,
      lessonId,
      studentId,
      studentName,
      instructorName,
      status,
      notes;
  final String studentUserId, instructorUserId;
  final DateTime lessonAt;
  factory LessonAttendance.fromMap(String id, Map<String, dynamic> map) =>
      LessonAttendance(
          id: id,
          lessonId: map['lessonId'] as String? ?? '',
          studentId: map['studentId'] as String? ?? '',
          studentName: map['studentName'] as String? ?? '',
          instructorName: map['instructorName'] as String? ?? '',
          lessonAt: (map['lessonAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: map['status'] as String? ?? 'present',
          notes: map['notes'] as String? ?? '',
          studentUserId: map['studentUserId'] as String? ?? '',
          instructorUserId: map['instructorUserId'] as String? ?? '',);
  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'studentId': studentId,
        'studentName': studentName,
        'instructorName': instructorName,
        'lessonAt': Timestamp.fromDate(lessonAt),
        'status': status,
        'notes': notes,
        'studentUserId': studentUserId,
        'instructorUserId': instructorUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
