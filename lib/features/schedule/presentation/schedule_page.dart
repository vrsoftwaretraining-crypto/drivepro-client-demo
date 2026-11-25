// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/instructor.dart';
import '../../../core/models/schedule_slot.dart';
import '../../../core/models/vehicle.dart';
import '../../instructors/providers/instructor_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/schedule_repository.dart';
import 'slot_format.dart';

enum _Range { upcoming, past, all }

/// Admin > Schedule. The admin creates every bookable slot here (time, vehicle, instructor, course,
/// duration, location). The website and the student portal show exactly these slots; a student booking
/// turns a slot to "Booked" everywhere at once, and the admin can confirm or cancel from here.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  final _repo = ScheduleRepository();
  _Range _range = _Range.upcoming;
  String _location = '';
  String _status = '';
  bool _weeklyView = true;
  late DateTime _weekStart = _monday(DateTime.now());
  late Stream<List<ScheduleSlot>> _slotsStream = _streamFor(_range);
  final Stream<List<SlotBooking>> _bookingsStream = ScheduleRepository().watchBookings();

  static DateTime _monday(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  Stream<List<ScheduleSlot>> _streamFor(_Range r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (r) {
      case _Range.upcoming:
        return _repo.watchRange(today);
      case _Range.past:
        return _repo.watchRange(today.subtract(const Duration(days: 90)), today);
      case _Range.all:
        return _repo.watchRange(today.subtract(const Duration(days: 365)));
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _say(done);
    } on ScheduleException catch (e) {
      _say(e.message);
    } catch (e) {
      _say('Something went wrong. Please try again. ($e)');
    }
  }

  Future<bool> _confirm(String title, String message, {String yes = 'Yes'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  // ------------------------------------------------------------------ slot actions

  Future<void> _openForm({ScheduleSlot? current, required List<String> locations}) async {
    final instructors = ref.read(instructorsProvider).valueOrNull ?? const <Instructor>[];
    final vehicles = ref.read(vehiclesProvider).valueOrNull ?? const <SchoolVehicle>[];
    if (instructors.where((e) => e.active).isEmpty || vehicles.where((e) => e.active).isEmpty) {
      _say('Add at least one instructor and one vehicle first (Instructors and Vehicles modules).');
      return;
    }
    final slots = await showDialog<List<ScheduleSlot>>(
      context: context,
      builder: (c) => _SlotFormDialog(current: current, instructors: instructors, vehicles: vehicles, locations: locations),
    );
    if (slots == null || slots.isEmpty) return;
    await _run(() async {
      for (final s in slots) {
        final clash = await _repo.findConflict(s, ignoreId: current?.id ?? '');
        if (clash != null) throw ScheduleException(clash);
      }
      if (current == null) {
        await _repo.createSlots(slots);
      } else {
        await _repo.updateSlot(slots.first);
      }
    }, current == null ? '${slots.length} slot(s) added. They are now visible on the website and in the student login.' : 'Slot updated.');
  }

  Future<void> _onSlotAction(String action, ScheduleSlot s, List<String> locations) async {
    switch (action) {
      case 'edit':
        await _openForm(current: s, locations: locations);
      case 'cancel':
        if (await _confirm('Cancel this slot?',
            s.status == 'booked' ? 'The booking on this slot will be cancelled too.' : 'It will no longer be shown for booking.',
            yes: 'Cancel slot')) {
          await _run(() => _repo.cancelSlot(s.id), 'Slot cancelled.');
        }
      case 'reopen':
        await _run(() => _repo.reopenSlot(s.id), 'Slot is available for booking again.');
      case 'delete':
        if (await _confirm('Delete this slot?', 'This cannot be undone.', yes: 'Delete')) {
          await _run(() => _repo.deleteSlot(s.id), 'Slot deleted.');
        }
      case 'complete':
        await _run(() => _repo.completeSlot(s.id), 'Slot marked as completed.');
      case 'booking':
        final b = await _repo.getBooking(s.bookingId);
        if (!mounted) return;
        if (b == null) {
          _say('Booking details were not found.');
        } else {
          await showDialog<void>(context: context, builder: (c) => _BookingDialog(booking: b));
        }
      case 'confirm':
        await _run(() => _repo.confirmBooking(s.bookingId), 'Booking confirmed.');
      case 'release':
        if (await _confirm('Cancel booking and reopen slot?', 'The student booking is cancelled and the slot is shown as available again.', yes: 'Cancel booking')) {
          await _run(() => _repo.cancelBooking(s.bookingId, reopen: true), 'Booking cancelled. The slot is available again.');
        }
    }
  }

  List<PopupMenuEntry<String>> _menu(ScheduleSlot s) {
    PopupMenuItem<String> item(String v, IconData i, String t) => PopupMenuItem<String>(
          value: v,
          child: Row(children: [Icon(i, size: 18), const SizedBox(width: 10), Text(t)]),
        );
    switch (s.status) {
      case 'available':
        return [item('edit', Icons.edit_outlined, 'Edit'), item('cancel', Icons.block, 'Cancel slot'), item('delete', Icons.delete_outline, 'Delete')];
      case 'booked':
        return [
          item('booking', Icons.person_search_outlined, 'View booking'),
          item('confirm', Icons.check_circle_outline, 'Confirm booking'),
          item('release', Icons.event_busy_outlined, 'Cancel booking, reopen slot'),
          item('complete', Icons.done_all, 'Mark completed'),
          item('cancel', Icons.block, 'Cancel slot'),
        ];
      case 'cancelled':
        return [item('reopen', Icons.restore, 'Reopen slot'), item('delete', Icons.delete_outline, 'Delete')];
      default:
        return [item('delete', Icons.delete_outline, 'Delete')];
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    // keep the instructor and vehicle lists loaded for the Add slot form
    ref.watch(instructorsProvider);
    ref.watch(vehiclesProvider);
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Slots'), Tab(text: 'Bookings')]),
        Expanded(child: TabBarView(children: [_slotsTab(), _bookingsTab()])),
      ]),
    );
  }

  Widget _slotsTab() {
    return StreamBuilder<List<ScheduleSlot>>(
      stream: _slotsStream,
      builder: (context, snap) {
        final all = snap.data ?? const <ScheduleSlot>[];
        final locations = {for (final s in all) if (s.location.isNotEmpty) s.location}.toList()..sort();
        final selectedLocation = locations.contains(_location) ? _location : '';
        final shown = all.where((s) => (selectedLocation.isEmpty || s.location == selectedLocation) && (_status.isEmpty || s.status == _status)).toList();
        final byDay = <DateTime, List<ScheduleSlot>>{};
        for (final s in shown) {
          final k = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
          (byDay[k] ??= <ScheduleSlot>[]).add(s);
        }
        final days = byDay.keys.toList()..sort((a, b) => _range == _Range.past ? b.compareTo(a) : a.compareTo(b));
        int count(String st) => all.where((s) => s.status == st).length;

        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Schedule', style: Theme.of(context).textTheme.headlineSmall),
            FilledButton.icon(onPressed: () => _openForm(locations: locations), icon: const Icon(Icons.add), label: const Text('Add slot')),
          ]),
          const SizedBox(height: 6),
          const Text('Create the slots students can book. They show on the website and in the student login, location wise.'),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final r in _Range.values)
              ChoiceChip(
                label: Text(switch (r) { _Range.upcoming => 'Upcoming', _Range.past => 'Past 90 days', _Range.all => 'All (1 year)' }),
                selected: _range == r,
                onSelected: (_) => setState(() {
                  _range = r;
                  _slotsStream = _streamFor(r);
                }),
              ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: selectedLocation,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Location', isDense: true),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All locations')),
                  for (final l in locations) DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _location = v ?? ''),
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'available', child: Text('Available')),
                  DropdownMenuItem(value: 'booked', child: Text('Booked')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                ],
                onChanged: (v) => setState(() => _status = v ?? ''),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _CountChip('Available', count('available'), statusColor('available')),
            _CountChip('Booked', count('booked'), statusColor('booked')),
            _CountChip('Completed', count('completed'), statusColor('completed')),
            _CountChip('Cancelled', count('cancelled'), statusColor('cancelled')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Calendar view', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Weekly'), icon: Icon(Icons.calendar_view_week)),
                ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.view_agenda_outlined)),
              ],
              selected: {_weeklyView},
              onSelectionChanged: (v) => setState(() => _weeklyView = v.first),
            ),
          ]),
          if (_weeklyView) ...[
            const SizedBox(height: 10),
            Row(children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_weekStart.day}/${_weekStart.month}/${_weekStart.year} – ${_weekStart.add(const Duration(days: 6)).day}/${_weekStart.add(const Duration(days: 6)).month}/${_weekStart.add(const Duration(days: 6)).year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () => setState(() => _weekStart = _monday(DateTime.now())),
                child: const Text('Today'),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          if (snap.hasError)
            const Padding(padding: EdgeInsets.all(24), child: Text('Slots could not be loaded. Please check your connection and try again.'))
          else if (!snap.hasData)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (days.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No slots here yet. Tap "Add slot" to create the first one.')))
          else if (_weeklyView)
            _weeklyGrid(shown, locations)
          else
            for (final d in days) ...[
              Padding(padding: const EdgeInsets.only(bottom: 8, top: 6), child: Text(fmtDay(d), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              for (final s in byDay[d]!) _slotTile(s, locations),
            ],
          const SizedBox(height: 40),
        ]);
      },
    );
  }

  List<ScheduleSlot> _slotsForDay(List<ScheduleSlot> slots, DateTime day) {
    final result = slots.where((s) =>
      s.startAt.year == day.year &&
      s.startAt.month == day.month &&
      s.startAt.day == day.day
    ).toList();
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return result;
  }

  Widget _weeklyGrid(List<ScheduleSlot> slots, List<String> locations) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in days)
            SizedBox(
              width: 238,
              child: Card(
                margin: const EdgeInsets.only(right: 10, bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1],
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('${day.day}/${day.month}/${day.year}'),
                      ]),
                    ),
                    ..._slotsForDay(slots, day).map((slot) => Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                        child: InkWell(
                          onTap: slot.status == 'booked' ? () => _onSlotAction('booking', slot, locations) : null,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: statusColor(slot.status).withValues(alpha: .55)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(fmtRange(slot), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(slot.instructorName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(slot.vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              StatusChip(slot.status),
                              if (slot.location.isNotEmpty)
                                Text(slot.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                        ),
                      )),
                    if (_slotsForDay(slots, day).isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No slots', style: TextStyle(color: Colors.grey)),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slotTile(ScheduleSlot s, List<String> locations) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(fmtRange(s), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                StatusChip(s.status),
              ]),
              InfoLine(Icons.place_outlined, s.location),
              InfoLine(Icons.school_outlined, [s.courseName, s.courseDuration].where((e) => e.isNotEmpty).join(' • ')),
              InfoLine(Icons.timer_outlined, 'Lesson: ${fmtDuration(s.durationMinutes)}${s.fee > 0 ? '   •   Fee: ₹${s.fee}' : ''}'),
              InfoLine(Icons.directions_car_outlined, s.vehicleName),
              InfoLine(Icons.person_outline, s.instructorName),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (a) => _onSlotAction(a, s, locations),
            itemBuilder: (c) => _menu(s),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ bookings tab

  Widget _bookingsTab() {
    return StreamBuilder<List<SlotBooking>>(
      stream: _bookingsStream,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Bookings could not be loaded right now.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('No slot bookings yet.'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Slot bookings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          for (final b in list)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    StatusChip(b.status),
                  ]),
                  InfoLine(Icons.phone_outlined, b.phone),
                  InfoLine(Icons.email_outlined, b.email),
                  InfoLine(Icons.event_outlined, '${fmtDay(b.startAt)}  ${fmtTime(b.startAt)} (${fmtDuration(b.durationMinutes)})'),
                  InfoLine(Icons.place_outlined, b.location),
                  InfoLine(Icons.school_outlined, b.courseName),
                  InfoLine(Icons.directions_car_outlined, b.vehicleName),
                  InfoLine(Icons.person_outline, b.instructorName),
                  InfoLine(Icons.sticky_note_2_outlined, b.notes),
                  InfoLine(Icons.badge_outlined, b.studentId.isNotEmpty ? 'Registered student' : (b.studentUserId.isNotEmpty ? 'Student login' : 'Website visitor (not registered)')),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (b.status == 'pending')
                      FilledButton.icon(
                        onPressed: () => _run(() => _repo.confirmBooking(b.id), 'Booking confirmed.'),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm'),
                      ),
                    if (b.status != 'cancelled')
                      OutlinedButton.icon(
                        onPressed: () async {
                          final reopen = await _askReopen();
                          if (reopen == null) return;
                          await _run(() => _repo.cancelBooking(b.id, reopen: reopen), reopen ? 'Booking cancelled. The slot is available again.' : 'Booking cancelled.');
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel booking'),
                      ),
                    OutlinedButton.icon(onPressed: () => _open('tel:${b.phone}'), icon: const Icon(Icons.call_outlined), label: const Text('Call')),
                    OutlinedButton.icon(onPressed: () => _open(_whatsApp(b.phone, b)), icon: const Icon(Icons.chat_outlined), label: const Text('WhatsApp')),
                  ]),
                ]),
              ),
            ),
          const SizedBox(height: 40),
        ]);
      },
    );
  }

  Future<bool?> _askReopen() {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text('Should the slot be offered to other students again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Back')),
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep slot cancelled')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reopen slot')),
        ],
      ),
    );
  }

  String _whatsApp(String phone, SlotBooking b) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '91$digits';
    final text = Uri.encodeComponent('Hello ${b.name}, your driving slot on ${fmtDay(b.startAt)} at ${fmtTime(b.startAt)} (${b.location}) is ${b.status}.');
    return 'https://wa.me/$digits?text=$text';
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) _say('Could not open this on this device.');
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
}

