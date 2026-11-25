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
          .toList(),);

  Map<String, dynamic> _public(Instructor i) => {
        'name': i.name.trim(),
        'photoUrl': i.photoUrl.trim(),
        'bio': i.bio.trim(),
        'experienceYears': i.experienceYears,
        'studentsTrained': i.studentsTrained,
        'achievements': i.achievements.trim(),
        'assignedVehicleId': i.assignedVehicleId.trim(),
        'workingDays': i.workingDays,
        'workingHours': i.workingHours.trim(),
        'active': i.active,
      };

  Future<void> add(Instructor instructor) async {
    final ref = _collection.doc();
    final batch = _db.batch();
    batch.set(ref, {
      ...instructor.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('public_instructors').doc(ref.id), _public(instructor));
    await batch.commit();
  }

  Future<void> update(Instructor instructor) async {
    if (instructor.id.isEmpty) {
      throw ArgumentError('Instructor ID is required.');
    }
    final batch = _db.batch();
    batch.update(_collection.doc(instructor.id), instructor.toMap());
    batch.set(_db.collection('public_instructors').doc(instructor.id),
        _public(instructor), SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> archive(String id) async {
    final batch = _db.batch();
    batch.update(_collection.doc(id), {
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('public_instructors').doc(id), {'active': false},
        SetOptions(merge: true));
    await batch.commit();
  }
}
