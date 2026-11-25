// Developed by @Ramana Code Softwares

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/school_service.dart';
import '../../../core/logging/app_logger.dart';
import '../data/public_catalog.dart';

/// Public slot board: no login needed. Shows school info, instructors,
/// vehicles and the day's slot grid. Visitors can call, enquire or book.
class PublicBookingPage extends StatefulWidget {
  const PublicBookingPage({super.key});

  @override
  State<PublicBookingPage> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends State<PublicBookingPage> {
  StreamSubscription<List<Map<String, dynamic>>>? _live;
  PublicCatalog? _catalog;
  String? _error;
  late DateTime _date;
  String? _instructorId; // null = "Any instructor"

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final catalog = await PublicCatalog.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        if (catalog.instructors.length == 1) {
          _instructorId = catalog.instructors.first['id'] as String;
        }
      });
      // Live updates: a slot booked by admin shows as BOOKED immediately.
      _live?.cancel();
      _live = SchoolService.watchOccupied().listen((occupied) {
        if (!mounted || _catalog == null) return;
        setState(() => _catalog!.occupied = occupied);
      });
    } catch (e, stack) {
      AppLogger.error('Failed to load public booking catalogue', tag: 'Booking', error: e, stackTrace: stack);
      if (mounted) setState(() => _error = 'Unable to load slots. Check your connection and retry.');
    }
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) {
      _snack('The school phone number has not been set yet.');
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic>? get _instructor {
    final c = _catalog;
    if (c == null) return null;
    for (final i in c.instructors) {
      if (i['id'] == _instructorId) return i;
    }
    return null;
  }

  Future<void> _enquire({Map<String, dynamic>? instructor, SlotWindow? slot}) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final message = TextEditingController();
    final key = GlobalKey<FormState>();
    final slotLabel = slot == null
        ? ''
        : '${_dateText(_date)} ${slot.label}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(instructor == null
            ? 'Enquiry'
            : 'Enquire about ${instructor['name']}'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (slotLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('Slot: $slotLabel'),
                  ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                  validator: (v) =>
                      (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                          ? 'Enter a valid mobile number'
                          : null,
                ),
                TextFormField(
                  controller: message,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Message (optional)'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Request call back'),
          ),
        ],
      ),
    );
    final payload = {
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'message': message.text.trim(),
      'instructorId': instructor?['id'] ?? '',
      'instructorName': instructor?['name'] ?? '',
      'slotLabel': slotLabel,
    };
    name.dispose();
    phone.dispose();
    message.dispose();
    if (ok != true) return;
    try {
      await SchoolService.submitEnquiry(
        name: payload['name'] as String,
        phone: payload['phone'] as String,
        message: payload['message'] as String,
        instructorId: payload['instructorId'] as String,
        instructorName: payload['instructorName'] as String,
        slotLabel: payload['slotLabel'] as String,
      );
      _snack('Thank you! The school will call you back soon.');
    } catch (error, stack) {
      AppLogger.error('Failed to submit public enquiry', tag: 'Booking', error: error, stackTrace: stack);
      _snack('Could not send your enquiry.');
    }
  }

  Future<void> _book(Map<String, dynamic>? picked, SlotWindow slot) async {
    final catalog = _catalog!;
    final any = picked == null;
    Map<String, dynamic>? instructor = picked;
    if (any) {
      // Balance the load: free instructor with the fewest lessons that day.
      final free = catalog.freeInstructors(slot)
        ..sort((a, b) => catalog.loadOn(a, _date).compareTo(catalog.loadOn(b, _date)));
      if (free.isEmpty) {
        _snack('No instructor is free for this slot.');
        return;
      }
      instructor = free.first;
    }
    final chosen = instructor!;
    final vehicle = catalog.vehicleOf(chosen) ??
        (catalog.vehicles.isNotEmpty ? catalog.vehicles.first : null);
    if (vehicle == null) {
      _snack('No vehicle is available for this instructor yet.');
      return;
    }
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final pickupAddress = TextEditingController();
    final course = TextEditingController(text: 'Test drive (trial lesson)');
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Book this slot'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${_dateText(_date)} • ${slot.label}'),
                  subtitle: Text(
                      '${any ? 'Any available instructor (assigned: ${chosen['name']})' : chosen['name']} • ${vehicle['makeModel'] ?? ''} ${vehicle['registrationNumber'] ?? ''}\n${catalog.location}'),
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                  validator: (v) =>
                      (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                          ? 'Enter a valid mobile number'
                          : null,
                ),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch((v ?? '').trim())
                      ? null
                      : 'Enter a valid email',
                ),
                TextFormField(
                  controller: pickupAddress,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Pickup address',
                    hintText: 'House / street, area, city, postcode',
                    prefixIcon: Icon(Icons.home_outlined),
                    helperText: 'Where should the instructor pick you up?',
                  ),
                  validator: (v) => (v ?? '').trim().length < 5
                      ? 'Enter a complete pickup address'
                      : (v ?? '').trim().length > 300
                          ? 'Address must be 300 characters or fewer'
                          : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: course.text,
                  decoration: const InputDecoration(labelText: 'Booking type'),
                  items: const [
                    DropdownMenuItem(value: 'Test drive (trial lesson)', child: Text('Test drive (trial lesson)')),
                    DropdownMenuItem(value: 'Driving course', child: Text('Driving course')),
                    DropdownMenuItem(value: 'Licence test preparation', child: Text('Licence test preparation')),
                  ],
                  onChanged: (v) => course.text = v ?? course.text,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The slot is held for 15 minutes. The school will contact you to confirm the fee. After payment is confirmed you will receive your login.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Request booking'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final ph = phone.text.trim();
    final em = email.text.trim();
    final pickup = pickupAddress.text.trim();
    final co = course.text;
    name.dispose();
    phone.dispose();
    email.dispose();
    pickupAddress.dispose();
    course.dispose();
    if (ok != true) return;
    try {
      await SchoolService.submitBooking(
        name: n,
        phone: ph,
        email: em,
        pickupAddress: pickup,
        course: co,
        instructorId: chosen['id'] as String,
        instructorName: chosen['name'] as String? ?? '',
        vehicleId: vehicle['id'] as String,
        vehicleRegistration: vehicle['registrationNumber'] as String? ?? '',
        startUtc: slot.startUtc,
        minutes: slot.minutes,
        anyInstructor: any,
      );
      _snack('Slot held for 15 minutes. The school will contact you to confirm payment.');
    } on SchoolException catch (e) {
      _snack(e.message);
    } catch (error, stack) {
      AppLogger.error('Failed to submit public booking', tag: 'Booking', error: error, stackTrace: stack);
      _snack('Could not book this slot.');
    }
    await _load();
  }

  static String _dateText(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${w[d.weekday - 1]}, ${d.day} ${m[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    return Scaffold(
      appBar: AppBar(title: const Text('Book a driving slot')),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ]),
            )
          : catalog == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _header(catalog),
                        const SizedBox(height: 16),
                        _dateStrip(),
                        const SizedBox(height: 16),
                        _instructorSection(catalog),
                        const SizedBox(height: 16),
                        _slotGrid(catalog),
                        const SizedBox(height: 24),
                        _vehicleSection(catalog),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _header(PublicCatalog c) {
    final s = c.summaryFor(_date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.schoolName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (c.location.isNotEmpty || c.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text([c.location, c.address].where((e) => e.isNotEmpty).join(' • '))),
              ]),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _chip(Icons.view_timeline_outlined, '${c.slotsPerDay} slots / day per instructor'),
            _chip(Icons.event_seat_outlined, '${s.total} total slots on ${_dateText(_date)}'),
            _chip(Icons.check_circle_outline, '${s.free} available'),
            _chip(Icons.badge_outlined, '${c.instructors.length} instructors'),
            _chip(Icons.directions_car_outlined, '${c.vehicles.length} vehicles'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _call(c.phone),
              icon: const Icon(Icons.call),
              label: Text(c.phone.isEmpty ? 'Call school' : 'Call ${c.phone}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _enquire(),
              icon: const Icon(Icons.support_agent),
              label: const Text('General enquiry'),
            ),
            if (c.mapUrl.startsWith('https://'))
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(c.mapUrl)),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open map'),
              ),
          ]),
          if (c.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(c.notes)),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(text));

  Widget _dateStrip() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final selected = d == _date;
          return ChoiceChip(
            label: Text(_dateText(d)),
            selected: selected,
            onSelected: (_) => setState(() => _date = d),
          );
        },
      ),
    );
  }

  Widget _instructorSection(PublicCatalog c) {
    if (c.instructors.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Instructors will be listed soon.')));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Instructors', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ChoiceChip(
          avatar: const Icon(Icons.groups_2_outlined, size: 18),
          label: const Text('Any instructor (fastest slot)'),
          selected: _instructorId == null,
          onSelected: (_) => setState(() => _instructorId = null),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final i in c.instructors) _instructorCard(c, i),
      ]),
    ]);
  }

  Widget _instructorCard(PublicCatalog c, Map<String, dynamic> i) {
    final vehicle = c.vehicleOf(i);
    final selected = i['id'] == _instructorId;
    final photo = i['photoUrl'] as String? ?? '';
    return SizedBox(
      width: 310,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: photo.startsWith('https://') ? NetworkImage(photo) : null,
                child: photo.startsWith('https://') ? null : const Icon(Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(i['name'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Experience: ${i['experienceYears'] ?? 0} years'),
            Text('Students trained: ${i['studentsTrained'] ?? 0}'),
            if ((i['achievements'] as String? ?? '').isNotEmpty) Text('Achievements: ${i['achievements']}'),
            if ((i['bio'] as String? ?? '').isNotEmpty) Text(i['bio'] as String),
            if (vehicle != null) Text('Vehicle: ${vehicle['makeModel'] ?? ''} (${vehicle['registrationNumber'] ?? ''})'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.tonal(
                onPressed: () => setState(() => _instructorId = i['id'] as String),
                child: Text(selected ? 'Selected' : 'Choose'),
              ),
              OutlinedButton(
                onPressed: () => _call(c.phone),
                child: const Text('Call'),
              ),
              OutlinedButton(
                onPressed: () => _enquire(instructor: i),
                child: const Text('Enquire'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _slotGrid(PublicCatalog c) {
    final instructor = _instructor;
    final slots = c.slotsFor(_date);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Slots for ${instructor?['name'] ?? 'any instructor'} • ${_dateText(_date)}',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final slot in slots) _slotTile(c, instructor, slot),
      ]),
    ]);
  }

  Widget _slotTile(PublicCatalog c, Map<String, dynamic>? instructor, SlotWindow slot) {
    final freeCount = instructor == null ? c.freeInstructors(slot).length : 0;
    final state = instructor == null
        ? (freeCount > 0
            ? SlotState.available
            : (!slot.startUtc.isAfter(DateTime.now().toUtc())
                ? SlotState.past
                : SlotState.booked))
        : c.stateOf(instructor, slot);
    final (text, color) = switch (state) {
      SlotState.available => (
          instructor == null ? 'Available ($freeCount instructors free)' : 'Available',
          Colors.green
        ),
      SlotState.booked => ('Booked', Colors.red),
      SlotState.past => ('Closed', Colors.grey),
      SlotState.notWorking => ('Not working', Colors.grey),
    };
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            if (c.location.isNotEmpty)
              Text(c.location, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (state == SlotState.available)
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _book(instructor, slot),
                    child: const Text('Book'),
                  ),
                ),
                IconButton(
                  tooltip: 'Enquire about this slot',
                  onPressed: () => _enquire(instructor: instructor, slot: slot),
                  icon: const Icon(Icons.support_agent),
                ),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _vehicleSection(PublicCatalog c) {
    if (c.vehicles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Vehicles', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final v in c.vehicles)
          SizedBox(
            width: 310,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v['makeModel'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Reg. no: ${v['registrationNumber'] ?? ''}'),
                  Text('${v['transmission'] ?? ''} • ${v['fuelType'] ?? ''}'),
                  Text('Instructor: ${c.instructorOfVehicle(v)?['name'] ?? 'Not assigned'}'),
                ]),
              ),
            ),
          ),
      ]),
    ]);
  }
}
