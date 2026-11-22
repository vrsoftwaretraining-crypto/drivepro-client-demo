// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception_handler.dart';
import '../../../core/models/attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this.db);

  final FirebaseFirestore db;

  Stream<List<LessonAttendance>> watch() => db
      .collection('attendance')
      .orderBy('lessonAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => LessonAttendance.fromMap(doc.id, doc.data()))
          .toList());

  Future<void> save(LessonAttendance item) => AppExceptionHandler.guard(
        'Unable to save attendance',
        () async {
          final ref = db.collection('attendance').doc(item.lessonId);
          await ref.set(
            {...item.toMap(), 'createdAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
        },
        tag: 'AttendanceRepository',
      );
}
