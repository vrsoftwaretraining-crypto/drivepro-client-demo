// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Run locally with:  flutter run -d chrome --dart-define=USE_EMULATOR=true
/// Production (Firebase Spark/free) is the default: no flag needed.
const useEmulator = bool.fromEnvironment('USE_EMULATOR');

String get _emulatorHost {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2'; // Android emulator -> host PC
  }
  return 'localhost';
}

void connectEmulators(FirebaseApp app) {
  if (!useEmulator) return;
  FirebaseAuth.instanceFor(app: app).useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(_emulatorHost, 8080);
}
