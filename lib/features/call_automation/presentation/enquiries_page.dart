// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';

class EnquiriesPage extends ConsumerWidget {
  const EnquiriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref
        .watch(firestoreProvider)
        .collection('call_enquiries')
        .orderBy('receivedAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load enquiries: ${snapshot.error}'),);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          final pending = docs
              .where((doc) =>
                  (doc.data()['followUpStatus'] as String? ?? 'pending') ==
                  'pending',)
              .length;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Call enquiries',
                  style: Theme.of(context).textTheme.headlineSmall,),
              const SizedBox(height: 6),
              const Text(
                  'Missed calls received on your DrivePro business number.',),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                      label: 'Total enquiries',
                      value: '${docs.length}',
                      icon: Icons.call,),
                  _MetricCard(
                      label: 'Pending follow-ups',
                      value: '$pending',
                      icon: Icons.pending_actions,),
                ],
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Card(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No call enquiries yet. Connect your cloud telephony webhook to start receiving calls.',),
                ),)
              else
                ...docs.map((doc) => _EnquiryTile(
                      data: doc.data(),
                      onStatusChanged: (status) => doc.reference.update({
                        'followUpStatus': status,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }),
                      onNotesChanged: (notes) => doc.reference.update({
                        'followUpNotes': notes,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }),
                    ),),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.icon,});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],),
          ],),
        ),),
      );
}

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({
    required this.data,
    required this.onStatusChanged,
    required this.onNotesChanged,
  });

  final Map<String, dynamic> data;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    final phone = data['phoneNumber'] as String? ?? 'Unknown number';
    final status = data['followUpStatus'] as String? ?? 'pending';
    final callStatus = data['callStatus'] as String? ?? 'missed';
    final receivedAt = (data['receivedAt'] as Timestamp?)?.toDate();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.phone_missed)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(phone, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '$callStatus${receivedAt == null ? '' : ' • ${MaterialLocalizations.of(context).formatMediumDate(receivedAt)} ${TimeOfDay.fromDateTime(receivedAt).format(context)}'}',),
                ],),),
            PopupMenuButton<String>(
              initialValue: status,
              onSelected: onStatusChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pending', child: Text('Pending')),
                PopupMenuItem(value: 'contacted', child: Text('Contacted')),
                PopupMenuItem(value: 'converted', child: Text('Converted')),
                PopupMenuItem(
                    value: 'not_interested', child: Text('Not interested'),),
              ],
              child: Chip(label: Text(status.replaceAll('_', ' '))),
            ),
          ],),
          const SizedBox(height: 8),
          if ((data['callerName'] as String? ?? '').isNotEmpty)
            Text('Name: ${data['callerName']}'),
          if ((data['instructorName'] as String? ?? '').isNotEmpty)
            Text('Instructor: ${data['instructorName']}'),
          if ((data['slotLabel'] as String? ?? '').isNotEmpty)
            Text('Slot: ${data['slotLabel']}'),
          if ((data['message'] as String? ?? '').isNotEmpty)
            Text('Message: ${data['message']}'),
          Text('SMS: ${data['smsStatus'] ?? 'not sent'}'),
          if ((data['followUpNotes'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Notes: ${data['followUpNotes']}'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _editNotes(context),
              icon: const Icon(Icons.edit_note),
              label: const Text('Add follow-up note'),
            ),
          ),
        ],),
      ),
    );
  }

  Future<void> _editNotes(BuildContext context) async {
    final controller =
        TextEditingController(text: data['followUpNotes'] as String? ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Follow-up notes'),
        content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Customer requirement / next follow-up',),),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),),
        ],
      ),
    );
    if (result != null) onNotesChanged(result);
    controller.dispose();
  }
}
