// Developed by @Ramana Code Softwares

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/models/schedule_slot.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/backend.dart';
import '../data/schedule_repository.dart';
import 'slot_format.dart';

/// Details of a signed-in student, so booking needs only one tap.
class SlotBooker {
  const SlotBooker({required this.userId, required this.studentId, required this.name, required this.phone, required this.email});

  final String userId;
  final String studentId;
  final String name;
  final String phone;
  final String email;
}

class _BookingInput {
  const _BookingInput(this.name, this.phone, this.email, this.notes);

  final String name;
  final String phone;
  final String email;
  final String notes;
}

/// Live list of the slots the admin created, grouped by day and filtered by location.
/// Used on the public website (no login) and inside the student portal (booker set).
/// Booked slots stay visible but greyed out; cancelled slots are hidden.
class SlotBoard extends StatefulWidget {
  const SlotBoard({this.booker, super.key});

  final SlotBooker? booker;

  @override
  State<SlotBoard> createState() => _SlotBoardState();
}

class _SlotBoardState extends State<SlotBoard> {
  final _repo = ScheduleRepository();
  late final Stream<List<ScheduleSlot>> _stream = _repo.watchUpcoming();
  String _location = '';

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _book(ScheduleSlot slot) async {
    final booker = widget.booker;
    _BookingInput? input;
    if (booker != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm your booking'),
          content: SingleChildScrollView(child: SlotSummary(slot)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm booking')),
          ],
        ),
      );
      if (ok != true) return;
      input = _BookingInput(booker.name, booker.phone, booker.email, '');
    } else {
      input = await showDialog<_BookingInput>(context: context, builder: (c) => _VisitorBookDialog(slot: slot));
    }
    if (input == null || !mounted) return;
    try {
      await _repo.book(
        slotId: slot.id,
        name: input.name,
        phone: input.phone,
        email: input.email,
        notes: input.notes,
        studentUserId: booker?.userId ?? '',
        studentId: booker?.studentId ?? '',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF1B8A5A), size: 44),
          title: const Text('Slot booked'),
          content: Text('Your slot on ${fmtDay(slot.startAt)}, ${fmtRange(slot)} at ${slot.location} is reserved. '
              'The school will confirm it shortly.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } on ScheduleException catch (e) {
      if (mounted) _say(e.message);
    } on FirebaseException {
      if (mounted) _say('Could not book this slot. Please refresh and try again.');
    } catch (_) {
      if (mounted) _say('Could not book this slot. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleSlot>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return const _Note('Slots could not be loaded right now. Please try again in a moment.');
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
        final all = snap.data!.where((s) => s.status == 'available' || s.status == 'booked').toList();
        if (all.isEmpty) return const _Note('No driving slots are scheduled yet. Please check back soon.');

        final openByLocation = <String, int>{};
        for (final s in all) {
          if (s.location.isEmpty) continue;
          openByLocation.update(s.location, (v) => s.isOpen ? v + 1 : v, ifAbsent: () => s.isOpen ? 1 : 0);
        }
        final names = openByLocation.keys.toList()..sort();
        final selected = names.contains(_location) ? _location : '';
        final shown = selected.isEmpty ? all : all.where((s) => s.location == selected).toList();
        final openTotal = all.where((s) => s.isOpen).length;

        final byDay = <DateTime, List<ScheduleSlot>>{};
        for (final s in shown) {
          final k = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
          (byDay[k] ??= <ScheduleSlot>[]).add(s);
        }
        final days = byDay.keys.toList()..sort();
        final cardWidth = math.min(350.0, MediaQuery.sizeOf(context).width - 64);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text('All locations ($openTotal available)'),
                selected: selected.isEmpty,
                onSelected: (_) => setState(() => _location = ''),
              ),
              for (final n in names)
                ChoiceChip(
                  label: Text('$n (${openByLocation[n]} available)'),
                  selected: selected == n,
                  onSelected: (_) => setState(() => _location = n),
                ),
            ]),
            const SizedBox(height: 16),
            for (final d in days) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(fmtDay(d), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final s in byDay[d]!) SizedBox(width: cardWidth, child: _SlotCard(slot: s, onBook: () => _book(s))),
              ]),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onBook});

  final ScheduleSlot slot;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final open = slot.isOpen;
    return Opacity(
      opacity: open ? 1 : .6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(fmtRange(slot), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              StatusChip(open ? 'available' : 'booked'),
            ]),
            InfoLine(Icons.place_outlined, slot.location),
            InfoLine(Icons.school_outlined, [slot.courseName, slot.courseDuration].where((e) => e.isNotEmpty).join(' • ')),
            InfoLine(Icons.timer_outlined, 'Lesson: ${fmtDuration(slot.durationMinutes)}'),
            InfoLine(Icons.directions_car_outlined, slot.vehicleName),
            InfoLine(Icons.person_outline, slot.instructorName),
            if (slot.fee > 0) InfoLine(Icons.currency_rupee, 'Fee: ₹${slot.fee}'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: open ? onBook : null,
                child: Text(open ? 'Book this slot' : 'Booked'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The slot's full details, used inside confirmation dialogs.
class SlotSummary extends StatelessWidget {
  const SlotSummary(this.slot, {super.key});

  final ScheduleSlot slot;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('${fmtDay(slot.startAt)}  ${fmtRange(slot)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      InfoLine(Icons.place_outlined, slot.location),
      InfoLine(Icons.school_outlined, [slot.courseName, slot.courseDuration].where((e) => e.isNotEmpty).join(' • ')),
      InfoLine(Icons.directions_car_outlined, slot.vehicleName),
      InfoLine(Icons.person_outline, slot.instructorName),
      if (slot.fee > 0) InfoLine(Icons.currency_rupee, 'Fee: ₹${slot.fee}'),
    ]);
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
      );
}

