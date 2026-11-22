// Developed by @Ramana Code Softwares

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/auth_providers.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider =
    Provider((ref) => PaymentRepository(ref.watch(firestoreProvider)));
final paymentsProvider = StreamProvider<List<FeePayment>>(
    (ref) => ref.watch(paymentRepositoryProvider).watchPayments());
