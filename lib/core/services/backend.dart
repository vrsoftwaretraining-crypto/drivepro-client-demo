// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Build demo using:
/// --dart-define=DEMO_MODE=true
///
/// Demo mode must never fall back to real Firebase instances.
const demoMode = bool.fromEnvironment('DEMO_MODE');

class Backend {
  Backend._();

  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;

  /// Firestore access point.
  ///
  /// Demo mode: FakeFirestore only.
  /// Production mode: Real Firebase Firestore.
  static FirebaseFirestore get firestore {
    if (demoMode) {
      final instance = _firestore;

      if (instance == null) {
        throw StateError(
          'Demo Firestore is not initialized. '
          'Call DemoBackend.install() before runApp().',
        );
      }

      return instance;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  /// Authentication access point.
  ///
  /// Demo mode: DemoAuth only.
  /// Production mode: Real Firebase Authentication.
  static FirebaseAuth get auth {
    if (demoMode) {
      final instance = _auth;

      if (instance == null) {
        throw StateError(
          'Demo Authentication is not initialized. '
          'Call DemoBackend.install() before runApp().',
        );
      }

      return instance;
    }

    return _auth ?? FirebaseAuth.instance;
  }

  /// Installs in-memory fake services for demo builds.
  static void useFakes(
    FirebaseFirestore firestore,
    FirebaseAuth auth,
  ) {
    if (!demoMode) {
      throw StateError(
        'Fake Firebase services can only be installed in demo mode.',
      );
    }

    _firestore = firestore;
    _auth = auth;
  }
}
