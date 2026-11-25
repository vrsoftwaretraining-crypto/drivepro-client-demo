// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Build with  --dart-define=DEMO_MODE=true  to run the whole app with NO Firebase project and NO database.
/// Every screen works on in-memory sample data (see core/demo/demo_backend.dart); nothing is stored anywhere.
/// The normal (production) build never sets this flag.
const demoMode = bool.fromEnvironment('DEMO_MODE');

/// Single access point for Firestore and Auth. Production uses the real Firebase instances;
/// the demo build installs in-memory fakes once at start-up.
class Backend {
  Backend._();

  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;

  static FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  static FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  static void useFakes(FirebaseFirestore firestore, FirebaseAuth auth) {
    _firestore = firestore;
    _auth = auth;
  }
}
