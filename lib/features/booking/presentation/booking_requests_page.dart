// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/school_service.dart';
import '../data/public_catalog.dart';
import '../../../core/services/backend.dart';

class BookingRequestsPage extends StatelessWidget {
  const BookingRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Booking requests & account setup',
                    style: Theme.of(context).textTheme.headlineSmall),
                FilledButton.icon(
                  onPressed: () => _createInstructor(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Create instructor account'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: Backend.firestore
                  .collection('booking_requests')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Unable to load requests: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No public booking requests yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final status = data['status'] as String? ?? 'pending';
                    final date = (data['startAt'] as Timestamp?)?.toDate();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['name'] as String? ?? 'New enquiry',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                Chip(label: Text(status.replaceAll('_', ' '))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Phone: ${data['phone'] ?? '-'}   •   Email: ${data['email'] ?? '-'}'),
                            Text('Course: ${data['course'] ?? '-'}'),
                            if ((data['pickupAddress'] as String? ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Icon(Icons.home_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('Pickup address: ${data['pickupAddress']}')),
                                ]),
                              ),
                            Text('Vehicle: ${data['vehicleRegistration'] ?? '-'}'),
                            Text('Instructor: ${data['instructorName'] ?? '-'}'),
                            Text('Preferred lesson: ${date?.toLocal() ?? 'Not set'}'),
                            Text('Payment: ${data['paymentStatus'] ?? 'unpaid'}'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (data['studentUserId'] == null &&
                                    status != 'expired')
                                  FilledButton.tonalIcon(
                                    onPressed: () => _createStudent(context, doc.id, data),
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Create student account'),
                                  ),
                                if (data['studentUserId'] != null &&
                                    data['paymentStatus'] != 'paid' &&
                                    status != 'expired')
                                  FilledButton.icon(
                                    onPressed: () => _confirmPayment(context, doc.id, data),
                                    icon: const Icon(Icons.verified),
                                    label: const Text('Confirm payment & activate'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCredentials(
      BuildContext context, String title, NewAccount acc, String extra) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SelectableText(
          'Login: ${acc.email}\nTemporary password: ${acc.temporaryPassword}\n\n'
          '$extra\nThey must set a new password and security questions at first login.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: 'Login: ${acc.email}\nPassword: ${acc.temporaryPassword}'));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copy & close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudent(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final feeController = TextEditingController();
    final fee = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Student registration fee'),
        content: TextField(
          controller: feeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Total course fee (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(feeController.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
    feeController.dispose();
    if (fee == null) return;
    try {
      final acc = await SchoolService.createAccount(
        role: 'student',
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        extra: {'course': data['course'], 'totalFee': fee},
        bookingRequestId: requestId,
        bookingRequest: data,
      );
      if (!context.mounted) return;
      await _showCredentials(context, 'Student account created', acc,
          'The login stays inactive until you confirm payment.');
    } catch (error) {
      if (context.mounted) _showError(context, '$error');
    }
  }

  Future<void> _confirmPayment(
      BuildContext context, String requestId, Map<String, dynamic> data) async {
    final PublicCatalog catalog;
    try {
      catalog = await PublicCatalog.load();
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not load slots: $error');
      return;
    }
    if (catalog.instructors.isEmpty) {
      if (context.mounted) _showError(context, 'Add at least one active instructor first.');
      return;
    }
    final reqStart = (data['startAt'] as Timestamp?)?.toDate().toUtc() ?? DateTime.now().toUtc();
    final ist = reqStart.add(const Duration(hours: 5, minutes: 30));
    var date = DateTime(ist.year, ist.month, ist.day);
    var instructor = catalog.instructors.firstWhere(
        (i) => i['id'] == data['instructorId'],
        orElse: () => catalog.instructors.first);
    var slots = catalog.slotsFor(date);
    SlotWindow? slot = slots.where((s) => s.startUtc == reqStart).firstOrNull ??
        (slots.isEmpty ? null : slots.first);
    final amountController = TextEditingController();
    var confirmed = false;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          String stateText(SlotWindow s) {
            if (s.startUtc == reqStart && instructor['id'] == data['instructorId']) {
              return 'requested';
            }
            return switch (catalog.stateOf(instructor, s)) {
              SlotState.available => 'free',
              SlotState.booked => 'BOOKED',
              SlotState.past => 'past',
              SlotState.notWorking => 'not working',
            };
          }

          return AlertDialog(
            title: const Text('Confirm payment & book slot'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount received (₹)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: instructor['id'] as String,
                    decoration: const InputDecoration(labelText: 'Instructor'),
                    items: [
                      for (final i in catalog.instructors)
                        DropdownMenuItem(value: i['id'] as String, child: Text(i['name'] as String? ?? '')),
                    ],
                    onChanged: (v) => setState(() {
                      instructor = catalog.instructors.firstWhere((i) => i['id'] == v);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text('${date.day}/${date.month}/${date.year}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked == null) return;
                        setState(() {
                          date = picked;
                          slots = catalog.slotsFor(date);
                          slot = slots.isEmpty ? null : slots.first;
                        });
                      },
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey('${date.toIso8601String()}-${instructor['id']}'),
                    initialValue: slot == null ? null : slots.indexOf(slot!),
                    decoration: const InputDecoration(labelText: 'Slot (marked BOOKED once confirmed)'),
                    items: [
                      for (var i = 0; i < slots.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${slots[i].label} • ${stateText(slots[i])}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => slot = v == null ? null : slots[v]),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(amountController.text.trim());
                  if (value == null || value <= 0 || slot == null) return;
                  confirmed = true;
                  Navigator.pop(dialogContext);
                },
                child: const Text('Confirm payment'),
              ),
            ],
          );
        },
      ),
    );
    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (!confirmed || amount == null || slot == null) return;
    final vehicle = catalog.vehicleOf(instructor) ??
        catalog.vehicles.where((v) => v['id'] == data['vehicleId']).firstOrNull ??
        (catalog.vehicles.isEmpty ? null : catalog.vehicles.first);
    if (vehicle == null) {
      if (context.mounted) _showError(context, 'No active vehicle found for this slot.');
      return;
    }
    try {
      await SchoolService.confirmBooking(
        requestId: requestId,
        amount: amount,
        instructorId: instructor['id'] as String,
        instructorName: instructor['name'] as String? ?? '',
        vehicleId: vehicle['id'] as String,
        vehicleRegistration: vehicle['registrationNumber'] as String? ?? '',
        startUtc: slot!.startUtc,
        minutes: slot!.minutes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed. Slot is now BOOKED and the student login is active.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, '$error');
    }
  }

  Future<void> _createInstructor(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final vehicleId = TextEditingController();
    final workingDays = TextEditingController(text: 'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday');
    final workingHours = TextEditingController(text: '06:00 AM - 08:00 PM');
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create instructor account'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Mobile number')),
                TextField(controller: vehicleId, decoration: const InputDecoration(labelText: 'Assigned vehicle document ID (optional)')),
                TextField(controller: workingDays, decoration: const InputDecoration(labelText: 'Working days (comma separated)')),
                TextField(controller: workingHours, decoration: const InputDecoration(labelText: 'Working hours')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [
              name.text.trim(), email.text.trim(), phone.text.trim(),
              vehicleId.text.trim(), workingDays.text.trim(), workingHours.text.trim(),
            ]),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
    vehicleId.dispose();
    workingDays.dispose();
    workingHours.dispose();
    if (result == null) return;
    if (result[0].isEmpty || result[1].isEmpty || result[2].isEmpty) {
      if (context.mounted) _showError(context, 'Enter instructor name, email and phone.');
      return;
    }
    try {
      final acc = await SchoolService.createAccount(
        role: 'instructor',
        name: result[0],
        email: result[1],
        phone: result[2],
        extra: {
          'assignedVehicleId': result[3],
          'workingDays': result[4].split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
          'workingHours': result[5],
        },
      );
      if (!context.mounted) return;
      await _showCredentials(context, 'Instructor account created', acc,
          'The instructor now appears on the public slot board.');
    } catch (error) {
      if (context.mounted) _showError(context, '$error');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
