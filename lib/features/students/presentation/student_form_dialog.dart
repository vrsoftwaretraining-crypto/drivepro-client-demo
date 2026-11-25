// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';

import '../../../core/models/student.dart';

class StudentFormDialog extends StatefulWidget {
  const StudentFormDialog({super.key, this.student});

  final Student? student;

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _course;
  late final TextEditingController _totalFee;
  late final TextEditingController _paidFee;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _name = TextEditingController(text: student?.name ?? '');
    _phone = TextEditingController(text: student?.phone ?? '');
    _email = TextEditingController(text: student?.email ?? '');
    _course = TextEditingController(text: student?.course ?? 'Car');
    _totalFee =
        TextEditingController(text: student?.totalFee.toString() ?? '0');
    _paidFee = TextEditingController(text: student?.paidFee.toString() ?? '0');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _course.dispose();
    _totalFee.dispose();
    _paidFee.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final total = double.tryParse(_totalFee.text.trim()) ?? 0;
    final paid = double.tryParse(_paidFee.text.trim()) ?? 0;
    if (paid > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid fee cannot exceed total fee.')),
      );
      return;
    }

    Navigator.of(context).pop(
      Student(
        id: widget.student?.id ?? '',
        name: _name.text,
        phone: _phone.text,
        email: _email.text,
        course: _course.text,
        totalFee: total,
        paidFee: paid,
        active: widget.student?.active ?? true,
        createdAt: widget.student?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.student == null ? 'Add student' : 'Edit student'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Full name'),
                _field(_phone, 'Phone number', keyboard: TextInputType.phone),
                _field(_email, 'Email (optional)', required: false),
                _field(_course, 'Course'),
                _field(_totalFee, 'Total fee',
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),),
                _field(_paidFee, 'Paid fee',
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return '$label is required.';
          }
          if ((label == 'Total fee' || label == 'Paid fee') &&
              value != null &&
              (double.tryParse(value) == null || double.parse(value) < 0)) {
            return 'Enter a valid non-negative amount.';
          }
          return null;
        },
      ),
    );
  }
}
