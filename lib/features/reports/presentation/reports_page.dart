// Developed by @Ramana Code Softwares

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/student.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/attendance.dart';
import '../../students/providers/student_providers.dart';
import '../../payments/providers/payment_providers.dart';
import '../../attendance/providers/attendance_providers.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);
    final payments = ref.watch(paymentsProvider);
    final attendance = ref.watch(attendanceProvider);
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: students.when(
                data: (ss) => payments.when(
                    data: (ps) => attendance.when(
                        data: (ats) => _ReportContent(
                            students: ss, payments: ps, attendance: ats,),
                        error: (e, _) => _err(e),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),),
                    error: (e, _) => _err(e),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),),
                error: (e, _) => _err(e),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),),),);
  }

  Widget _err(Object e) =>
      Center(child: Text('Unable to load report data: $e'));
}

class _ReportContent extends StatelessWidget {
  const _ReportContent(
      {required this.students,
      required this.payments,
      required this.attendance,});
  final List<Student> students;
  final List<FeePayment> payments;
  final List<LessonAttendance> attendance;
  @override
  Widget build(BuildContext context) {
    final total = students.fold<double>(0, (v, s) => v + s.totalFee);
    final paid = students.fold<double>(0, (v, s) => v + s.paidFee);
    final pending = (total - paid).clamp(0, double.infinity);
    final now = DateTime.now();
    final monthPayments = payments
        .where((p) => p.paidAt.year == now.year && p.paidAt.month == now.month)
        .fold<double>(0, (v, p) => v + p.amount);
    final present = attendance.where((a) => a.status == 'present').length;
    return ListView(children: [
      Text('School reports', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _metric('Total fees', '₹${total.toStringAsFixed(0)}'),
        _metric('Collected', '₹${paid.toStringAsFixed(0)}'),
        _metric('Pending', '₹${pending.toStringAsFixed(0)}'),
        _metric('This month', '₹${monthPayments.toStringAsFixed(0)}'),
        _metric('Students', '${students.length}'),
        _metric('Present lessons', '$present / ${attendance.length}'),
      ],),
      const SizedBox(height: 24),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export reports',
                        style: Theme.of(context).textTheme.titleLarge,),
                    const SizedBox(height: 8),
                    const Text(
                        'Export student fee balances, payment transactions and lesson attendance.',),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      FilledButton.icon(
                          onPressed: () => _exportExcel(context),
                          icon: const Icon(Icons.table_view),
                          label: const Text('Export Excel (.xlsx)'),),
                      OutlinedButton.icon(
                          onPressed: () => _exportPdf(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Print / Save PDF'),),
                    ],),
                  ],),),),
      const SizedBox(height: 16),
      Text('Fee balances', style: Theme.of(context).textTheme.titleLarge),
      ...students.map((s) => ListTile(
          dense: true,
          title: Text(s.name),
          subtitle: Text(s.course),
          trailing: Text('₹${s.pendingFee.toStringAsFixed(0)} pending'),),),
    ],);
  }

  Widget _metric(String label, String value) => SizedBox(
      width: 165,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    const SizedBox(height: 8),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,),),
                  ],),),),);
  Future<void> _exportExcel(BuildContext context) async {
    try {
      final book = Excel.createExcel();
      final fees = book['Fee Summary'];
      fees.appendRow([
        TextCellValue('Student'),
        TextCellValue('Course'),
        TextCellValue('Total Fee'),
        TextCellValue('Paid'),
        TextCellValue('Pending'),
      ]);
      for (final s in students) {
        fees.appendRow([
          TextCellValue(s.name),
          TextCellValue(s.course),
          DoubleCellValue(s.totalFee),
          DoubleCellValue(s.paidFee),
          DoubleCellValue(s.pendingFee),
        ]);
      }
      final tx = book['Payments'];
      tx.appendRow([
        TextCellValue('Date'),
        TextCellValue('Student'),
        TextCellValue('Receipt'),
        TextCellValue('Method'),
        TextCellValue('Amount'),
      ]);
      for (final p in payments) {
        tx.appendRow([
          TextCellValue(DateFormat.yMd().format(p.paidAt)),
          TextCellValue(p.studentName),
          TextCellValue(p.receiptNo),
          TextCellValue(p.method),
          DoubleCellValue(p.amount),
        ]);
      }
      final att = book['Attendance'];
      att.appendRow([
        TextCellValue('Date'),
        TextCellValue('Student'),
        TextCellValue('Instructor'),
        TextCellValue('Status'),
      ]);
      for (final a in attendance) {
        att.appendRow([
          TextCellValue(DateFormat.yMd().format(a.lessonAt)),
          TextCellValue(a.studentName),
          TextCellValue(a.instructorName),
          TextCellValue(a.status),
        ]);
      }
      final bytes = book.encode();
      if (bytes == null) throw StateError('Excel generation failed.');
      await FileSaver.instance.saveFile(
          name:
              'DrivePro_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
          bytes: Uint8List.fromList(bytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel report exported.')),);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Excel export failed: $e')));
      }
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
              pw.Text('DrivePro - Driving School Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold,),),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Generated: ${DateFormat.yMMMd().format(DateTime.now())}',),
              pw.SizedBox(height: 16),
              pw.Text('Fee summary',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold,),),
              pw.TableHelper.fromTextArray(
                  headers: ['Student', 'Course', 'Total', 'Paid', 'Pending'],
                  data: students
                      .map((s) => [
                            s.name,
                            s.course,
                            s.totalFee.toStringAsFixed(0),
                            s.paidFee.toStringAsFixed(0),
                            s.pendingFee.toStringAsFixed(0),
                          ],)
                      .toList(),),
              pw.SizedBox(height: 16),
              pw.Text('Payment transactions',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold,),),
              pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Student', 'Receipt', 'Method', 'Amount'],
                  data: payments
                      .map((p) => [
                            DateFormat.yMd().format(p.paidAt),
                            p.studentName,
                            p.receiptNo,
                            p.method,
                            p.amount.toStringAsFixed(2),
                          ],)
                      .toList(),),
              pw.SizedBox(height: 16),
              pw.Text('Lesson attendance',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold,),),
              pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Student', 'Instructor', 'Status'],
                  data: attendance
                      .map((a) => [
                            DateFormat.yMd().format(a.lessonAt),
                            a.studentName,
                            a.instructorName,
                            a.status,
                          ],)
                      .toList(),),
            ],),);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) => doc.save());
  }
}
