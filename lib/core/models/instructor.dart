// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class Instructor {
  const Instructor({
    this.id = '',
    required this.name,
    required this.phone,
    this.email = '',
    this.licenseNumber = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String licenseNumber;
  final bool active;

  factory Instructor.fromMap(String id, Map<String, dynamic> map) {
    return Instructor(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      licenseNumber: map['licenseNumber'] as String? ?? '',
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'licenseNumber': licenseNumber.trim(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
