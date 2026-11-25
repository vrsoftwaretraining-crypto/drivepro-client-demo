// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../auth/presentation/security_questions_form.dart';

class RolePortalPage extends StatelessWidget {
  const RolePortalPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isStudent = user.role == 'student';
    final uid = user.uid;
    final db = FirebaseFirestore.instance;
    final title = isStudent ? 'Student dashboard' : 'Instructor dashboard';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text(user.name)),
          ),
          IconButton(
            tooltip: 'Security questions',
            onPressed: () => showSecurityQuestionsDialog(context),
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Welcome, ${user.name}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(isStudent
              ? 'Your course, booked lessons, payments and attendance.'
              : 'Your assigned students, vehicle and upcoming driving lessons.'),
          const SizedBox(height: 20),
          if (isStudent) ...[
            _recordCard(
              title: 'My registration',
              stream: db.collection('students').where('userId', isEqualTo: uid).limit(1).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'Registration details are being prepared by the school.',
              builder: (docs) {
                if (docs.isEmpty) return const Text('No registration record found.');
                final data = docs.first;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Course: ${data['course'] ?? '-'}'),
                  Text('Instructor: ${data['assignedInstructorName'] ?? data['assignedInstructorId'] ?? '-'}'),
                  Text('Vehicle: ${data['assignedVehicleRegistration'] ?? data['assignedVehicleId'] ?? '-'}'),
                  Text('Contact: ${data['phone'] ?? user.email}'),
                  Text('Status: ${data['active'] == true ? 'Active' : 'Pending activation'}'),
                  Text('Total fee: ₹${data['totalFee'] ?? 0}'),
                  Text('Paid: ₹${data['paidFee'] ?? 0}'),
                  Text('Balance: ₹${((data['totalFee'] as num?)?.toDouble() ?? 0) - ((data['paidFee'] as num?)?.toDouble() ?? 0)}'),
                ]);
              },
            ),
            _recordCard(
              title: 'Course progress',
              stream: db.collection('lessons').where('studentUserId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'Your course progress will appear after your first lesson is scheduled.',
              builder: (docs) {
                final dates = docs
                    .map((d) => (d['startAt'] as Timestamp?)?.toDate())
                    .whereType<DateTime>()
                    .toList()
                  ..sort();
                final done = docs.where((d) => d['status'] == 'completed').length;
                final total = docs.where((d) => d['status'] != 'cancelled').length;
                final span = dates.length < 2 ? 1 : dates.last.difference(dates.first).inDays + 1;
                final fmt = MaterialLocalizations.of(context);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LinearProgressIndicator(value: total == 0 ? 0 : done / total),
                  const SizedBox(height: 8),
                  Text('$done of $total lessons completed'),
                  if (dates.isNotEmpty) Text('Course start: ${fmt.formatMediumDate(dates.first)}'),
                  if (dates.isNotEmpty) Text('Last scheduled lesson: ${fmt.formatMediumDate(dates.last)} ($span days)'),
                ]);
              },
            ),
            _recordCard(
              title: 'My booked lessons',
              stream: db.collection('lessons').where('studentUserId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No lessons have been scheduled yet.',
              builder: (docs) => _lessonList(docs),
            ),
            _recordCard(
              title: 'Payment history',
              stream: db.collection('payments').where('studentUserId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No payments recorded yet.',
              builder: (docs) => Column(
                children: docs.map((data) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('₹${data['amount'] ?? 0}'),
                    subtitle: Text('${data['method'] ?? 'Payment'} • ${data['status'] ?? ''}'),
                  );
                }).toList(),
              ),
            ),
            _recordCard(
              title: 'Attendance',
              stream: db.collection('attendance').where('studentUserId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'Attendance records will appear here.',
              builder: (docs) => Text('${docs.length} attendance record(s)'),
            ),
            _recordCard(
              title: 'Notifications',
              stream: db.collection('reminders').where('userId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No notifications at present.',
              builder: (docs) => Column(
                children: docs.map((data) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(data['title'] as String? ?? 'Reminder'),
                  subtitle: Text(data['message'] as String? ?? ''),
                )).toList(),
              ),
            ),
          ] else ...[
            _recordCard(
              title: 'My instructor profile',
              stream: db.collection('instructors').doc(uid).snapshots().map((doc) => doc.exists ? [doc.data()!] : <Map<String, dynamic>>[]),
              empty: 'Instructor profile is being prepared.',
              builder: (docs) {
                if (docs.isEmpty) return const Text('No instructor profile found.');
                final data = docs.first;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Phone: ${data['phone'] ?? '-'}'),
                  Text('Assigned vehicle: ${data['assignedVehicleId'] ?? 'Not assigned'}'),
                  Text('Working days: ${(data['workingDays'] as List<dynamic>? ?? []).join(', ')}'),
                  Text('Working hours: ${data['workingHours'] ?? 'Not set'}'),
                ]);
              },
            ),
            _recordCard(
              title: 'My lessons & schedule',
              stream: db.collection('lessons').where('instructorId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No lessons assigned yet.',
              builder: (docs) => _lessonList(docs),
            ),
            _recordCard(
              title: 'Attendance records',
              stream: db.collection('attendance').where('instructorUserId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No attendance records yet.',
              builder: (docs) => Text('${docs.length} attendance record(s)'),
            ),
            _recordCard(
              title: 'Assigned students',
              stream: db.collection('students').where('assignedInstructorId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
              empty: 'No students assigned yet.',
              builder: (docs) => Column(
                children: docs.map((data) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['name'] as String? ?? 'Student'),
                    subtitle: Text(data['phone'] as String? ?? ''),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordCard({
    required String title,
    required Stream<List<Map<String, dynamic>>> stream,
    required String empty,
    required Widget Function(List<Map<String, dynamic>>) builder,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Unable to load this section: ${snapshot.error}');
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) return Text(empty);
                return builder(snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _lessonList(List<Map<String, dynamic>> docs) {
    final sorted = [...docs]..sort((a, b) {
      final aDate = (a['startAt'] as Timestamp?)?.toDate() ?? DateTime(2100);
      final bDate = (b['startAt'] as Timestamp?)?.toDate() ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });
    return Column(
      children: sorted.map((doc) {
        final data = doc;
        final date = (data['startAt'] as Timestamp?)?.toDate();
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available_outlined),
          title: Text('${data['vehicleRegistration'] ?? 'Vehicle'} • ${data['status'] ?? 'scheduled'}'),
          subtitle: Text(date?.toLocal().toString() ?? 'Date to be confirmed'),
        );
      }).toList(),
    );
  }
}
