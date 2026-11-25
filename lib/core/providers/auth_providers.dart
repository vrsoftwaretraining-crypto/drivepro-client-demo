// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/backend.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => Backend.auth,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => Backend.firestore,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return null;

  final snapshot = await ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(authUser.uid)
      .get();

  if (!snapshot.exists || snapshot.data() == null) return null;
  return AppUser.fromMap(authUser.uid, snapshot.data()!);
});
