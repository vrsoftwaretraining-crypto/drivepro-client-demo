// Developed by @Ramana Code Softwares

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/school_service.dart';
import 'security_questions_form.dart';

/// UIDs that chose "Skip for now" this session (only allowed when no
/// password change is required).
final setupSkippedProvider = StateProvider<Set<String>>((ref) => <String>{});

/// First-login gate: default admin must change the password; every account
/// is asked to save security questions so it can recover its own password.
class AccountSetupPage extends ConsumerStatefulWidget {
  const AccountSetupPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _draft = SecurityQuestionDraft();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_draft.isValid) {
      setState(() => _error = 'Choose 3 different questions and answer all of them.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.user.mustChangePassword) {
        await FirebaseAuth.instance.currentUser!.updatePassword(_password.text);
      }
      await SchoolService.saveSecurityQuestions(_draft.toPayload());
      ref.invalidate(appUserProvider);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Could not change the password.');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mustChange = widget.user.mustChangePassword;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure your account'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  mustChange
                      ? 'You are using the default password. Set a new password and security questions to continue.'
                      : 'Set your security questions so you can reset your password if you forget it.',
                ),
                const SizedBox(height: 16),
                if (mustChange) ...[
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (min 8 characters)'),
                    validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
                  ),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                SecurityQuestionsEditor(draft: _draft),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Save and continue'),
                ),
                if (!mustChange)
                  TextButton(
                    onPressed: () => ref.read(setupSkippedProvider.notifier).state = {
                      ...ref.read(setupSkippedProvider),
                      widget.user.uid,
                    },
                    child: const Text('Skip for now'),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
