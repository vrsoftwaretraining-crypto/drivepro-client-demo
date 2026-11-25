// Developed by @Ramana Code Softwares
//
// DEMO BUILD ONLY (--dart-define=DEMO_MODE=true). An in-memory Firestore and a fake sign-in that
// run entirely inside the browser tab. Nothing is sent to any server and nothing is saved: reload the page
// and the sample data is back to its starting state.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/backend.dart';

/// Demo logins shown at the top of the demo build.
const demoAdminEmail = 'admin@demo.com';
const demoInstructorEmail = 'instructor@demo.com';
const demoStudentEmail = 'student@demo.com';

class DemoBackend {
  DemoBackend._();

  /// Demo sign-in accounts (email -> uid), kept in memory so sign-in never depends on a database query.
  static final Map<String, String> accounts = {};
  static Future<void>? _installFuture;

  /// Safe to call from startup and again from a portal button.
  /// The same in-memory backend instance is installed only once.
  static Future<void> install() {
    return _installFuture ??= _installOnce();
  }

  static Future<void> _installOnce() async {
    final db = FakeFirebaseFirestore();
    // Install the fakes FIRST, so the app can never fall back to the real Firebase in the demo build.
    Backend.useFakes(db, DemoAuth(db));
    try {
      // The three sign-in accounts come first: even if some sample data below fails, login still works.
      await _user(db, 'admin1', 'School Admin', demoAdminEmail, 'admin', username: 'admin', phone: '9876543210');
      await _user(db, 'ins1', 'Ramesh Kumar', demoInstructorEmail, 'instructor', phone: '9876500001');
      await _user(db, 'stu1', 'Anil Sharma', demoStudentEmail, 'student', phone: '9000000001');
    } catch (e, st) {
      debugPrint('Demo accounts could not be created: $e\n$st');
    }
    try {
      await _seed(db);
    } catch (e, st) {
      debugPrint('Demo sample data stopped early: $e\n$st');
    }
  }

  static Timestamp _t(DateTime d) => Timestamp.fromDate(d);

  static Future<void> _seed(FakeFirebaseFirestore db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int dayOffset, int hour) => today.add(Duration(days: dayOffset, hours: hour));

    Future<void> put(String col, String id, Map<String, dynamic> data) => db.collection(col).doc(id).set(data);

    // ---- school info (public website + settings)
    final school = {
      'name': 'DrivePro Driving School',
      'schoolName': 'DrivePro Driving School',
      'phone': '+91 98765 43210',
      'alternatePhone': '+91 91234 56780',
      'email': 'hello@drivepro.demo',
      'address': '12, Main Road, Madhapur, Hyderabad - 500081',
      'location': 'Hyderabad, Telangana',
      'mapUrl': 'https://maps.google.com',
      'websiteUrl': 'https://drivepro.demo',
      'facebookUrl': '',
      'instagramUrl': '',
      'notes': 'Bring your learner licence and a photo ID on the first day.',
      'openTime': '06:00',
      'closeTime': '20:00',
      'slotMinutes': 120,
    };
    await put('public_info', 'school', school);
    await put('school_settings', 'general', school);
    await put('system', 'bootstrap', {'done': true});

    // ---- vehicles (+ public mirror)
    final vehicles = <String, Map<String, dynamic>>{
      'v1': {'registrationNumber': 'TS 09 AB 1234', 'makeModel': 'Maruti Swift', 'transmission': 'Manual', 'fuelType': 'Petrol', 'insuranceExpiry': _t(at(18, 0)), 'fcExpiry': _t(at(240, 0)), 'photoUrl': '', 'active': true},
      'v2': {'registrationNumber': 'TS 09 CD 5678', 'makeModel': 'Hyundai i10', 'transmission': 'Automatic', 'fuelType': 'Petrol', 'insuranceExpiry': _t(at(150, 0)), 'fcExpiry': _t(at(25, 0)), 'photoUrl': '', 'active': true},
      'v3': {'registrationNumber': 'TS 10 EF 9012', 'makeModel': 'Honda Activa', 'transmission': 'Automatic', 'fuelType': 'Petrol', 'insuranceExpiry': _t(at(300, 0)), 'fcExpiry': _t(at(320, 0)), 'photoUrl': '', 'active': true},
    };
    for (final e in vehicles.entries) {
      await put('vehicles', e.key, {...e.value, 'createdAt': _t(at(-120, 9))});
      await put('public_vehicles', e.key, {
        'registrationNumber': e.value['registrationNumber'], 'makeModel': e.value['makeModel'], 'transmission': e.value['transmission'],
        'fuelType': e.value['fuelType'], 'photoUrl': '', 'active': true,
      });
    }

