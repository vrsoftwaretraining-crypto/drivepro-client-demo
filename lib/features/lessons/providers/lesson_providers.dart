// Developed by @Ramana Code Softwares

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/lesson.dart';
import '../../../core/providers/auth_providers.dart';
import '../data/lesson_repository.dart';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(ref.watch(firestoreProvider));
});

final lessonsProvider = StreamProvider<List<DrivingLesson>>((ref) {
  return ref.watch(lessonRepositoryProvider).watchLessons();
});
