// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/lesson.dart';

class LessonRepository {
  LessonRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('lessons');

  Stream<List<DrivingLesson>> watchLessons() =>
      _collection.orderBy('startAt').snapshots().map((snapshot) => snapshot.docs
          .map((doc) => DrivingLesson.fromMap(doc.id, doc.data()))
          .toList(),);

  Future<void> add(DrivingLesson lesson) async {
    final batch = _db.batch();
    batch.set(_collection.doc(), {
      ...lesson.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Show the lesson as BOOKED on the public slot board too.
    if (lesson.instructorId.isNotEmpty) {
      final ms = lesson.startAt.toUtc().millisecondsSinceEpoch;
      final data = {
        'instructorId': lesson.instructorId,
        'vehicleId': lesson.vehicleId,
        'startAt': Timestamp.fromDate(lesson.startAt),
        'durationMinutes': lesson.durationMinutes,
        'status': 'booked',
      };
      batch.set(_db.collection('booking_slots').doc('${lesson.instructorId}_$ms'),
          {...data, 'kind': 'instructor'});
      if (lesson.vehicleId.isNotEmpty) {
        batch.set(_db.collection('booking_slots').doc('v_${lesson.vehicleId}_$ms'),
            {...data, 'kind': 'vehicle'});
      }
    }
    await batch.commit();
  }

  Future<void> updateStatus(String id, String status) async {
    await _collection.doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
