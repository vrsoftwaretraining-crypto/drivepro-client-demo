// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref
        .watch(firestoreProvider)
        .collection('reminders')
        .orderBy('createdAt', descending: true)
        .snapshots();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_alert),
        label: const Text('Add reminder'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
                child: Text('Unable to load reminders: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(
                child: Text(
                    'No reminders yet. Add a reminder for a lesson, payment or vehicle document.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Text('Reminders',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data();
                final dueAt = (data['dueAt'] as Timestamp?)?.toDate();
                final done = data['completed'] == true;
                return Card(
                  child: CheckboxListTile(
                    value: done,
                    onChanged: (value) async {
                      await doc.reference.update({
                        'completed': value ?? false,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                    title: Text(data['title'] as String? ?? 'Reminder'),
                    subtitle: Text([
                      data['details'] as String? ?? '',
                      if (dueAt != null)
                        'Due: ${MaterialLocalizations.of(context).formatMediumDate(dueAt)}',
                    ].where((item) => item.isNotEmpty).join('\n')),
                    secondary: Icon(done
                        ? Icons.check_circle
                        : Icons.notifications_active_outlined),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    DateTime dueAt = DateTime.now().add(const Duration(days: 1));
    final selectedDate = ValueNotifier<DateTime>(dueAt);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create reminder'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                TextFormField(
                  controller: detailsController,
                  decoration:
                      const InputDecoration(labelText: 'Details (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<DateTime>(
                  valueListenable: selectedDate,
                  builder: (context, date, _) => OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                        'Due: ${MaterialLocalizations.of(context).formatMediumDate(date)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        dueAt = picked;
                        selectedDate.value = picked;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(firestoreProvider).collection('reminders').add({
                  'title': titleController.text.trim(),
                  'details': detailsController.text.trim(),
                  'dueAt': Timestamp.fromDate(dueAt),
                  'completed': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text('Could not save reminder: $error')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
    detailsController.dispose();
    selectedDate.dispose();
  }
}
