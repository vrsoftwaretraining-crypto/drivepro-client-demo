// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/lesson.dart';
import '../../lessons/providers/lesson_providers.dart';
import '../providers/attendance_providers.dart';
import '../../../core/models/attendance.dart';

class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final records = ref.watch(attendanceProvider);
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                spacing: 12,
                children: [
                  Text('Lesson attendance', style: Theme.of(context).textTheme.headlineSmall),
                  FilledButton.icon(
                    onPressed: () => lessons.when(
                      data: (items) {
                        if (items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Create a lesson before marking attendance.')),
                          );
                          return;
                        }
                        showDialog<void>(
                          context: context,
                          builder: (_) => _AttendanceDialog(lessons: items),
                        );
                      },
                      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))),
                      loading: () {},
                    ),
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Mark attendance'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                  child: records.when(
                      data: (items) => items.isEmpty
                          ? const Center(
                              child: Text('No attendance records yet.'),)
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final a = items[i];
                                final color = a.status == 'present'
                                    ? Colors.green
                                    : a.status == 'late'
                                        ? Colors.orange
                                        : Colors.red;
                                return ListTile(
                                    leading: Icon(Icons.person, color: color),
                                    title: Text(a.studentName),
                                    subtitle: Text(
                                        '${DateFormat.yMMMd().add_jm().format(a.lessonAt)} • ${a.instructorName}',),
                                    trailing: Chip(
                                        label: Text(a.status.toUpperCase()),
                                        side: BorderSide(color: color),),);
                              },),
                      error: (e, _) =>
                          Center(child: Text('Could not load attendance: $e')),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),),),
            ],),),);
  }
}

class _AttendanceDialog extends ConsumerStatefulWidget {
  const _AttendanceDialog({required this.lessons});
  final List<DrivingLesson> lessons;
  @override
  ConsumerState<_AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends ConsumerState<_AttendanceDialog> {
  String? lessonId;
  String status = 'present';
  final notes = TextEditingController();
  bool saving = false;
  DrivingLesson? get _selectedLesson {
    for (final item in widget.lessons) {
      if (item.id == lessonId) return item;
    }
    return null;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _selectedLesson;
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Mark lesson attendance'),
      content: SizedBox(
        width: 440,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.62),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select the lesson and record the student status.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: lessonId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lesson', border: OutlineInputBorder()),
                  items: widget.lessons.map((l) => DropdownMenuItem(
                    value: l.id,
                    child: Text(
                      '${l.studentName} • ${DateFormat.yMMMd().add_jm().format(l.startAt)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (value) => setState(() => lessonId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Attendance status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'present', child: Text('Present')),
                    DropdownMenuItem(value: 'late', child: Text('Late')),
                    DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  ],
                  onChanged: (value) => setState(() => status = value ?? 'present'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(), alignLabelWithHint: true),
                ),
                if (lesson != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lesson.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${lesson.instructorName} • ${lesson.vehicleRegistration}'),
                        Text(DateFormat.yMMMMd().add_jm().format(lesson.startAt)),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: saving || lesson == null ? null : _save,
          icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          label: const Text('Save attendance'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l = _selectedLesson;
    if (l == null) return;
    setState(() => saving = true);
    try {
      await ref.read(attendanceRepositoryProvider).save(LessonAttendance(
          id: l.id,
          lessonId: l.id,
          studentId: l.studentId,
          studentName: l.studentName,
          instructorName: l.instructorName,
          lessonAt: l.startAt,
          status: status,
          notes: notes.text,
          studentUserId: l.studentUserId.isNotEmpty ? l.studentUserId : l.studentId,
          instructorUserId: l.instructorUserId.isNotEmpty ? l.instructorUserId : l.instructorId,),);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
