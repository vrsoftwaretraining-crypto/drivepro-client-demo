// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';

class SchoolSettingsPage extends ConsumerStatefulWidget {
  const SchoolSettingsPage({super.key});

  @override
  ConsumerState<SchoolSettingsPage> createState() => _SchoolSettingsPageState();
}

class _SchoolSettingsPageState extends ConsumerState<SchoolSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _alternatePhone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _mapUrl = TextEditingController();
  final _facebookUrl = TextEditingController();
  final _instagramUrl = TextEditingController();
  final _websiteUrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  List<TextEditingController> get _controllers => [
        _name, _phone, _alternatePhone, _email, _address, _location,
        _mapUrl, _facebookUrl, _instagramUrl, _websiteUrl,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final settingsRef = db.collection('school_settings').doc('general');
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load settings: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          if (!_loaded) {
            _name.text = data['schoolName'] as String? ?? '';
            _phone.text = data['phone'] as String? ?? '';
            _alternatePhone.text = data['alternatePhone'] as String? ?? '';
            _email.text = data['email'] as String? ?? '';
            _address.text = data['address'] as String? ?? '';
            _location.text = data['location'] as String? ?? '';
            _mapUrl.text = data['mapUrl'] as String? ?? '';
            _facebookUrl.text = data['facebookUrl'] as String? ?? '';
            _instagramUrl.text = data['instagramUrl'] as String? ?? '';
            _websiteUrl.text = data['websiteUrl'] as String? ?? '';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('School profile & contact details', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text('These details appear on the public DrivePro website Contact Us section.'),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _section('School information', Icons.school_outlined),
                  _field(_name, 'Driving school name', required: true),
                  _field(_address, 'Full school address', maxLines: 3),
                  _field(_location, 'Area / city / landmark'),
                  const SizedBox(height: 18),
                  _section('Contact information', Icons.call_outlined),
                  _field(_phone, 'Primary contact number', keyboard: TextInputType.phone),
                  _field(_alternatePhone, 'Alternate contact number', keyboard: TextInputType.phone),
                  _field(_email, 'Contact email', keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 18),
                  _section('Map and social media', Icons.public),
                  _field(_mapUrl, 'Google Maps / Directions URL', keyboard: TextInputType.url),
                  _field(_facebookUrl, 'Facebook page URL', keyboard: TextInputType.url),
                  _field(_instagramUrl, 'Instagram profile URL', keyboard: TextInputType.url),
                  _field(_websiteUrl, 'Website URL (optional)', keyboard: TextInputType.url),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save and publish contact details'),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 9), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
      );

  Widget _field(TextEditingController controller, String label, {bool required = false, int maxLines = 1, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.edit_outlined)),
          validator: required ? (value) => value == null || value.trim().isEmpty ? 'Enter $label' : null : null,
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(firestoreProvider);
    final payload = <String, dynamic>{
      'schoolName': _name.text.trim(),
      'phone': _phone.text.trim(),
      'alternatePhone': _alternatePhone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
      'location': _location.text.trim(),
      'mapUrl': _mapUrl.text.trim(),
      'facebookUrl': _facebookUrl.text.trim(),
      'instagramUrl': _instagramUrl.text.trim(),
      'websiteUrl': _websiteUrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final batch = db.batch();
      batch.set(db.collection('school_settings').doc('general'), payload, SetOptions(merge: true));
      // Public mirror contains only school contact details, never admin credentials.
      batch.set(db.collection('public_info').doc('school'), {
        'name': payload['schoolName'],
        'phone': payload['phone'],
        'alternatePhone': payload['alternatePhone'],
        'email': payload['email'],
        'address': payload['address'],
        'location': payload['location'],
        'mapUrl': payload['mapUrl'],
        'facebookUrl': payload['facebookUrl'],
        'instagramUrl': payload['instagramUrl'],
        'websiteUrl': payload['websiteUrl'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('School contact details published to the website.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
