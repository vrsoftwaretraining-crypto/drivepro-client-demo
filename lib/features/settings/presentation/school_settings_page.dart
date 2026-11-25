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
  final _email = TextEditingController();
  final _address = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsRef = ref
        .watch(firestoreProvider)
        .collection('school_settings')
        .doc('general');
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load settings: ${snapshot.error}'),);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          if (!_loaded) {
            _name.text = data['schoolName'] as String? ?? '';
            _phone.text = data['phone'] as String? ?? '';
            _email.text = data['email'] as String? ?? '';
            _address.text = data['address'] as String? ?? '';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('School profile & settings',
                  style: Theme.of(context).textTheme.headlineSmall,),
              const SizedBox(height: 8),
              const Text(
                  'These details can be used on receipts and certificates in a future enhancement.',),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Driving school name',),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter school name'
                            : null,),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _phone,
                        decoration:
                            const InputDecoration(labelText: 'Contact phone'),
                        keyboardType: TextInputType.phone,),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _email,
                        decoration:
                            const InputDecoration(labelText: 'Contact email'),
                        keyboardType: TextInputType.emailAddress,),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _address,
                        decoration:
                            const InputDecoration(labelText: 'School address'),
                        maxLines: 3,),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),)
                            : const Icon(Icons.save),
                        label: const Text('Save school profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('school_settings')
          .doc('general')
          .set({
        'schoolName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School profile saved.')),);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
