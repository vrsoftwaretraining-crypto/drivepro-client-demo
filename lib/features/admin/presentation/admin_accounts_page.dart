// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/school_service.dart';

/// Admin: see every login account and create additional administrators.
class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key});

  Future<void> _createAdmin(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create admin account'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (login)'),
                validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter a valid email',
              ),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => (v ?? '').trim().length < 10 ? 'Enter a phone number' : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final m = email.text.trim();
    final ph = phone.text.trim();
    name.dispose();
    email.dispose();
    phone.dispose();
    if (ok != true || !context.mounted) return;
    try {
      final acc = await SchoolService.createAccount(
          role: 'admin', name: n, email: m, phone: ph);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Admin account created'),
          content: SelectableText(
              'Login: ${acc.email}\nTemporary password: ${acc.temporaryPassword}\n\nShare this securely. The new admin must set a new password and security questions at first login.'),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(
                  text: 'Login: ${acc.email}\nPassword: ${acc.temporaryPassword}')),
              child: const Text('Copy'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAdmin(context),
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('New admin'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('name').limit(500).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load accounts: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              Text('Login accounts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final doc in docs)
                Card(
                  child: ListTile(
                    leading: Icon(switch (doc.data()['role']) {
                      'admin' => Icons.admin_panel_settings,
                      'instructor' => Icons.badge,
                      _ => Icons.school,
                    }),
                    title: Text(doc.data()['name'] as String? ?? ''),
                    subtitle: Text('${doc.data()['email'] ?? ''} • ${doc.data()['role'] ?? ''}'),
                    trailing: Switch(
                      value: doc.data()['active'] == true,
                      onChanged: doc.id == me
                          ? null
                          : (v) => doc.reference.update({
                                'active': v,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