/// Name / phone form for a visitor who is not signed in.
class _VisitorBookDialog extends StatefulWidget {
  const _VisitorBookDialog({required this.slot});

  final ScheduleSlot slot;

  @override
  State<_VisitorBookDialog> createState() => _VisitorBookDialogState();
}

class _VisitorBookDialogState extends State<_VisitorBookDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Book this slot'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SlotSummary(widget.slot),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: (v) => RegExp(r'^\+?[0-9 \-]{10,15}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid mobile number.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email or leave it empty.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Message (optional)'),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, _BookingInput(_name.text, _phone.text, _email.text, _notes.text));
          },
          child: const Text('Book slot'),
        ),
      ],
    );
  }
}

/// Finds the signed-in student's record, then shows the slot board with one-tap booking.
class StudentSlotsCard extends StatefulWidget {
  const StudentSlotsCard({required this.user, super.key});

  final AppUser user;

  @override
  State<StudentSlotsCard> createState() => _StudentSlotsCardState();
}

class _StudentSlotsCardState extends State<StudentSlotsCard> {
  late final Future<SlotBooker> _booker = _load();

  Future<SlotBooker> _load() async {
    var studentId = '';
    var phone = '';
    try {
      final snap = await Backend.firestore.collection('students').where('userId', isEqualTo: widget.user.uid).limit(1).get();
      if (snap.docs.isNotEmpty) {
        studentId = snap.docs.first.id;
        phone = snap.docs.first.data()['phone'] as String? ?? '';
      }
    } catch (_) {
      // booking still works; the lesson is linked later by the school
    }
    return SlotBooker(userId: widget.user.uid, studentId: studentId, name: widget.user.name, phone: phone, email: widget.user.email);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available driving slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Choose a location and book a slot. The school confirms it, and it then appears in My booked lessons.'),
          const SizedBox(height: 14),
          FutureBuilder<SlotBooker>(
            future: _booker,
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              return SlotBoard(booker: snap.data);
            },
          ),
        ]),
      ),
    );
  }
}

/// The student's own slot bookings with their status.
class MySlotBookingsCard extends StatelessWidget {
  const MySlotBookingsCard({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My slot bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          StreamBuilder<List<SlotBooking>>(
            stream: ScheduleRepository().watchMyBookings(uid),
            builder: (context, snap) {
              if (snap.hasError) return const Text('Unable to load your bookings right now.');
              if (!snap.hasData) return const LinearProgressIndicator();
              if (snap.data!.isEmpty) return const Text('You have not booked any slot yet.');
              return Column(children: [
                for (final b in snap.data!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text('${fmtDay(b.startAt)}  ${fmtTime(b.startAt)}'),
                    subtitle: Text([b.location, b.instructorName, b.vehicleName].where((e) => e.isNotEmpty).join(' • ')),
                    trailing: StatusChip(b.status),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// Instructor portal: the slots the admin assigned to this instructor.
class InstructorSlotsCard extends StatelessWidget {
  const InstructorSlotsCard({required this.instructorId, super.key});

  final String instructorId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My scheduled slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          StreamBuilder<List<ScheduleSlot>>(
            stream: ScheduleRepository().watchForInstructor(instructorId),
            builder: (context, snap) {
              if (snap.hasError) return const Text('Unable to load your slots right now.');
              if (!snap.hasData) return const LinearProgressIndicator();
              final now = DateTime.now().subtract(const Duration(hours: 3));
              final list = snap.data!.where((s) => s.status != 'cancelled' && s.startAt.isAfter(now)).toList();
              if (list.isEmpty) return const Text('No upcoming slots have been scheduled for you.');
              return Column(children: [
                for (final s in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text('${fmtDay(s.startAt)}  ${fmtRange(s)}'),
                    subtitle: Text([s.location, s.vehicleName, s.courseName].where((e) => e.isNotEmpty).join(' • ')),
                    trailing: StatusChip(s.status),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
