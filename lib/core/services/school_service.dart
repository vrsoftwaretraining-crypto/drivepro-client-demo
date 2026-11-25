// Developed by @Ramana Code Softwares
//
// All business logic that used to live in Cloud Functions. It uses only
// Firebase Auth + Firestore, so it runs on the free Spark plan and on the
// local Firebase Emulator without any code change.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'emulator.dart';

class SchoolException implements Exception {
  SchoolException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NewAccount {
  const NewAccount(this.uid, this.email, this.temporaryPassword);
  final String uid;
  final String email;
  final String temporaryPassword;
}

class SchoolService {
  SchoolService._();

  static const defaultAdminUsername = 'admin';
  static const defaultAdminEmail = 'admin@drivepro.app';
  static const defaultAdminPassword = 'Admin@12345';
  static const holdMinutes = 15;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------------------------------------------------------------- slots

  static String slotId(String resourceId, DateTime startUtc) =>
      '${resourceId}_${startUtc.millisecondsSinceEpoch}';
  static String vehicleSlotId(String vehicleId, DateTime startUtc) =>
      'v_${vehicleId}_${startUtc.millisecondsSinceEpoch}';

  static bool _blocks(DocumentSnapshot<Map<String, dynamic>> d, {String? ignoreRequestId}) {
    if (!d.exists) return false;
    final data = d.data()!;
    if (ignoreRequestId != null && data['bookingRequestId'] == ignoreRequestId) {
      return false;
    }
    if (data['status'] == 'booked') return true;
    final expiry = (data['holdExpiresAt'] as Timestamp?)?.toDate();
    return data['status'] == 'held' &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
  }

  /// Live list of occupied slots (booked, or held and not expired).
  static Stream<List<Map<String, dynamic>>> watchOccupied() => _db
      .collection('booking_slots')
      .where('startAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
      .snapshots()
      .map((s) => parseOccupied(s.docs.map((d) => d.data())));

  static List<Map<String, dynamic>> parseOccupied(
      Iterable<Map<String, dynamic>> docs) {
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final d in docs) {
      final start = (d['startAt'] as Timestamp?)?.toDate();
      if (start == null) continue;
      final held = d['status'] == 'held';
      final expiry = (d['holdExpiresAt'] as Timestamp?)?.toDate();
      if (held && (expiry == null || !expiry.isAfter(now))) continue;
      if (!held && d['status'] != 'booked') continue;
      out.add({
        'instructorId': d['instructorId'] ?? '',
        'vehicleId': d['vehicleId'] ?? '',
        'startAt': start.toUtc().toIso8601String(),
        'durationMinutes': (d['durationMinutes'] as num?)?.toInt() ?? 60,
        'status': d['status'],
      });
    }
    return out;
  }

