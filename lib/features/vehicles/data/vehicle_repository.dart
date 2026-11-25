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
          .toList(),);

  Map<String, dynamic> _public(SchoolVehicle v) => {
        'registrationNumber': v.registrationNumber.trim().toUpperCase(),
        'makeModel': v.makeModel.trim(),
        'transmission': v.transmission,
        'fuelType': v.fuelType,
        'photoUrl': v.photoUrl.trim(),
        'active': v.active,
      };

  Future<void> add(SchoolVehicle vehicle) async {
    final ref = _collection.doc();
    final batch = _db.batch();
    batch.set(ref, {
      ...vehicle.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('public_vehicles').doc(ref.id), _public(vehicle));
    await batch.commit();
  }

  Future<void> update(SchoolVehicle vehicle) async {
    if (vehicle.id.isEmpty) throw ArgumentError('Vehicle ID is required.');
    final batch = _db.batch();
    batch.update(_collection.doc(vehicle.id), vehicle.toMap());
    batch.set(_db.collection('public_vehicles').doc(vehicle.id), _public(vehicle),
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> archive(String id) async {
    final batch = _db.batch();
    batch.update(_collection.doc(id), {
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('public_vehicles').doc(id), {'active': false},
        SetOptions(merge: true));
    await batch.commit();
  }
}