    // ---- instructors (+ login users + public mirror)
    final instructors = <String, Map<String, dynamic>>{
      'ins1': {'name': 'Ramesh Kumar', 'phone': '9876500001', 'email': demoInstructorEmail, 'licenseNumber': 'DL-TS-2011-0456', 'bio': '12 years of patient, calm teaching.', 'experienceYears': 12, 'studentsTrained': 640, 'achievements': 'Best instructor 2024', 'assignedVehicleId': 'v1', 'workingDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'], 'workingHours': '06:00 - 20:00'},
      'ins2': {'name': 'Sunitha Reddy', 'phone': '9876500002', 'email': 'sunitha@demo.com', 'licenseNumber': 'DL-TS-2015-0987', 'bio': 'Specialist for first-time and nervous learners.', 'experienceYears': 8, 'studentsTrained': 410, 'achievements': 'Ladies batch coach', 'assignedVehicleId': 'v2', 'workingDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'], 'workingHours': '06:00 - 18:00'},
      'ins3': {'name': 'Vikram Singh', 'phone': '9876500003', 'email': 'vikram@demo.com', 'licenseNumber': 'DL-TS-2018-1342', 'bio': 'Two-wheeler and highway practice.', 'experienceYears': 5, 'studentsTrained': 220, 'achievements': '', 'assignedVehicleId': 'v3', 'workingDays': ['Tuesday', 'Thursday', 'Saturday', 'Sunday'], 'workingHours': '08:00 - 18:00'},
    };
    for (final e in instructors.entries) {
      final m = e.value;
      await put('instructors', e.key, {...m, 'photoUrl': '', 'active': true, 'userId': e.key, 'createdAt': _t(at(-200, 9))});
      await put('public_instructors', e.key, {
        'name': m['name'], 'photoUrl': '', 'bio': m['bio'], 'experienceYears': m['experienceYears'], 'studentsTrained': m['studentsTrained'],
        'achievements': m['achievements'], 'assignedVehicleId': m['assignedVehicleId'], 'workingDays': m['workingDays'], 'workingHours': m['workingHours'], 'active': true,
      });
      await _user(db, e.key, m['name'] as String, m['email'] as String, 'instructor', phone: m['phone'] as String);
    }

    // ---- admin
    await _user(db, 'admin1', 'School Admin', demoAdminEmail, 'admin', username: 'admin', phone: '9876543210');

    // ---- students (+ login user for the first one)
    final students = <Map<String, dynamic>>[
      {'id': 'stu1', 'name': 'Anil Sharma', 'phone': '9000000001', 'email': demoStudentEmail, 'course': 'Car - 30 day course', 'total': 6500, 'paid': 4000, 'ins': 'ins1', 'veh': 'v1', 'user': true, 'ago': 40},
      {'id': 'stu2', 'name': 'Priya Nair', 'phone': '9000000002', 'email': 'priya@demo.com', 'course': 'Car - 30 day course', 'total': 6500, 'paid': 6500, 'ins': 'ins2', 'veh': 'v2', 'ago': 35},
      {'id': 'stu3', 'name': 'Mohammed Irfan', 'phone': '9000000003', 'email': 'irfan@demo.com', 'course': 'Two-wheeler course', 'total': 3000, 'paid': 1500, 'ins': 'ins3', 'veh': 'v3', 'ago': 22},
      {'id': 'stu4', 'name': 'Kavya Rao', 'phone': '9000000004', 'email': 'kavya@demo.com', 'course': 'Car - refresher', 'total': 3500, 'paid': 0, 'ins': 'ins1', 'veh': 'v1', 'ago': 9},
      {'id': 'stu5', 'name': 'Sanjay Verma', 'phone': '9000000005', 'email': 'sanjay@demo.com', 'course': 'Car - 30 day course', 'total': 6500, 'paid': 2500, 'ins': 'ins2', 'veh': 'v2', 'ago': 15},
      {'id': 'stu6', 'name': 'Divya Menon', 'phone': '9000000006', 'email': 'divya@demo.com', 'course': 'Licence test preparation', 'total': 2000, 'paid': 2000, 'ins': 'ins3', 'veh': 'v3', 'ago': 60, 'active': false},
    ];
    for (final s in students) {
      final ins = instructors[s['ins']]!, veh = vehicles[s['veh']]!;
      await put('students', s['id'] as String, {
        'userId': s['user'] == true ? s['id'] : '', 'name': s['name'], 'phone': s['phone'], 'email': s['email'], 'course': s['course'],
        'totalFee': s['total'], 'paidFee': s['paid'], 'active': s['active'] ?? true,
        'assignedInstructorId': s['ins'], 'assignedInstructorName': ins['name'], 'assignedVehicleId': s['veh'], 'assignedVehicleRegistration': veh['registrationNumber'],
        'createdAt': _t(at(-(s['ago'] as int), 10)), 'updatedAt': _t(at(-1, 10)),
      });
      if (s['user'] == true) await _user(db, s['id'] as String, s['name'] as String, s['email'] as String, 'student', phone: s['phone'] as String);
    }

    // ---- payments
    var receipt = 1000;
    Future<void> pay(String sid, int amount, String method, int daysAgo, [String note = '']) async {
      final st = students.firstWhere((x) => x['id'] == sid);
      receipt++;
      await db.collection('payments').add({
        'studentId': sid, 'studentUserId': st['user'] == true ? sid : '', 'studentName': st['name'], 'amount': amount, 'method': method,
        'receiptNo': 'RC-$receipt', 'notes': note, 'paidAt': _t(at(-daysAgo, 11)), 'createdAt': _t(at(-daysAgo, 11)),
      });
    }
    await pay('stu1', 2500, 'upi', 38, 'Advance');
    await pay('stu1', 1500, 'cash', 20);
    await pay('stu2', 6500, 'card', 34, 'Full fee');
    await pay('stu3', 1500, 'upi', 21, 'Advance');
    await pay('stu5', 2500, 'cash', 14);
    await pay('stu6', 2000, 'cash', 58, 'Full fee');

    // ---- lessons, attendance and the booked slots they occupy
    var lessonNo = 0;
    Future<void> lesson(String sid, int day, int hour, String status, {String? attendance, String notes = ''}) async {
      final st = students.firstWhere((x) => x['id'] == sid);
      final iid = st['ins'] as String, vid = st['veh'] as String;
      final start = at(day, hour);
      lessonNo++;
      final ref = db.collection('lessons').doc('les$lessonNo');
      await ref.set({
        'studentId': sid, 'studentName': st['name'], 'studentUserId': st['user'] == true ? sid : '',
        'instructorId': iid, 'instructorName': instructors[iid]!['name'], 'instructorUserId': iid,
        'vehicleId': vid, 'vehicleRegistration': vehicles[vid]!['registrationNumber'],
        'startAt': _t(start), 'durationMinutes': 120, 'notes': notes, 'status': status, 'createdAt': _t(start.subtract(const Duration(days: 3))),
      });
      if (status != 'cancelled') {
        await db.collection('booking_slots').doc('${iid}_${start.toUtc().millisecondsSinceEpoch}').set({'instructorId': iid, 'vehicleId': vid, 'startAt': _t(start.toUtc()), 'durationMinutes': 120, 'status': 'booked', 'kind': 'instructor'});
        await db.collection('booking_slots').doc('v_${vid}_${start.toUtc().millisecondsSinceEpoch}').set({'instructorId': iid, 'vehicleId': vid, 'startAt': _t(start.toUtc()), 'durationMinutes': 120, 'status': 'booked', 'kind': 'vehicle'});
      }
      if (attendance != null) {
        await db.collection('attendance').add({
          'lessonId': ref.id, 'studentId': sid, 'studentName': st['name'], 'studentUserId': st['user'] == true ? sid : '',
          'instructorName': instructors[iid]!['name'], 'instructorUserId': iid, 'lessonAt': _t(start), 'status': attendance, 'notes': notes,
        });
      }
    }
    await lesson('stu1', -6, 7, 'completed', attendance: 'present', notes: 'Clutch control practice');
    await lesson('stu1', -3, 7, 'completed', attendance: 'late', notes: 'Reverse parking');
    await lesson('stu1', 1, 7, 'scheduled', notes: 'City driving');
    await lesson('stu1', 4, 9, 'scheduled');
    await lesson('stu2', -5, 8, 'completed', attendance: 'present');
    await lesson('stu2', 2, 8, 'scheduled');
    await lesson('stu3', -2, 10, 'completed', attendance: 'absent', notes: 'Did not attend');
    await lesson('stu3', 3, 10, 'scheduled');
    await lesson('stu5', 0, 16, 'scheduled', notes: 'Highway practice');
    await lesson('stu4', 5, 12, 'cancelled', notes: 'Student asked to reschedule');

    // ---- public booking requests (admin "Booking requests" page)
    Future<void> request(String name, String phone, String email, String course, String iid, int day, int hour, String status, String payment, int hoursAgo) async {
      final start = at(day, hour);
      await db.collection('booking_requests').add({
        'name': name, 'phone': phone, 'email': email, 'course': course, 'instructorId': iid, 'instructorName': instructors[iid]!['name'],
        'vehicleId': instructors[iid]!['assignedVehicleId'], 'vehicleRegistration': vehicles[instructors[iid]!['assignedVehicleId']]!['registrationNumber'],
        'anyInstructor': false, 'pickupAddress': name == 'Rahul Gupta' ? 'Flat 302, Green Heights, Madhapur, Hyderabad' : (name == 'Neha Joshi' ? 'H.No. 8-2-120, Kukatpally, Hyderabad' : 'Road No. 5, Hanamkonda, Warangal'), 'startAt': _t(start.toUtc()), 'durationMinutes': 120, 'status': status, 'paymentStatus': payment,
        'createdAt': _t(now.subtract(Duration(hours: hoursAgo))),
      });
    }
    await request('Rahul Gupta', '9111111111', 'rahul@demo.com', 'Car - 30 day course', 'ins1', 6, 8, 'pending_admin_contact', 'unpaid', 3);
    await request('Neha Joshi', '9222222222', 'neha@demo.com', 'Two-wheeler course', 'ins3', 7, 10, 'pending_admin_contact', 'unpaid', 20);
    await request('Arjun Das', '9333333333', 'arjun@demo.com', 'Car - refresher', 'ins2', 8, 14, 'registration_created_pending_payment', 'unpaid', 30);

    // ---- call enquiries
    Future<void> enquiry(String name, String phone, String source, String call, String follow, int hoursAgo, {String message = '', String notes = ''}) async {
      await db.collection('call_enquiries').add({
        'source': source, 'callerName': name, 'phoneNumber': phone, 'callStatus': call, 'smsStatus': source == 'web_enquiry' ? 'not applicable' : 'sent',
        'instructorId': '', 'instructorName': '', 'slotLabel': '', 'message': message, 'followUpStatus': follow, 'followUpNotes': notes,
        'receivedAt': _t(now.subtract(Duration(hours: hoursAgo))),
      });
    }
    await enquiry('Suresh Babu', '9444444444', 'missed_call', 'missed', 'pending', 2);
    await enquiry('Lakshmi', '9555555555', 'web_enquiry', 'web enquiry', 'pending', 7, message: 'Need car classes on weekends. What are the fees?');
    await enquiry('Imran', '9666666666', 'missed_call', 'missed', 'contacted', 28, notes: 'Called back, will join next week');

    // ---- Schedule module: the slots the admin created (website and student login show these)
    const slotLocations = {'ins1': 'Madhapur, Hyderabad', 'ins2': 'Kukatpally, Hyderabad', 'ins3': 'Hanamkonda, Warangal'};
    const slotCourses = {'ins1': ['Car - 30 day course', '30 days'], 'ins2': ['Car - 30 day course', '30 days'], 'ins3': ['Two-wheeler course', '15 days']};
    final slotIds = <String, String>{};
    for (var day = 1; day <= 7; day++) {
      for (final iid in ['ins1', 'ins2', 'ins3']) {
        for (final hour in [8, 10, 16]) {
          if (iid == 'ins3' && hour == 10) continue;
          final ins = instructors[iid]!;
          final veh = vehicles[ins['assignedVehicleId']]!;
          final ref = db.collection('schedule_slots').doc();
          slotIds['$iid-$day-$hour'] = ref.id;
          await ref.set({
            'startAt': _t(at(day, hour)), 'durationMinutes': 60, 'location': slotLocations[iid], 'vehicleId': ins['assignedVehicleId'],
            'vehicleName': '${veh['registrationNumber']} • ${veh['makeModel']}', 'instructorId': iid, 'instructorName': ins['name'],
            'courseName': slotCourses[iid]![0], 'courseDuration': slotCourses[iid]![1], 'fee': iid == 'ins3' ? 3000 : 6500,
            'status': 'available', 'bookingId': '', 'createdAt': _t(at(-1, 9)), 'updatedAt': _t(at(-1, 9)),
          });
        }
      }
    }
    Future<void> bookSlot(String key, String iid, int day, int hour, String name, String phone, String email, String status, {String userId = '', String studentId = ''}) async {
      final slotId = slotIds[key]!;
      final ins = instructors[iid]!;
      final veh = vehicles[ins['assignedVehicleId']]!;
      final ref = db.collection('slot_bookings').doc();
      await ref.set({
        'slotId': slotId, 'studentUserId': userId, 'studentId': studentId, 'name': name, 'phone': phone, 'email': email, 'notes': '', 'status': status,
        'startAt': _t(at(day, hour)), 'durationMinutes': 60, 'location': slotLocations[iid], 'pickupAddress': iid == 'ins1' ? 'Flat 12, Madhapur Main Road, Hyderabad' : (iid == 'ins2' ? 'Near Metro Station, Kukatpally, Hyderabad' : 'Nakkalagutta, Hanamkonda, Warangal'), 'vehicleName': '${veh['registrationNumber']} • ${veh['makeModel']}',
        'instructorId': iid, 'instructorName': ins['name'], 'courseName': slotCourses[iid]![0], 'lessonId': '', 'createdAt': _t(now.subtract(const Duration(hours: 5))),
      });
      await db.collection('schedule_slots').doc(slotId).update({'status': 'booked', 'bookingId': ref.id});
    }
    await bookSlot('ins1-1-8', 'ins1', 1, 8, 'Anil Sharma', '9000000001', demoStudentEmail, 'pending', userId: 'stu1', studentId: 'stu1');
    await bookSlot('ins2-2-10', 'ins2', 2, 10, 'Rahul Gupta', '9111111111', 'rahul@demo.com', 'confirmed');
    await bookSlot('ins3-3-8', 'ins3', 3, 8, 'Neha Joshi', '9222222222', 'neha@demo.com', 'pending');
    await db.collection('schedule_slots').doc(slotIds['ins1-4-16']!).update({'status': 'cancelled'});

    // ---- reminders
    await db.collection('reminders').add({'title': 'Renew Swift insurance', 'details': 'TS 09 AB 1234 insurance ends soon', 'dueAt': _t(at(10, 10)), 'completed': false, 'createdAt': _t(at(-2, 9))});
    await db.collection('reminders').add({'title': 'Call pending fee students', 'details': 'Kavya Rao, Sanjay Verma', 'dueAt': _t(at(1, 11)), 'completed': false, 'createdAt': _t(at(-1, 9))});
    await db.collection('reminders').add({'title': 'Print certificates for batch 14', 'details': '', 'dueAt': _t(at(-3, 11)), 'completed': true, 'createdAt': _t(at(-6, 9))});
  }

  static Future<void> _user(FakeFirebaseFirestore db, String uid, String name, String email, String role, {String username = '', String phone = ''}) async {
    await db.collection('users').doc(uid).set({
      'uid': uid, 'name': name, 'email': email, 'username': username.isEmpty ? email : username, 'phone': phone, 'role': role,
      'active': true, 'paymentStatus': role == 'student' ? 'paid' : 'not_required', 'mustChangePassword': false, 'securityQuestionsSet': true,
      'createdAt': Timestamp.now(), 'updatedAt': Timestamp.now(),
    });
    accounts[email.toLowerCase()] = uid;
    await db.collection('login_index').doc(email).set({'email': email, 'uid': uid});
    if (username.isNotEmpty) await db.collection('login_index').doc(username).set({'email': email, 'uid': uid});
  }
}

