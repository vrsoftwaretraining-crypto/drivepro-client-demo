// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/payment.dart';

class PaymentRepository {
  PaymentRepository(this.db);
  final FirebaseFirestore db;
  Stream<List<FeePayment>> watchPayments() => db
      .collection('payments')
      .orderBy('paidAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => FeePayment.fromMap(d.id, d.data())).toList());
  Future<void> record(
      {required String studentId,
      required String studentName,
      required double amount,
      required String method,
      required String receiptNo,
      required String notes}) async {
    if (amount <= 0)
      throw ArgumentError('Payment amount must be greater than zero.');
    final student = db.collection('students').doc(studentId);
    final payment = db.collection('payments').doc();
    await db.runTransaction((tx) async {
      final snap = await tx.get(student);
      if (!snap.exists) throw StateError('Student not found.');
      final data = snap.data()!;
      final total = (data['totalFee'] as num?)?.toDouble() ?? 0;
      final paid = (data['paidFee'] as num?)?.toDouble() ?? 0;
      if (amount > total - paid + 0.000001)
        throw StateError('Payment exceeds pending fee.');
      tx.update(student, {
        'paidFee': paid + amount,
        'updatedAt': FieldValue.serverTimestamp()
      });
      tx.set(payment, {
        'studentId': studentId,
        'studentName': studentName,
        'amount': amount,
        'method': method,
        'receiptNo': receiptNo,
        'notes': notes.trim(),
        'paidAt': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp()
      });
    });
  }
}
