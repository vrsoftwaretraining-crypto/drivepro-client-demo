// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolVehicle {
  const SchoolVehicle({
    this.id = '',
    required this.registrationNumber,
    required this.makeModel,
    required this.transmission,
    this.fuelType = 'Petrol',
    this.insuranceExpiry,
    this.fcExpiry,
    this.photoUrl = '',
    this.active = true,
  });

  final String id;
  final String registrationNumber;
  final String makeModel;
  final String transmission;
  final String fuelType;
  final DateTime? insuranceExpiry;
  final DateTime? fcExpiry;
  final String photoUrl;
  final bool active;

  factory SchoolVehicle.fromMap(String id, Map<String, dynamic> map) {
    DateTime? dateFrom(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return SchoolVehicle(
      id: id,
      registrationNumber: map['registrationNumber'] as String? ?? '',
      makeModel: map['makeModel'] as String? ?? '',
      transmission: map['transmission'] as String? ?? 'Manual',
      fuelType: map['fuelType'] as String? ?? 'Petrol',
      insuranceExpiry: dateFrom(map['insuranceExpiry']),
      fcExpiry: dateFrom(map['fcExpiry']),
      photoUrl: map['photoUrl'] as String? ?? '',
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'registrationNumber': registrationNumber.trim().toUpperCase(),
        'makeModel': makeModel.trim(),
        'transmission': transmission,
        'fuelType': fuelType,
        'insuranceExpiry': insuranceExpiry == null
            ? null
            : Timestamp.fromDate(insuranceExpiry!),
        'fcExpiry': fcExpiry == null ? null : Timestamp.fromDate(fcExpiry!),
        'photoUrl': photoUrl.trim(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
