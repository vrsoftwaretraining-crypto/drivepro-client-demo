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
              Row(children: [
                Expanded(
                    child: Text('Lesson attendance',
                        style: Theme.of(context).textTheme.headlineSmall)),
                FilledButton.icon(
                    onPressed: () => lessons.when(
                        data: (items) => showDialog(
                            context: context,
                            builder: (_) => _AttendanceDialog(lessons: items)),
                        error: (e, _) => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e'))),
                        loading: () => null),
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Mark attendance'))
              ]),
              const SizedBox(height: 12),
              Expanded(
                  child: records.when(
                      data: (items) => items.isEmpty
                          ? const Center(
                              child: Text('No attendance records yet.'))
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
                                        '${DateFormat.yMMMd().add_jm().format(a.lessonAt)} • ${a.instructorName}'),
                                    trailing: Chip(
                                        label: Text(a.status.toUpperCase()),
                                        side: BorderSide(color: color)));
                              }),
                      error: (e, _) =>
                          Center(child: Text('Could not load attendance: $e')),
                      loading: () =>
                          const Center(child: CircularProgressIndicator())))
            ])));
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
    return AlertDialog(
        title: const Text('Mark attendance'),
        content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                  initialValue: lessonId,
                  decoration: const InputDecoration(labelText: 'Lesson'),
                  items: widget.lessons
                      .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(
                              '${l.studentName} • ${DateFormat.yMMMd().add_jm().format(l.startAt)}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => lessonId = v)),
              DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['present', 'absent', 'late']
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(v.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => status = v ?? 'present')),
              TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'))
            ])),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving || lesson == null ? null : _save,
              child: saving
                  ? const CircularProgressIndicator()
                  : const Text('Save'))
        ]);
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
          notes: notes.text));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
