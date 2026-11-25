// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';

import '../../../core/services/school_service.dart';

/// Reset a forgotten password by answering the saved security questions.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _id = TextEditingController();
  final _answers = List.generate(3, (_) => TextEditingController());
  List<String> _questions = [];
  bool _busy = false;
  bool _done = false;
  String _sentTo = '';
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    for (final a in _answers) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (_id.text.trim().isEmpty) {
      setState(() => _error = 'Enter your username or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await SchoolService.getSecurityQuestions(_id.text.trim());
      setState(() => _questions = q);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_answers.any((a) => a.text.trim().isEmpty)) {
      setState(() => _error = 'Answer all three questions.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = await SchoolService.resetWithAnswers(
          _id.text.trim(), _answers.map((a) => a.text.trim()).toList());
      setState(() {
        _done = true;
        _sentTo = email;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot password'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _done
              ? Text('Answers verified. A password reset link was sent to $_sentTo. Open it to set a new password.')
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: _id,
                    enabled: _questions.isEmpty,
                    decoration: const InputDecoration(labelText: 'Username or email'),
                  ),
                  if (_questions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < _questions.length; i++)
                      TextField(
                        controller: _answers[i],
                        decoration: InputDecoration(labelText: _questions[i]),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_done ? 'Close' : 'Cancel'),
        ),
        if (!_done)
          FilledButton(
            onPressed: _busy ? null : (_questions.isEmpty ? _loadQuestions : _reset),
            child: Text(_questions.isEmpty ? 'Continue' : 'Verify & send reset link'),
          ),
      ],
    );
  }
}
