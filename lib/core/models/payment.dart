// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';

class FeePayment {
  const FeePayment(
      {required this.id,
      required this.studentId,
      required this.studentName,
      required this.amount,
      required this.method,
      required this.receiptNo,
      required this.paidAt,
      this.notes = '',});
  final String id, studentId, studentName, method, receiptNo, notes;
  final double amount;
  final DateTime paidAt;
  factory FeePayment.fromMap(String id, Map<String, dynamic> map) => FeePayment(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: map['method'] as String? ?? 'cash',
      receiptNo: map['receiptNo'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      paidAt: (map['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),);
  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'amount': amount,
        'method': method,
        'receiptNo': receiptNo,
        'notes': notes,
        'paidAt': Timestamp.fromDate(paidAt),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
