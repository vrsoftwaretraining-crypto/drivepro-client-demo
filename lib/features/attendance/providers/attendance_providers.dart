// Developed by @Ramana Code Softwares

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/attendance.dart';
import '../../../core/providers/auth_providers.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider =
    Provider((ref) => AttendanceRepository(ref.watch(firestoreProvider)));
final attendanceProvider = StreamProvider<List<LessonAttendance>>(
    (ref) => ref.watch(attendanceRepositoryProvider).watch());
