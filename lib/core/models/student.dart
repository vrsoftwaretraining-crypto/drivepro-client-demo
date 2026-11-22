// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  const Student({
    this.id = '',
    required this.name,
    required this.phone,
    this.email = '',
    required this.course,
    required this.totalFee,
    required this.paidFee,
    required this.active,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String course;
  final double totalFee;
  final double paidFee;
  final bool active;
  final DateTime? createdAt;

  double get pendingFee =>
      (totalFee - paidFee).clamp(0, double.infinity).toDouble();

  factory Student.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'] as Timestamp?;
    return Student(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      course: map['course'] as String? ?? '',
      totalFee: (map['totalFee'] as num?)?.toDouble() ?? 0,
      paidFee: (map['paidFee'] as num?)?.toDouble() ?? 0,
      active: map['active'] as bool? ?? true,
      createdAt: timestamp?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'course': course.trim(),
      'totalFee': totalFee,
      'paidFee': paidFee,
      'active': active,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
