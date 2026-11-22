// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/student.dart';
import '../../students/providers/student_providers.dart';
import '../providers/payment_providers.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);
    final payments = ref.watch(paymentsProvider);
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('Fee payments',
                        style: Theme.of(context).textTheme.headlineSmall)),
                FilledButton.icon(
                    onPressed: () => students.when(
                        data: (items) => showDialog(
                            context: context,
                            builder: (_) => _PaymentDialog(
                                students: items
                                    .where((s) => s.active && s.pendingFee > 0)
                                    .toList())),
                        error: (e, _) => _error(context, e),
                        loading: () => null),
                    icon: const Icon(Icons.add),
                    label: const Text('Record payment'))
              ]),
              const SizedBox(height: 12),
              Expanded(
                  child: payments.when(
                      data: (items) => items.isEmpty
                          ? const Center(
                              child: Text('No payments recorded yet.'))
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final p = items[i];
                                return ListTile(
                                    leading: const CircleAvatar(
                                        child: Icon(Icons.receipt_long)),
                                    title: Text(p.studentName),
                                    subtitle: Text(
                                        '${p.receiptNo} • ${p.method.toUpperCase()} • ${DateFormat.yMMMd().format(p.paidAt)}'),
                                    trailing: Text(
                                        '₹${p.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)));
                              }),
                      error: (e, _) =>
                          Center(child: Text('Could not load payments: $e')),
                      loading: () =>
                          const Center(child: CircularProgressIndicator())))
            ])));
  }

  void _error(BuildContext context, Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));
}

class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({required this.students});
  final List<Student> students;
  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  String? studentId;
  String method = 'cash';
  final amount = TextEditingController();
  final receipt = TextEditingController();
  final notes = TextEditingController();
  bool saving = false;
  Student? get _selectedStudent {
    for (final item in widget.students) {
      if (item.id == studentId) return item;
    }
    return null;
  }

  @override
  void dispose() {
    amount.dispose();
    receipt.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedStudent;
    return AlertDialog(
        title: const Text('Record fee payment'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                  initialValue: studentId,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: widget.students
                      .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                              '${s.name} • Pending ₹${s.pendingFee.toStringAsFixed(0)}')))
                      .toList(),
                  onChanged: (v) => setState(() => studentId = v)),
              TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Amount',
                      helperText: selected == null
                          ? null
                          : 'Pending: ₹${selected.pendingFee.toStringAsFixed(2)}')),
              DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration:
                      const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    'cash',
                    'upi',
                    'card',
                    'bank transfer',
                    'cheque'
                  ]
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(v.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => method = v ?? 'cash')),
              TextField(
                  controller: receipt,
                  decoration:
                      const InputDecoration(labelText: 'Receipt number')),
              TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'))
            ]))),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'))
        ]);
  }

  Future<void> _save() async {
    final s = _selectedStudent;
    final value = double.tryParse(amount.text.trim());
    if (s == null || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a student and enter a valid amount.')));
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(paymentRepositoryProvider).record(
          studentId: s.id,
          studentName: s.name,
          amount: value,
          method: method,
          receiptNo: receipt.text.trim(),
          notes: notes.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
