// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception_handler.dart';
import '../../../core/models/student.dart';

class StudentRepository {
  StudentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection('students');

  Stream<List<Student>> watchStudents() {
    return _students.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Student.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addStudent(Student student) => AppExceptionHandler.guard(
        'Unable to add student',
        () async => _students.add(student.toMap()),
        tag: 'StudentRepository',
      );

  Future<void> updateStudent(Student student) => AppExceptionHandler.guard(
        'Unable to update student',
        () async {
          if (student.id.isEmpty) {
            throw ArgumentError('Student ID is required for update.');
          }
          await _students.doc(student.id).update(student.toMap());
        },
        tag: 'StudentRepository',
      );

  Future<void> archiveStudent(String id) => AppExceptionHandler.guard(
        'Unable to archive student',
        () async => _students.doc(id).update({
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        tag: 'StudentRepository',
      );
}
