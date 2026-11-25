// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class Instructor {
  const Instructor({
    this.id = '',
    required this.name,
    required this.phone,
    this.email = '',
    this.licenseNumber = '',
    this.photoUrl = '',
    this.bio = '',
    this.experienceYears = 0,
    this.studentsTrained = 0,
    this.achievements = '',
    this.assignedVehicleId = '',
    this.workingDays = const [],
    this.workingHours = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String licenseNumber;
  final String photoUrl;
  final String bio;
  final int experienceYears;
  final int studentsTrained;
  final String achievements;
  final String assignedVehicleId;
  final List<String> workingDays;
  final String workingHours;
  final bool active;

  factory Instructor.fromMap(String id, Map<String, dynamic> map) {
    return Instructor(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      licenseNumber: map['licenseNumber'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      experienceYears: (map['experienceYears'] as num? ?? 0).toInt(),
      studentsTrained: (map['studentsTrained'] as num? ?? 0).toInt(),
      achievements: map['achievements'] as String? ?? '',
      assignedVehicleId: map['assignedVehicleId'] as String? ?? '',
      workingDays: (map['workingDays'] as List<dynamic>? ?? []).whereType<String>().toList(),
      workingHours: map['workingHours'] as String? ?? '',
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'licenseNumber': licenseNumber.trim(),
        'photoUrl': photoUrl.trim(),
        'bio': bio.trim(),
        'experienceYears': experienceYears,
        'studentsTrained': studentsTrained,
        'achievements': achievements.trim(),
        'assignedVehicleId': assignedVehicleId.trim(),
        'workingDays': workingDays,
        'workingHours': workingHours.trim(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
