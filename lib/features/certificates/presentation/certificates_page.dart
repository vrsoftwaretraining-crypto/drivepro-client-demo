// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/student.dart';
import '../../students/providers/student_providers.dart';

class CertificatesPage extends ConsumerWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load students: $error')),
        data: (students) {
          final activeStudents =
              students.where((student) => student.active).toList();
          if (activeStudents.isEmpty) {
            return const Center(
                child: Text('No active students available for certificates.'),);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Student certificates',
                  style: Theme.of(context).textTheme.headlineSmall,),
              const SizedBox(height: 8),
              const Text(
                  'Generate a printable course completion certificate for an active student. Verify course completion before issuing.',),
              const SizedBox(height: 16),
              ...activeStudents.map(
                (student) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.workspace_premium_outlined),),
                    title: Text(student.name),
                    subtitle: Text('${student.course} • ${student.phone}'),
                    trailing: IconButton(
                      tooltip: 'Preview and print certificate',
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => _printCertificate(context, student),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printCertificate(BuildContext context, Student student) async {
    final issueDate = DateFormat.yMMMMd().format(DateTime.now());
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(35),
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(28),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey, width: 3),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('DRIVING SCHOOL',
                  style: const pw.TextStyle(
                      fontSize: 14,
                      letterSpacing: 3,
                      color: PdfColors.blueGrey,),),
              pw.SizedBox(height: 18),
              pw.Text('CERTIFICATE OF COMPLETION',
                  style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo,),),
              pw.SizedBox(height: 30),
              pw.Text('This is to certify that',
                  style: const pw.TextStyle(fontSize: 16),),
              pw.SizedBox(height: 12),
              pw.Text(student.name,
                  style: pw.TextStyle(
                      fontSize: 30, fontWeight: pw.FontWeight.bold,),),
              pw.SizedBox(height: 12),
              pw.Text('has completed the training course: ${student.course}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 17),),
              pw.SizedBox(height: 28),
              pw.Text('Issued on $issueDate',
                  style: const pw.TextStyle(fontSize: 12),),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.Text('Instructor signature'),
                  ],),
                  pw.Column(children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.Text('Authorized signature'),
                  ],),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    try {
      await Printing.layoutPdf(onLayout: (_) => document.save());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Certificate export failed: $error')),);
      }
    }
  }
}