  /// Public booking request: transactionally holds the slot for 15 minutes.
  static Future<String> submitBooking({
    required String name,
    required String phone,
    required String email,
    required String course,
    required String instructorId,
    required String instructorName,
    required String vehicleId,
    required String vehicleRegistration,
    required DateTime startUtc,
    required int minutes,
    bool anyInstructor = false,
  }) async {
    final slotRef = _db.collection('booking_slots').doc(slotId(instructorId, startUtc));
    final vRef = _db.collection('booking_slots').doc(vehicleSlotId(vehicleId, startUtc));
    final reqRef = _db.collection('booking_requests').doc();
    final expires = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: holdMinutes)));
    final slotData = {
      'instructorId': instructorId,
      'vehicleId': vehicleId,
      'startAt': Timestamp.fromDate(startUtc),
      'durationMinutes': minutes,
      'status': 'held',
      'holdExpiresAt': expires,
      'bookingRequestId': reqRef.id,
    };
    try {
      await _db.runTransaction((tx) async {
        final a = await tx.get(slotRef);
        final b = await tx.get(vRef);
        if (_blocks(a) || _blocks(b)) {
          throw SchoolException('This slot was just taken. Please choose another.');
        }
        tx.set(slotRef, {...slotData, 'kind': 'instructor'});
        tx.set(vRef, {...slotData, 'kind': 'vehicle'});
        tx.set(reqRef, {
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'course': course,
          'instructorId': instructorId,
          'instructorName': instructorName,
          'vehicleId': vehicleId,
          'vehicleRegistration': vehicleRegistration,
          'anyInstructor': anyInstructor,
          'slotId': slotRef.id,
          'vehicleSlotId': vRef.id,
          'startAt': Timestamp.fromDate(startUtc),
          'durationMinutes': minutes,
          'status': 'pending_admin_contact',
          'paymentStatus': 'unpaid',
          'holdExpiresAt': expires,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw SchoolException(e.code == 'permission-denied'
          ? 'This slot is no longer available. Please choose another.'
          : (e.message ?? 'Could not book this slot.'));
    }
    return reqRef.id;
  }

  static Future<void> submitEnquiry({
    required String name,
    required String phone,
    String message = '',
    String instructorId = '',
    String instructorName = '',
    String slotLabel = '',
  }) async {
    await _db.collection('call_enquiries').add({
      'source': 'web_enquiry',
      'callerName': name.trim(),
      'phoneNumber': phone.trim(),
      'callStatus': 'web enquiry',
      'smsStatus': 'not applicable',
      'instructorId': instructorId,
      'instructorName': instructorName,
      'slotLabel': slotLabel,
      'message': message.trim(),
      'followUpStatus': 'pending',
      'receivedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: confirm payment, (re)assign the slot, mark it BOOKED, activate student.
  static Future<void> confirmBooking({
    required String requestId,
    required double amount,
    required String instructorId,
    required String instructorName,
    required String vehicleId,
    required String vehicleRegistration,
    required DateTime startUtc,
    required int minutes,
    String method = 'manual',
    String reference = '',
  }) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) throw SchoolException('Sign in as admin first.');
    final reqRef = _db.collection('booking_requests').doc(requestId);
    final newSlot = _db.collection('booking_slots').doc(slotId(instructorId, startUtc));
    final newVeh = _db.collection('booking_slots').doc(vehicleSlotId(vehicleId, startUtc));
    try {
      await _db.runTransaction((tx) async {
        final reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) throw SchoolException('Booking request not found.');
        final req = reqSnap.data()!;
        final studentUid = req['studentUserId'] as String? ?? '';
        if (studentUid.isEmpty) {
          throw SchoolException('Create the student account before confirming payment.');
        }
        if (req['status'] == 'confirmed') {
          throw SchoolException('This request is already confirmed.');
        }
        final a = await tx.get(newSlot);
        final b = await tx.get(newVeh);
        if (_blocks(a, ignoreRequestId: requestId) ||
            _blocks(b, ignoreRequestId: requestId)) {
          throw SchoolException('That slot is already booked by someone else. Pick another slot.');
        }
        // Free the originally requested slot if admin moved the student.
        final oldSlot = req['slotId'] as String? ?? '';
        final oldVeh = req['vehicleSlotId'] as String? ?? '';
        if (oldSlot.isNotEmpty && oldSlot != newSlot.id) {
          tx.delete(_db.collection('booking_slots').doc(oldSlot));
        }
        if (oldVeh.isNotEmpty && oldVeh != newVeh.id) {
          tx.delete(_db.collection('booking_slots').doc(oldVeh));
        }
        final booked = {
          'instructorId': instructorId,
          'vehicleId': vehicleId,
          'startAt': Timestamp.fromDate(startUtc),
          'durationMinutes': minutes,
          'status': 'booked',
          'bookingRequestId': requestId,
          'studentUserId': studentUid,
        };
        tx.set(newSlot, {...booked, 'kind': 'instructor'});
        tx.set(newVeh, {...booked, 'kind': 'vehicle'});
        tx.update(reqRef, {
          'status': 'confirmed',
          'paymentStatus': 'paid',
          'paidAmount': amount,
          'instructorId': instructorId,
          'instructorName': instructorName,
          'vehicleId': vehicleId,
          'vehicleRegistration': vehicleRegistration,
          'slotId': newSlot.id,
          'vehicleSlotId': newVeh.id,
          'startAt': Timestamp.fromDate(startUtc),
          'durationMinutes': minutes,
          'paymentConfirmedBy': adminUid,
          'paymentConfirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(_db.collection('users').doc(studentUid), {
          'active': true,
          'paymentStatus': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(_db.collection('students').doc(studentUid), {
          'active': true,
          'paidFee': amount,
          'assignedInstructorId': instructorId,
          'assignedInstructorName': instructorName,
          'assignedVehicleId': vehicleId,
          'assignedVehicleRegistration': vehicleRegistration,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection('lessons').doc(), {
          'studentId': studentUid,
          'studentUserId': studentUid,
          'studentName': req['name'] ?? '',
          'instructorId': instructorId,
          'instructorUserId': instructorId,
          'instructorName': instructorName,
          'vehicleId': vehicleId,
          'vehicleRegistration': vehicleRegistration,
          'startAt': Timestamp.fromDate(startUtc),
          'durationMinutes': minutes,
          'notes': 'Initial lesson created from confirmed booking.',
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection('payments').doc(), {
          'studentId': studentUid,
          'studentUserId': studentUid,
          'studentName': req['name'] ?? '',
          'amount': amount,
          'method': method,
          'reference': reference,
          'status': 'paid',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw SchoolException(e.message ?? e.code);
    }
  }

  /// Admin: copies existing instructors/vehicles into the public mirrors, so
  /// records saved before this update appear on the public slot board.
  static Future<int> syncPublicCatalog() async {
    final instructors = await _db.collection('instructors').get();
    final vehicles = await _db.collection('vehicles').get();
    final batch = _db.batch();
    for (final d in instructors.docs) {
      final m = d.data();
      batch.set(_db.collection('public_instructors').doc(d.id), {
        'name': m['name'] ?? '',
        'photoUrl': m['photoUrl'] ?? '',
        'bio': m['bio'] ?? '',
        'experienceYears': m['experienceYears'] ?? 0,
        'studentsTrained': m['studentsTrained'] ?? 0,
        'achievements': m['achievements'] ?? '',
        'assignedVehicleId': m['assignedVehicleId'] ?? '',
        'workingDays': m['workingDays'] ?? <String>[],
        'workingHours': m['workingHours'] ?? '',
        'active': m['active'] ?? true,
      });
    }
    for (final d in vehicles.docs) {
      final m = d.data();
      batch.set(_db.collection('public_vehicles').doc(d.id), {
        'registrationNumber': m['registrationNumber'] ?? '',
        'makeModel': m['makeModel'] ?? '',
        'transmission': m['transmission'] ?? '',
        'fuelType': m['fuelType'] ?? '',
        'photoUrl': m['photoUrl'] ?? '',
        'active': m['active'] ?? true,
      });
    }
    await batch.commit();
    return instructors.size + vehicles.size;
  }

  // ------------------------------------------------------------- accounts

  static Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app('secondary');
    } catch (_) {
      final app = await Firebase.initializeApp(
        name: 'secondary',
        options: Firebase.app().options,
      );
      connectEmulators(app);
      return app;
    }
  }

  static String _randomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join() + '@7';
  }

  /// Admin creates a login (admin / instructor / student). The app generates a
  /// temporary password; the user must change it at first login.
  static Future<NewAccount> createAccount({
    required String role,
    required String name,
    required String email,
    required String phone,
    Map<String, dynamic> extra = const {},
    String? bookingRequestId,
    Map<String, dynamic>? bookingRequest,
  }) async {
    final mail = email.trim().toLowerCase();
    final temp = _randomPassword();
    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    String uid;
    try {
      final cred = await auth.createUserWithEmailAndPassword(email: mail, password: temp);
      uid = cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw SchoolException(e.code == 'email-already-in-use'
          ? 'An account already exists for this email.'
          : (e.message ?? 'Could not create the account.'));
    } finally {
      await auth.signOut();
    }

    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid), {
      'uid': uid,
      'name': name.trim(),
      'email': mail,
      'username': mail,
      'phone': phone.trim(),
      'role': role,
      'active': role != 'student',
      'paymentStatus': role == 'student' ? 'pending' : 'not_required',
      'mustChangePassword': true,
      'securityQuestionsSet': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('login_index').doc(mail), {'email': mail, 'uid': uid});
    if (role == 'student') {
      final r = bookingRequest ?? {};
      batch.set(_db.collection('students').doc(uid), {
        'userId': uid,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': mail,
        'course': extra['course'] ?? r['course'] ?? 'Driving course',
        'totalFee': extra['totalFee'] ?? 0,
        'paidFee': 0,
        'active': false,
        'bookingRequestId': bookingRequestId,
        'assignedInstructorId': r['instructorId'] ?? '',
        'assignedInstructorName': r['instructorName'] ?? '',
        'assignedVehicleId': r['vehicleId'] ?? '',
        'assignedVehicleRegistration': r['vehicleRegistration'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (bookingRequestId != null) {
        batch.update(_db.collection('booking_requests').doc(bookingRequestId), {
          'studentUserId': uid,
          'status': 'registration_created_pending_payment',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else if (role == 'instructor') {
      final days = extra['workingDays'] ?? <String>[];
      final profile = {
        'name': name.trim(),
        'assignedVehicleId': extra['assignedVehicleId'] ?? '',
        'workingDays': days,
        'workingHours': extra['workingHours'] ?? '',
        'active': true,
        'experienceYears': extra['experienceYears'] ?? 0,
        'studentsTrained': extra['studentsTrained'] ?? 0,
        'achievements': extra['achievements'] ?? '',
        'bio': '',
        'photoUrl': '',
      };
      batch.set(_db.collection('instructors').doc(uid), {
        ...profile,
        'phone': phone.trim(),
        'email': mail,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_db.collection('public_instructors').doc(uid), profile);
    }
    await batch.commit();
    return NewAccount(uid, mail, temp);
  }

  /// First visit: creates admin/Admin@12345 once (only if never bootstrapped).
  /// Uses a secondary app so the visitor is never signed in as admin.
  static Future<void> ensureDefaultAdmin() async {
    final marker = await _db.collection('system').doc('bootstrap').get();
    if (marker.exists) return;
    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    try {
      final cred = await auth.createUserWithEmailAndPassword(
          email: defaultAdminEmail, password: defaultAdminPassword);
      final uid = cred.user!.uid;
      final batch = db.batch();
      batch.set(db.collection('users').doc(uid), {
        'uid': uid,
        'name': 'Administrator',
        'username': defaultAdminUsername,
        'email': defaultAdminEmail,
        'role': 'admin',
        'active': true,
        'mustChangePassword': true,
        'securityQuestionsSet': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(db.collection('system').doc('bootstrap'), {
        'createdAt': FieldValue.serverTimestamp(),
        'by': uid,
      });
      await batch.commit();
      // Second step: the admin profile now exists, so the index writes pass the rules.
      final idx = db.batch();
      idx.set(db.collection('login_index').doc(defaultAdminUsername),
          {'email': defaultAdminEmail, 'uid': uid});
      idx.set(db.collection('login_index').doc(defaultAdminEmail),
          {'email': defaultAdminEmail, 'uid': uid});
      await idx.commit();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
    } finally {
      await auth.signOut();
    }
  }

  // ------------------------------------------------- login / recovery

  /// Username (e.g. "admin") or email -> login email.
  static Future<String> resolveEmail(String idOrEmail) async {
    final id = idOrEmail.trim().toLowerCase();
    if (id.contains('@')) return id;
    final snap = await _db.collection('login_index').doc(id).get();
    return (snap.data()?['email'] as String?) ?? id;
  }

  static String _normalize(String a) =>
      a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _hash(String answer, String salt) {
    var digest = sha256.convert(utf8.encode('$salt|${_normalize(answer)}'));
    for (var i = 0; i < 5000; i++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
    }
    return digest.toString();
  }

  static String _salt() {
    final r = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => r.nextInt(256)));
  }

  /// Signed-in user saves 3 questions (answers stored only as salted hashes).
  static Future<void> saveSecurityQuestions(List<Map<String, String>> items) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw SchoolException('Sign in first.');
    if (items.length != 3 || items.map((e) => e['question']).toSet().length != 3) {
      throw SchoolException('Choose 3 different questions.');
    }
    final salts = List.generate(3, (_) => _salt());
    final mail = (user.email ?? '').toLowerCase();
    final batch = _db.batch();
    batch.set(_db.collection('recovery').doc(user.uid), {
      'uid': user.uid,
      'questions': items.map((e) => e['question']).toList(),
      'salts': salts,
      'hashes': [for (var i = 0; i < 3; i++) _hash(items[i]['answer']!, salts[i])],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('users').doc(user.uid), {
      'securityQuestionsSet': true,
      'mustChangePassword': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    if (mail.isNotEmpty) {
      await _db.collection('login_index').doc(mail).set({'email': mail, 'uid': user.uid});
    }
  }

  static Future<Map<String, dynamic>?> _recoveryFor(String idOrEmail) async {
    final idx = await _db.collection('login_index').doc(idOrEmail.trim().toLowerCase()).get();
    final uid = idx.data()?['uid'] as String?;
    if (uid == null) return null;
    final rec = await _db.collection('recovery').doc(uid).get();
    final data = rec.data();
    if (data == null) return null;
    return {...data, 'email': idx.data()!['email']};
  }

  static Future<List<String>> getSecurityQuestions(String idOrEmail) async {
    final rec = await _recoveryFor(idOrEmail);
    if (rec == null) {
      throw SchoolException('No security questions are saved for this account. Ask the admin.');
    }
    return (rec['questions'] as List<dynamic>).cast<String>();
  }

  /// Checks all 3 answers, then sends a Firebase password-reset email to the
  /// registered address (no server needed).
  static Future<String> resetWithAnswers(String idOrEmail, List<String> answers) async {
    final rec = await _recoveryFor(idOrEmail);
    if (rec == null) throw SchoolException('The answers did not match.');
    final salts = (rec['salts'] as List<dynamic>).cast<String>();
    final hashes = (rec['hashes'] as List<dynamic>).cast<String>();
    var ok = answers.length == 3;
    for (var i = 0; ok && i < 3; i++) {
      if (_hash(answers[i], salts[i]) != hashes[i]) ok = false;
    }
    if (!ok) throw SchoolException('The answers did not match.');
    final email = rec['email'] as String;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    return email;
  }
}
