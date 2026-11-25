// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/student.dart';
import '../../../core/providers/auth_providers.dart';
import '../providers/student_providers.dart';
import 'student_form_dialog.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    final student = await showDialog<Student>(
      context: context,
      builder: (_) => const StudentFormDialog(),
    );
    if (student == null || !mounted) return;

    try {
      await ref.read(studentRepositoryProvider).addStudent(student);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully.')),
        );
      }
    } catch (error) {
      if (mounted) _showError('Unable to add student: $error');
    }
  }

  Future<void> _editStudent(Student current) async {
    final updated = await showDialog<Student>(
      context: context,
      builder: (_) => StudentFormDialog(student: current),
    );
    if (updated == null || !mounted) return;

    try {
      await ref.read(studentRepositoryProvider).updateStudent(updated);
    } catch (error) {
      if (mounted) _showError('Unable to update student: $error');
    }
  }

  Future<void> _archiveStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive student?'),
        content: Text('Archive ${student.name}? They will remain in records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(studentRepositoryProvider).archiveStudent(student.id);
    } catch (error) {
      if (mounted) _showError('Unable to archive student: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _addStudent,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add student'),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by name, phone or course',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Unable to load students: $error'),
                ),
                data: (students) {
                  final filtered = students.where((student) {
                    final matches =
                        student.name.toLowerCase().contains(_query) ||
                            student.phone.toLowerCase().contains(_query) ||
                            student.course.toLowerCase().contains(_query);
                    return matches;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No students found. Add your first student.'),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 680) {
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => _StudentCard(
                            student: filtered[index],
                            canEdit: isAdmin,
                            onEdit: () => _editStudent(filtered[index]),
                            onArchive: () => _archiveStudent(filtered[index]),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Course')),
                                DataColumn(label: Text('Total fee')),
                                DataColumn(label: Text('Paid')),
                                DataColumn(label: Text('Pending')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((student) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(student.name)),
                                    DataCell(Text(student.phone)),
                                    DataCell(Text(student.course)),
                                    DataCell(Text(_money(student.totalFee))),
                                    DataCell(Text(_money(student.paidFee))),
                                    DataCell(Text(_money(student.pendingFee))),
                                    DataCell(
                                        _StatusChip(active: student.active),),
                                    DataCell(
                                      isAdmin
                                          ? Row(
                                              children: [
                                                IconButton(
                                                  tooltip: 'Edit',
                                                  onPressed: () =>
                                                      _editStudent(student),
                                                  icon: const Icon(
                                                      Icons.edit_outlined,),
                                                ),
                                                IconButton(
                                                  tooltip: 'Archive',
                                                  onPressed: () =>
                                                      _archiveStudent(student),
                                                  icon: const Icon(
                                                      Icons.archive_outlined,),
                                                ),
                                              ],
                                            )
                                          : const Text('View only'),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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
      ),
    );
  }

  String _money(double value) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(value);
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.canEdit,
    required this.onEdit,
    required this.onArchive,
  });

  final Student student;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          child:
              Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase()),
        ),
        title: Text(student.name,
            style: const TextStyle(fontWeight: FontWeight.w700),),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${student.phone} • ${student.course}\nPending: ₹${student.pendingFee.toStringAsFixed(0)}',
          ),
        ),
        isThreeLine: true,
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onArchive();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              )
            : _StatusChip(active: student.active),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(active ? 'Active' : 'Archived'),
      backgroundColor:
          active ? const Color(0xFFE2F6EC) : const Color(0xFFF0F1F4),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: active ? const Color(0xFF16794B) : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
