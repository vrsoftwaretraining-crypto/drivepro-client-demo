// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/schedule_slot.dart';
import '../../../core/services/backend.dart';

/// A problem the person can understand and act on (shown as-is in a message).
class ScheduleException implements Exception {
  ScheduleException(this.message);
  final String message;
  @override
  String toString() => message;
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) => ScheduleRepository());

/// All scheduling reads and writes. Every screen (admin Schedule module, public website,
/// student portal, instructor portal) uses the same `schedule_slots` data, so a change made by the admin
/// or a booking made by a student shows up everywhere at once.
class ScheduleRepository {
  ScheduleRepository([FirebaseFirestore? db]) : _db = db ?? Backend.firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _slots => _db.collection('schedule_slots');
  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('slot_bookings');

  static String _stamp(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

  // ------------------------------------------------------------------ reads

  /// Public + student view: every future slot (the screen hides cancelled ones).
  Stream<List<ScheduleSlot>> watchUpcoming() => _slots
      .where('startAt', isGreaterThan: Timestamp.now())
      .orderBy('startAt')
      .limit(400)
      .snapshots()
      .map((s) => s.docs.map((d) => ScheduleSlot.fromMap(d.id, d.data())).toList());

  /// Admin view for a date range.
  Stream<List<ScheduleSlot>> watchRange(DateTime from, [DateTime? to]) {
    Query<Map<String, dynamic>> q = _slots.where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (to != null) q = q.where('startAt', isLessThan: Timestamp.fromDate(to));
    return q.orderBy('startAt').limit(600).snapshots().map((s) => s.docs.map((d) => ScheduleSlot.fromMap(d.id, d.data())).toList());
  }

  /// Instructor view: their own slots, soonest first.
  Stream<List<ScheduleSlot>> watchForInstructor(String instructorId) =>
      _slots.where('instructorId', isEqualTo: instructorId).snapshots().map((s) {
        final list = s.docs.map((d) => ScheduleSlot.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.startAt.compareTo(b.startAt));
        return list;
      });

  Stream<List<SlotBooking>> watchBookings() => _bookings
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map((d) => SlotBooking.fromMap(d.id, d.data())).toList());