// ------------------------------------------------------------------ fake sign-in

class DemoUser implements User {
  DemoUser(this.uid, this.email);

  @override
  final String uid;
  @override
  final String? email;
  @override
  String? get displayName => null;
  @override
  bool get emailVerified => true;

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoCredential implements UserCredential {
  _DemoCredential(this._user);
  final User _user;

  @override
  User? get user => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Accepts any password for the sample accounts (admin / instructor / student) and for accounts
/// created inside the demo. Unknown emails get the normal "incorrect" message.
class DemoAuth implements FirebaseAuth {
  DemoAuth(this._db);

  final FakeFirebaseFirestore _db;
  final _changes = StreamController<User?>.broadcast();
  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  /// Select a seeded demo role directly; never calls Firebase Authentication.
  void selectDemoRole(String role) {
    final normalized = role.trim().toLowerCase();
    final entry = <String, String>{
      'admin': demoAdminEmail,
      'instructor': demoInstructorEmail,
      'student': demoStudentEmail,
    }[normalized];
    if (entry == null) throw ArgumentError.value(role, 'role', 'Unknown demo role');
    final uid = DemoBackend.accounts[entry];
    if (uid == null) throw StateError('Demo account for $normalized was not seeded');
    _user = DemoUser(uid, entry);
    _changes.add(_user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    final mail = email.trim().toLowerCase();
    if (!mail.contains('@')) throw FirebaseAuthException(code: 'invalid-email');
    var uid = DemoBackend.accounts[mail];
    if (uid == null) {
      // Demo-only fallback: role shortcuts must never depend on a password or
      // on Firebase credentials. Map common portal labels to seeded demo users.
      if (mail.contains('admin')) {
        uid = 'admin1';
      } else if (mail.contains('instructor') || mail.contains('teacher')) {
        uid = 'ins1';
      } else if (mail.contains('student') || mail.contains('learner')) {
        uid = 'stu1';
      } else {
        // Accounts created inside the demo (Admin > create student/instructor).
        final found = await _db.collection('users').where('email', isEqualTo: mail).limit(1).get();
        if (found.docs.isNotEmpty) uid = found.docs.first.id;
      }
    }
    // In this isolated demo build the password is intentionally ignored.
    if (uid == null) throw FirebaseAuthException(code: 'user-not-found');
    _user = DemoUser(uid, mail);
    _changes.add(_user);
    return _DemoCredential(_user!);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
