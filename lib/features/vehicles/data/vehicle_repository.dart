// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/vehicle.dart';

class VehicleRepository {
  VehicleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('vehicles');

  Stream<List<SchoolVehicle>> watchAll() => _collection
      .orderBy('registrationNumber')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => SchoolVehicle.fromMap(doc.id, doc.data()))
          .toList());

  Future<void> add(SchoolVehicle vehicle) async {
    await _collection.add({
      ...vehicle.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(SchoolVehicle vehicle) async {
    if (vehicle.id.isEmpty) throw ArgumentError('Vehicle ID is required.');
    await _collection.doc(vehicle.id).update(vehicle.toMap());
  }

  Future<void> archive(String id) async {
    await _collection.doc(id).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
