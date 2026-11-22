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
          .toList());

  Future<void> add(DrivingLesson lesson) async {
    await _collection.add({
      ...lesson.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus(String id, String status) async {
    await _collection.doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
