// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/services/school_service.dart';

/// Admin: daily timings, slot length and training location shown to visitors.
class SlotSettingsPage extends ConsumerStatefulWidget {
  const SlotSettingsPage({super.key});

  @override
  ConsumerState<SlotSettingsPage> createState() => _SlotSettingsPageState();
}

class _SlotSettingsPageState extends ConsumerState<SlotSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _open = TextEditingController(text: '06:00');
  final _close = TextEditingController(text: '20:00');
  final _schoolName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _mapUrl = TextEditingController();
  final _notes = TextEditingController();
  int _slotMinutes = 120;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _open.dispose();
    _close.dispose();
    _schoolName.dispose();
    _phone.dispose();
    _address.dispose();
    _location.dispose();
    _mapUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  static int? _minutes(String v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return h * 60 + mi;
  }

  List<String> _preview() {
    final a = _minutes(_open.text);
    final b = _minutes(_close.text);
    if (a == null || b == null) return [];
    String f(int x) =>
        '${(x ~/ 60).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
    return [
      for (var s = a; s + _slotMinutes <= b; s += _slotMinutes)
        '${f(s)} – ${f(s + _slotMinutes)}',
    ];
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> ref) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.set({
        'schoolName': _schoolName.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'openTime': _open.text.trim(),
        'closeTime': _close.text.trim(),
        'slotMinutes': _slotMinutes,
        'location': _location.text.trim(),
        'mapUrl': _mapUrl.text.trim(),
        'notes': _notes.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Slot settings saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _docRef();
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_loaded) {
            final d = snapshot.data!.data() ?? {};
            _open.text = d['openTime'] as String? ?? '06:00';
            _close.text = d['closeTime'] as String? ?? '20:00';
            _schoolName.text = d['schoolName'] as String? ?? '';
            _phone.text = d['phone'] as String? ?? '';
            _address.text = d['address'] as String? ?? '';
            _location.text = d['location'] as String? ?? '';
            _mapUrl.text = d['mapUrl'] as String? ?? '';
            _notes.text = d['notes'] as String? ?? '';
            _slotMinutes = (d['slotMinutes'] as num?)?.toInt() ?? 120;
            _loaded = true;
          }
          final preview = _preview();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Slot settings', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text('Saved to the public school info document. Shown on the website slot board.'),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _schoolName,
                    decoration: const InputDecoration(labelText: 'School name (public)'),
                  ),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'School phone (Call button)'),
                  ),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: _open,
                    decoration: const InputDecoration(labelText: 'Opening time (HH:MM, 24h)'),
                    validator: (v) => _minutes(v ?? '') == null ? 'Use HH:MM e.g. 06:00' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  TextFormField(
                    controller: _close,
                    decoration: const InputDecoration(labelText: 'Closing time (HH:MM, 24h)'),
                    validator: (v) => _minutes(v ?? '') == null ? 'Use HH:MM e.g. 20:00' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _slotMinutes,
                    decoration: const InputDecoration(labelText: 'Slot length'),
                    items: const [
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                      DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                      DropdownMenuItem(value: 120, child: Text('2 hours')),
                    ],
                    onChanged: (v) => setState(() => _slotMinutes = v ?? 120),
                  ),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Training location / pickup point'),
                  ),
                  TextFormField(
                    controller: _mapUrl,
                    decoration: const InputDecoration(labelText: 'Map link (https://…)'),
                    validator: (v) => (v ?? '').isEmpty || (v ?? '').startsWith('https://')
                        ? null
                        : 'Must start with https://',
                  ),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes for students (optional)'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('${preview.length} slots per day per instructor',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in preview) Chip(label: Text(p)),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Publish existing instructors & vehicles'),
                  onPressed: () async {
                    try {
                      final n = await SchoolService.syncPublicCatalog();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$n records published to the website.')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Could not publish: $e')));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(docRef),
                  child: Text(_saving ? 'Saving...' : 'Save slot settings'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _docRef() => ref
      .watch(firestoreProvider)
      .collection('public_info')
      .doc('school');
}
