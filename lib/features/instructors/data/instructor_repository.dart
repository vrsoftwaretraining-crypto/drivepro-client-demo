// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/instructor.dart';

class InstructorRepository {
  InstructorRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('instructors');

  Stream<List<Instructor>> watchAll() =>
      _collection.orderBy('name').snapshots().map((snapshot) => snapshot.docs
          .map((doc) => Instructor.fromMap(doc.id, doc.data()))
          .toList());

  Future<void> add(Instructor instructor) async {
    await _collection.add({
      ...instructor.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(Instructor instructor) async {
    if (instructor.id.isEmpty) {
      throw ArgumentError('Instructor ID is required.');
    }
    await _collection.doc(instructor.id).update(instructor.toMap());
  }

  Future<void> archive(String id) async {
    await _collection.doc(id).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
