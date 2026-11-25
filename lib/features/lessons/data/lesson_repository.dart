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
    final lessonRef = _collection.doc(id);
    final snapshot = await lessonRef.get();
    if (!snapshot.exists) throw StateError('Lesson was not found.');
    final data = snapshot.data()!;
    final batch = _db.batch();
    batch.update(lessonRef, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // A cancelled lesson must release both resources so the public slot board
    // can offer the time again. Completed lessons remain historical records.
    if (status == 'cancelled') {
      final startAt = (data['startAt'] as Timestamp?)?.toDate();
      final instructorId = data['instructorId'] as String? ?? '';
      final vehicleId = data['vehicleId'] as String? ?? '';
      if (startAt != null) {
        final milliseconds = startAt.toUtc().millisecondsSinceEpoch;
        if (instructorId.isNotEmpty) {
          batch.delete(_db.collection('booking_slots').doc('${instructorId}_$milliseconds'));
        }
        if (vehicleId.isNotEmpty) {
          batch.delete(_db.collection('booking_slots').doc('v_${vehicleId}_$milliseconds'));
        }
      }
    }
    await batch.commit();
  }
}