class _BookingDialog extends StatelessWidget {
  const _BookingDialog({required this.booking});

  final SlotBooking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return AlertDialog(
      title: Text(b.name),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusChip(b.status),
        InfoLine(Icons.phone_outlined, b.phone),
        InfoLine(Icons.email_outlined, b.email),
        InfoLine(Icons.event_outlined, '${fmtDay(b.startAt)}  ${fmtTime(b.startAt)}'),
        InfoLine(Icons.place_outlined, b.location),
        InfoLine(Icons.directions_car_outlined, b.vehicleName),
        InfoLine(Icons.person_outline, b.instructorName),
        InfoLine(Icons.sticky_note_2_outlined, b.notes),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

/// Add / edit slot form. When adding, one form can create the same slot for many days.
class _SlotFormDialog extends StatefulWidget {
  const _SlotFormDialog({required this.current, required this.instructors, required this.vehicles, required this.locations});

  final ScheduleSlot? current;
  final List<Instructor> instructors;
  final List<SchoolVehicle> vehicles;
  final List<String> locations;

  @override
  State<_SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<_SlotFormDialog> {
  final _form = GlobalKey<FormState>();
  late DateTime _date;
  late TimeOfDay _time;
  int _duration = 60;
  String? _instructorId;
  String? _vehicleId;
  int _repeat = 0; // 0 only this day, 1 every day, 2 Mon-Sat, 3 Mon-Fri
  final _days = TextEditingController(text: '7');
  late final TextEditingController _location;
  late final TextEditingController _course;
  late final TextEditingController _courseDuration;
  late final TextEditingController _fee;
  String? _dateError;

  bool get _editing => widget.current != null;
  List<Instructor> get _instructors => widget.instructors.where((e) => e.active || e.id == widget.current?.instructorId).toList();
  List<SchoolVehicle> get _vehicles => widget.vehicles.where((e) => e.active || e.id == widget.current?.vehicleId).toList();
  static String _vehicleLabel(SchoolVehicle v) => '${v.registrationNumber} • ${v.makeModel}';

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = c == null ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day) : DateTime(c.startAt.year, c.startAt.month, c.startAt.day);
    _time = c == null ? const TimeOfDay(hour: 7, minute: 0) : TimeOfDay(hour: c.startAt.hour, minute: c.startAt.minute);
    _duration = c?.durationMinutes ?? 60;
    _location = TextEditingController(text: c?.location ?? (widget.locations.isNotEmpty ? widget.locations.first : ''));
    _course = TextEditingController(text: c?.courseName ?? 'Car driving lesson');
    _courseDuration = TextEditingController(text: c?.courseDuration ?? '');
    _fee = TextEditingController(text: (c != null && c.fee > 0) ? '${c.fee}' : '');
    _instructorId = _instructors.any((e) => e.id == c?.instructorId) ? c!.instructorId : (_instructors.isNotEmpty ? _instructors.first.id : null);
    _vehicleId = _vehicles.any((e) => e.id == c?.vehicleId) ? c!.vehicleId : _assignedVehicleFor(_instructorId);
    if (!_durations.contains(_duration)) _duration = 60;
  }

  static const _durations = [15, 30, 45, 60, 90, 120, 180];

  String? _assignedVehicleFor(String? instructorId) {
    final ins = _instructors.where((e) => e.id == instructorId);
    final assigned = ins.isEmpty ? '' : ins.first.assignedVehicleId;
    if (_vehicles.any((v) => v.id == assigned)) return assigned;
    return _vehicles.isNotEmpty ? _vehicles.first.id : null;
  }

  @override
  void dispose() {
    _days.dispose();
    _location.dispose();
    _course.dispose();
    _courseDuration.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: _date.isBefore(today) ? _date : today, lastDate: now.add(const Duration(days: 730)));
    if (d != null) setState(() { _date = d; _dateError = null; });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() { _time = t; _dateError = null; });
  }

  List<ScheduleSlot> _build() {
    final ins = _instructors.firstWhere((e) => e.id == _instructorId);
    final veh = _vehicles.firstWhere((e) => e.id == _vehicleId);
    final fee = num.tryParse(_fee.text.trim()) ?? 0;
    ScheduleSlot at(DateTime t) => ScheduleSlot(
          id: widget.current?.id ?? '',
          startAt: t,
          durationMinutes: _duration,
          location: _location.text.trim(),
          vehicleId: veh.id,
          vehicleName: _vehicleLabel(veh),
          instructorId: ins.id,
          instructorName: ins.name,
          courseName: _course.text.trim(),
          courseDuration: _courseDuration.text.trim(),
          fee: fee,
        );
    final base = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (_editing || _repeat == 0) return [at(base)];
    final count = (int.tryParse(_days.text.trim()) ?? 1).clamp(1, 60);
    final out = <ScheduleSlot>[];
    for (var i = 0; i < count; i++) {
      final d = base.add(Duration(days: i));
      if (_repeat == 2 && d.weekday == DateTime.sunday) continue;
      if (_repeat == 3 && d.weekday >= DateTime.saturday) continue;
      out.add(at(d));
    }
    return out;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (!_editing && !start.isAfter(DateTime.now())) {
      setState(() => _dateError = 'Choose a date and time in the future.');
      return;
    }
    final slots = _build();
    if (slots.isEmpty) {
      setState(() => _dateError = 'No dates match this repeat option.');
      return;
    }
    Navigator.pop(context, slots);
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(_editing ? 'Edit slot' : 'Add slot'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 18), label: Text(loc.formatMediumDate(_date)))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.access_time, size: 18), label: Text(_time.format(context)))),
              ]),
              if (_dateError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_dateError!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'Lesson duration'),
                items: [for (final d in _durations) DropdownMenuItem(value: d, child: Text(fmtDuration(d)))],
                onChanged: (v) => setState(() => _duration = v ?? 60),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _instructorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Instructor'),
                items: [for (final i in _instructors) DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis))],
                validator: (v) => v == null ? 'Choose an instructor.' : null,
                onChanged: (v) => setState(() {
                  _instructorId = v;
                  _vehicleId = _assignedVehicleFor(v);
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [for (final v in _vehicles) DropdownMenuItem(value: v.id, child: Text(_vehicleLabel(v), overflow: TextOverflow.ellipsis))],
                validator: (v) => v == null ? 'Choose a vehicle.' : null,
                onChanged: (v) => setState(() => _vehicleId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location (area / branch)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the location.' : null,
              ),
              if (widget.locations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 6, runSpacing: 0, children: [
                    for (final l in widget.locations) ActionChip(label: Text(l), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _location.text = l)),
                  ]),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _course,
                decoration: const InputDecoration(labelText: 'Course name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the course name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _courseDuration, decoration: const InputDecoration(labelText: 'Course duration (example: 30 days)')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fee in ₹ (optional)'),
                validator: (v) => (v == null || v.trim().isEmpty || num.tryParse(v.trim()) != null) ? null : 'Enter a number.',
              ),
              if (!_editing) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _repeat,
                  decoration: const InputDecoration(labelText: 'Repeat'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Only this day')),
                    DropdownMenuItem(value: 1, child: Text('Every day')),
                    DropdownMenuItem(value: 2, child: Text('Monday to Saturday')),
                    DropdownMenuItem(value: 3, child: Text('Monday to Friday')),
                  ],
                  onChanged: (v) => setState(() => _repeat = v ?? 0),
                ),
                if (_repeat != 0) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'For how many days (1 to 60)'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 1 || n > 60 ? 'Enter 1 to 60.' : null;
                    },
                  ),
                ],
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(_editing ? 'Save changes' : 'Add slot(s)')),
      ],
    );
  }
}
