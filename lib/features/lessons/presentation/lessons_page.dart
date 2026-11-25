// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/instructor.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/student.dart';
import '../../../core/models/vehicle.dart';
import '../../../core/providers/auth_providers.dart';
import '../../instructors/providers/instructor_providers.dart';
import '../../students/providers/student_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/lesson_providers.dart';

class LessonsPage extends ConsumerWidget {
  const LessonsPage({super.key});

  Future<void> _bookLesson(BuildContext context, WidgetRef ref) async {
    final students = await ref.read(studentsProvider.future);
    final instructors = await ref.read(instructorsProvider.future);
    final vehicles = await ref.read(vehiclesProvider.future);

    final activeStudents = students.where((item) => item.active).toList();
    final activeInstructors = instructors.where((item) => item.active).toList();
    final activeVehicles = vehicles.where((item) => item.active).toList();

    if (activeStudents.isEmpty ||
        activeInstructors.isEmpty ||
        activeVehicles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Add an active student, instructor and vehicle before booking a lesson.',),),
        );
      }
      return;
    }

    Student selectedStudent = activeStudents.first;
    Instructor selectedInstructor = activeInstructors.first;
    SchoolVehicle selectedVehicle = activeVehicles.first;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    int duration = 60;
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final lesson = await showDialog<DrivingLesson>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Book driving lesson'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Student>(
                      initialValue: selectedStudent,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Student'),
                      items: activeStudents
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.name,
                                    overflow: TextOverflow.ellipsis,),
                              ),)
                          .toList(),
                      onChanged: (value) => setDialogState(
                          () => selectedStudent = value ?? selectedStudent,),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Instructor>(
                      initialValue: selectedInstructor,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Instructor'),
                      items: activeInstructors
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.name,
                                    overflow: TextOverflow.ellipsis,),
                              ),)
                          .toList(),
                      onChanged: (value) => setDialogState(() =>
                          selectedInstructor = value ?? selectedInstructor,),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SchoolVehicle>(
                      initialValue: selectedVehicle,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Vehicle'),
                      items: activeVehicles
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                    '${item.registrationNumber} • ${item.makeModel}',
                                    overflow: TextOverflow.ellipsis,),
                              ),)
                          .toList(),
                      onChanged: (value) => setDialogState(
                          () => selectedVehicle = value ?? selectedVehicle,),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lesson date'),
                      subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start time'),
                      subtitle: Text(selectedTime.format(context)),
                      trailing: IconButton(
                        icon: const Icon(Icons.schedule),
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: selectedTime,);
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: duration,
                      decoration: const InputDecoration(labelText: 'Duration'),
                      items: const [15, 30, 45, 60, 90, 120]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value minutes'),
                              ),)
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => duration = value ?? 60),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)'),
                    ),
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
                final start = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                if (start.isBefore(DateTime.now())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Choose a future lesson time.'),),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  DrivingLesson(
                    studentId: selectedStudent.id,
                    studentName: selectedStudent.name,
                    instructorId: selectedInstructor.id,
                    instructorName: selectedInstructor.name,
                    vehicleId: selectedVehicle.id,
                    vehicleRegistration: selectedVehicle.registrationNumber,
                    startAt: start,
                    durationMinutes: duration,
                    notes: notes.text,
                  ),
                );
              },
              child: const Text('Book lesson'),
            ),
          ],
        ),
      ),
    );

    notes.dispose();
    if (lesson == null || !context.mounted) return;

    try {
      await ref.read(lessonRepositoryProvider).add(lesson);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson booked successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to book lesson: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(appUserProvider).valueOrNull?.isAdmin ?? false;
    final data = ref.watch(lessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson schedule'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _bookLesson(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Book lesson'),
              ),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Unable to load lessons: $error')),
        data: (lessons) {
          if (lessons.isEmpty) {
            return const Center(child: Text('No lessons scheduled yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: lessons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final isPast = lesson.startAt.isBefore(DateTime.now());
              return Card(
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.drive_eta_rounded)),
                  title: Text(
                      '${lesson.studentName} • ${lesson.vehicleRegistration}',),
                  subtitle: Text(
                    '${DateFormat.yMMMd().add_jm().format(lesson.startAt)}'
                    ' • ${lesson.durationMinutes} min\nInstructor: ${lesson.instructorName}'
                    '${lesson.notes.isEmpty ? '' : '\n${lesson.notes}'}',
                  ),
                  isThreeLine: true,
                  trailing: isAdmin
                      ? PopupMenuButton<String>(
                          initialValue: lesson.status,
                          onSelected: (value) => ref
                              .read(lessonRepositoryProvider)
                              .updateStatus(lesson.id, value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'scheduled', child: Text('Scheduled'),),
                            PopupMenuItem(
                                value: 'completed', child: Text('Completed'),),
                            PopupMenuItem(
                                value: 'cancelled', child: Text('Cancelled'),),
                          ],
                          child: Chip(label: Text(lesson.status)),
                        )
                      : Chip(label: Text(lesson.status)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
