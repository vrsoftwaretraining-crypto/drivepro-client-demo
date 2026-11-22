// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/instructor.dart';
import '../../../core/providers/auth_providers.dart';
import '../providers/instructor_providers.dart';

class InstructorsPage extends ConsumerWidget {
  const InstructorsPage({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Instructor? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final phone = TextEditingController(text: current?.phone ?? '');
    final email = TextEditingController(text: current?.email ?? '');
    final license = TextEditingController(text: current?.licenseNumber ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Instructor>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'Add instructor' : 'Edit instructor'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _input(name, 'Full name'),
                  _input(phone, 'Phone number'),
                  _input(email, 'Email address', required: false),
                  _input(license, 'Driving licence number', required: false),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                Instructor(
                  id: current?.id ?? '',
                  name: name.text,
                  phone: phone.text,
                  email: email.text,
                  licenseNumber: license.text,
                  active: current?.active ?? true,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    name.dispose();
    phone.dispose();
    email.dispose();
    license.dispose();

    if (result == null) return;
    final repository = ref.read(instructorRepositoryProvider);
    try {
      if (current == null) {
        await repository.add(result);
      } else {
        await repository.update(result);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save instructor: $error')),
        );
      }
    }
  }

  static Widget _input(TextEditingController controller, String label,
      {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            required && (value == null || value.trim().isEmpty)
                ? '$label is required.'
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final canManage = user?.isAdmin ?? false;
    final data = ref.watch(instructorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructors'),
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add instructor'),
              ),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Unable to load instructors: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No instructors added yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.badge_outlined)),
                  title: Text(item.name),
                  subtitle: Text(
                      '${item.phone}  •  ${item.email}\nLicence: ${item.licenseNumber.isEmpty ? 'Not provided' : item.licenseNumber}'),
                  isThreeLine: true,
                  trailing: canManage
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openForm(context, ref, current: item);
                            } else if (value == 'archive') {
                              await ref
                                  .read(instructorRepositoryProvider)
                                  .archive(item.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'archive', child: Text('Archive')),
                          ],
                        )
                      : Chip(label: Text(item.active ? 'Active' : 'Archived')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
