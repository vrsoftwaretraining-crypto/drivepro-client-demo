// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';

import '../../../core/services/school_service.dart';

const securityQuestionChoices = <String>[
  'What was the name of your first school?',
  'What is your mother\'s maiden name?',
  'What was the name of your first pet?',
  'In which town were you born?',
  'What was your childhood nickname?',
  'What is the name of your favourite teacher?',
  'What was the make of your first vehicle?',
  'What is your favourite food?',
];

/// Holds the 3 chosen questions and answer controllers.
class SecurityQuestionDraft {
  SecurityQuestionDraft()
      : questions = [
          securityQuestionChoices[0],
          securityQuestionChoices[1],
          securityQuestionChoices[2],
        ],
        answers = List.generate(3, (_) => TextEditingController());

  final List<String> questions;
  final List<TextEditingController> answers;

  bool get isValid =>
      questions.toSet().length == 3 &&
      answers.every((a) => a.text.trim().length >= 2);

  List<Map<String, String>> toPayload() => [
        for (var i = 0; i < 3; i++)
          {'question': questions[i], 'answer': answers[i].text.trim()},
      ];

  void dispose() {
    for (final a in answers) {
      a.dispose();
    }
  }
}

class SecurityQuestionsEditor extends StatefulWidget {
  const SecurityQuestionsEditor({required this.draft, super.key});

  final SecurityQuestionDraft draft;

  @override
  State<SecurityQuestionsEditor> createState() =>
      _SecurityQuestionsEditorState();
}

class _SecurityQuestionsEditorState extends State<SecurityQuestionsEditor> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Column(children: [
      for (var i = 0; i < 3; i++) ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: d.questions[i],
          decoration: InputDecoration(labelText: 'Security question ${i + 1}'),
          items: [
            for (final q in securityQuestionChoices)
              DropdownMenuItem(value: q, child: Text(q, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => d.questions[i] = v ?? d.questions[i]),
        ),
        TextFormField(
          controller: d.answers[i],
          decoration: InputDecoration(labelText: 'Answer ${i + 1}'),
          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter an answer' : null,
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

/// Dialog for any signed-in user to set / update their security questions.
Future<void> showSecurityQuestionsDialog(BuildContext context) async {
  final draft = SecurityQuestionDraft();
  final formKey = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Security questions'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Used to reset your password if you forget it. Pick 3 different questions.'),
              const SizedBox(height: 12),
              SecurityQuestionsEditor(draft: draft),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate() && draft.isValid) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  final payload = draft.toPayload();
  draft.dispose();
  if (ok != true || !context.mounted) return;
  try {
    await SchoolService.saveSecurityQuestions(payload);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Security questions saved.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