  Stream<List<SlotBooking>> watchMyBookings(String uid) => _bookings.where('studentUserId', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map((d) => SlotBooking.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => b.startAt.compareTo(a.startAt));
        return list;
      });

  Future<SlotBooking?> getBooking(String id) async {
    if (id.isEmpty) return null;
    final snap = await _bookings.doc(id).get();
    final data = snap.data();
    return data == null ? null : SlotBooking.fromMap(snap.id, data);
  }

  // ------------------------------------------------------------------ admin: create / edit

  /// Returns a message when the instructor or the vehicle is already busy at that time, otherwise null.
  Future<String?> findConflict(ScheduleSlot slot, {String ignoreId = ''}) async {
    final dayStart = DateTime(slot.startAt.year, slot.startAt.month, slot.startAt.day);
    final snap = await _slots
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('startAt', isLessThan: Timestamp.fromDate(dayStart.add(const Duration(days: 1))))
        .get();
    for (final d in snap.docs) {
      if (d.id == ignoreId) continue;
      final other = ScheduleSlot.fromMap(d.id, d.data());
      if (other.status == 'cancelled') continue;
      final overlap = slot.startAt.isBefore(other.endAt) && other.startAt.isBefore(slot.endAt);
      if (!overlap) continue;
      if (other.instructorId == slot.instructorId) {
        return '${other.instructorName} already has a slot on ${_stamp(other.startAt)}. Choose another time or instructor.';
      }
      if (other.vehicleId == slot.vehicleId) {
        return '${other.vehicleName} is already used on ${_stamp(other.startAt)}. Choose another time or vehicle.';
      }
    }
    return null;
  }

  Future<void> createSlots(List<ScheduleSlot> slots) async {
    for (var i = 0; i < slots.length; i += 400) {
      final batch = _db.batch();
      for (final s in slots.skip(i).take(400)) {
        batch.set(_slots.doc(), {
          ...s.toMap(),
          'status': 'available',
          'bookingId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> updateSlot(ScheduleSlot s) async {
    final map = s.toMap()
      ..remove('status')
      ..remove('bookingId');
    await _slots.doc(s.id).update({...map, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteSlot(String slotId) async {
    final snap = await _slots.doc(slotId).get();
    if (snap.data()?['status'] == 'booked') {
      throw ScheduleException('This slot is booked. Cancel the booking first.');
    }
    await _slots.doc(slotId).delete();
  }

  /// A cancelled slot can be offered again (if its time has not passed).
  Future<void> reopenSlot(String slotId) async {
    final snap = await _slots.doc(slotId).get();
    final data = snap.data();
    if (data == null) throw ScheduleException('Slot not found.');
    final start = (data['startAt'] as Timestamp).toDate();
    if (!start.isAfter(DateTime.now())) throw ScheduleException('This slot time has already passed.');
    await _slots.doc(slotId).update({'status': 'available', 'bookingId': '', 'updatedAt': FieldValue.serverTimestamp()});
  }

  // ------------------------------------------------------------------ admin: bookings

  /// Admin cancels a whole slot. A booking on it is cancelled too.
  Future<void> cancelSlot(String slotId) async {
    var lessonId = '';
    await _db.runTransaction((tx) async {
      final slotRef = _slots.doc(slotId);
      final slot = await tx.get(slotRef);
      if (!slot.exists) throw ScheduleException('Slot not found.');
      final bookingId = slot.data()!['bookingId'] as String? ?? '';
      Map<String, dynamic>? booking;
      if (bookingId.isNotEmpty) booking = (await tx.get(_bookings.doc(bookingId))).data();
      tx.update(slotRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
      if (booking != null && booking['status'] != 'cancelled') {
        lessonId = booking['lessonId'] as String? ?? '';
        tx.update(_bookings.doc(bookingId), {
          'status': 'cancelled',
          'cancelReason': 'Slot cancelled by the school',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    await _setLessonStatus(lessonId, 'cancelled');
  }

  /// Admin cancels one booking. [reopen] puts the slot back on the website for other students.
  Future<void> cancelBooking(String bookingId, {required bool reopen}) async {
    var lessonId = '';
    await _db.runTransaction((tx) async {
      final bookingRef = _bookings.doc(bookingId);
      final booking = await tx.get(bookingRef);
      final b = booking.data();
      if (b == null) throw ScheduleException('Booking not found.');
      if (b['status'] == 'cancelled') return;
      final slotRef = _slots.doc(b['slotId'] as String? ?? '-');
      final slot = await tx.get(slotRef);
      lessonId = b['lessonId'] as String? ?? '';
      tx.update(bookingRef, {
        'status': 'cancelled',
        'cancelReason': 'Cancelled by the school',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (slot.exists && slot.data()!['bookingId'] == bookingId) {
        final future = ((slot.data()!['startAt'] as Timestamp).toDate()).isAfter(DateTime.now());
        tx.update(slotRef, {
          'status': reopen && future ? 'available' : 'cancelled',
          'bookingId': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    await _setLessonStatus(lessonId, 'cancelled');
  }

  /// Admin confirms a booking. For a registered student this also creates the lesson,
  /// so it appears in Lessons, Attendance and the instructor's schedule.
  Future<void> confirmBooking(String bookingId) async {
    final bookingRef = _bookings.doc(bookingId);
    final snap = await bookingRef.get();
    final data = snap.data();
    if (data == null) throw ScheduleException('Booking not found.');
    final b = SlotBooking.fromMap(snap.id, data);
    if (b.status != 'pending') return;
    final batch = _db.batch();
    var lessonId = '';
    final vehicleId = (await _slots.doc(b.slotId).get()).data()?['vehicleId'] as String? ?? '';
    if (b.studentId.isNotEmpty) {
      final lessonRef = _db.collection('lessons').doc();
      lessonId = lessonRef.id;
      batch.set(lessonRef, {
        'studentId': b.studentId,
        'studentName': b.name,
        'studentUserId': b.studentUserId,
        'instructorId': b.instructorId,
        'instructorName': b.instructorName,
        'instructorUserId': b.instructorId,
        'vehicleId': vehicleId,
        'vehicleRegistration': b.vehicleName,
        'startAt': Timestamp.fromDate(b.startAt),
        'durationMinutes': b.durationMinutes,
        'notes': 'Booked slot at ${b.location}',
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(bookingRef, {
      'status': 'confirmed',
      'lessonId': lessonId,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> completeSlot(String slotId) async {
    final slot = await _slots.doc(slotId).get();
    final bookingId = slot.data()?['bookingId'] as String? ?? '';
    await _slots.doc(slotId).update({'status': 'completed', 'updatedAt': FieldValue.serverTimestamp()});
    if (bookingId.isNotEmpty) {
      final lessonId = (await _bookings.doc(bookingId).get()).data()?['lessonId'] as String? ?? '';
      await _setLessonStatus(lessonId, 'completed');
    }
  }

  Future<void> _setLessonStatus(String lessonId, String status) async {
    if (lessonId.isEmpty) return;
    try {
      await _db.collection('lessons').doc(lessonId).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // The slot / booking change already succeeded; the lesson can be changed in Lessons.
    }
  }

  // ------------------------------------------------------------------ student / visitor: book

  /// Books an open slot. Done in one transaction, so two people can never get the same slot:
  /// the second one is told it has just been taken.
  Future<String> book({
    required String slotId,
    required String name,
    required String phone,
    String email = '',
    String notes = '',
    String studentUserId = '',
    String studentId = '',
  }) async {
    final slotRef = _slots.doc(slotId);
    final bookingRef = _bookings.doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(slotRef);
      final d = snap.data();
      if (d == null) throw ScheduleException('This slot is no longer available.');
      final start = (d['startAt'] as Timestamp).toDate();
      if (d['status'] != 'available' || !start.isAfter(DateTime.now())) {
        throw ScheduleException('Sorry, this slot has just been taken. Please choose another slot.');
      }
      tx.update(slotRef, {'status': 'booked', 'bookingId': bookingRef.id, 'updatedAt': FieldValue.serverTimestamp()});
      tx.set(bookingRef, {
        'slotId': slotId,
        'studentUserId': studentUserId,
        'studentId': studentId,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'notes': notes.trim(),
        'status': 'pending',
        'startAt': d['startAt'],
        'durationMinutes': d['durationMinutes'],
        'location': d['location'],
        'vehicleName': d['vehicleName'],
        'instructorId': d['instructorId'],
        'instructorName': d['instructorName'],
        'courseName': d['courseName'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return bookingRef.id;
  }
}
