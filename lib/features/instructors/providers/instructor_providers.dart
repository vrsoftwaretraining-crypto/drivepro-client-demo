// Developed by @Ramana Code Softwares

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/models/instructor.dart';
import '../data/instructor_repository.dart';

final instructorRepositoryProvider = Provider<InstructorRepository>((ref) {
  return InstructorRepository(ref.watch(firestoreProvider));
});

final instructorsProvider = StreamProvider<List<Instructor>>((ref) {
  return ref.watch(instructorRepositoryProvider).watchAll();
});
