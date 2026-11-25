// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../students/presentation/students_page.dart';
import '../../instructors/presentation/instructors_page.dart';
import '../../vehicles/presentation/vehicles_page.dart';
import '../../lessons/presentation/lessons_page.dart';
import '../../payments/presentation/payments_page.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../certificates/presentation/certificates_page.dart';
import '../../reminders/presentation/reminders_page.dart';
import '../../settings/presentation/school_settings_page.dart';
import '../../admin/presentation/admin_accounts_page.dart';
import '../../call_automation/presentation/call_autoreply_page.dart';
import '../../auth/presentation/security_questions_form.dart';
import '../../call_automation/presentation/enquiries_page.dart';
import '../../schedule/presentation/schedule_page.dart';
import 'role_portal_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedIndex = 0;
  bool _isTelugu = false;

  AppStrings get s => AppStrings(_isTelugu);

  @override
  Widget build(BuildContext context) {
    if (widget.user.role == 'student' || widget.user.role == 'instructor') {
      return RolePortalPage(user: widget.user);
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final labels = [
      s.dashboard,
      s.students,
      s.instructors,
      _isTelugu ? 'వాహనాలు' : 'Vehicles',
      _isTelugu ? 'లెసన్లు' : 'Lessons',
      s.schedule,
      _isTelugu ? 'ఫీజు చెల్లింపులు' : 'Payments',
      _isTelugu ? 'హాజరు' : 'Attendance',
      _isTelugu ? 'రిపోర్టులు' : 'Reports',
      _isTelugu ? 'సర్టిఫికెట్లు' : 'Certificates',
      _isTelugu ? 'రిమైండర్లు' : 'Reminders',
      _isTelugu ? 'స్కూల్ సెట్టింగ్స్' : 'School Settings',
      _isTelugu ? 'కాల్ ఎంక్వైరీలు' : 'Call Enquiries',
      _isTelugu ? 'అడ్మిన్ ఖాతాలు' : 'Admin Accounts',
      _isTelugu ? 'ఆటో SMS' : 'Auto SMS (Phone)',
    ];
    final icons = [
      Icons.dashboard_rounded,
      Icons.people_alt_rounded,
      Icons.badge_rounded,
      Icons.directions_car_rounded,
      Icons.event_available_rounded,
      Icons.calendar_month_rounded,
      Icons.account_balance_wallet_rounded,
      Icons.fact_check_rounded,
      Icons.assessment_rounded,
      Icons.workspace_premium_rounded,
      Icons.notifications_active_rounded,
      Icons.settings_rounded,
      Icons.phone_callback_rounded,
      Icons.admin_panel_settings_rounded,
      Icons.sms_rounded,
    ];

    final pages = [
      _OverviewPage(strings: s),
      const StudentsPage(),
      const InstructorsPage(),
      const VehiclesPage(),
      const LessonsPage(),
      const SchedulePage(),
      const PaymentsPage(),
      const AttendancePage(),
      const ReportsPage(),
      const CertificatesPage(),
      const RemindersPage(),
      const SchoolSettingsPage(),
      const EnquiriesPage(),
      const AdminAccountsPage(),
      const CallAutoReplyPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.directions_car_filled_rounded,
                color: AppTheme.primary,),
            SizedBox(width: 10),
            Text('DrivePro',
                style: TextStyle(fontWeight: FontWeight.w800),),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isTelugu = !_isTelugu),
            icon: const Icon(Icons.translate_rounded),
            label: Text(s.language),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.user.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Security questions',
            onPressed: () => showSecurityQuestionsDialog(context),
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          if (!isWide)
            PopupMenuButton<int>(
                tooltip: 'Open module',
                onSelected: (value) => setState(() => _selectedIndex = value),
                itemBuilder: (context) => List.generate(
                    labels.length,
                    (index) => PopupMenuItem<int>(
                        value: index, child: Text(labels[index]),),),
                icon: const Icon(Icons.apps_rounded),),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) =>
                      setState(() => _selectedIndex = value),
                  extended: width >= 1350,
                  labelType: width >= 1350
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: List.generate(
                    labels.length,
                    (index) => NavigationRailDestination(
                      icon: Icon(icons[index]),
                      label: Text(labels[index]),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[_selectedIndex]),
              ],
            )
          : pages[_selectedIndex],
      bottomNavigationBar: null,
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = [
      (
        strings.totalStudents,
        '248',
        Icons.people_alt_rounded,
        const Color(0xFF3157D5)
      ),
      (
        strings.activeInstructors,
        '12',
        Icons.badge_rounded,
        const Color(0xFF14B8A6)
      ),
      (
        strings.todayLessons,
        '18',
        Icons.calendar_month_rounded,
        const Color(0xFFEA9A35)
      ),
      (
        strings.pendingFees,
        '₹24,500',
        Icons.account_balance_wallet_rounded,
        const Color(0xFFE15B70)
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.welcome,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),),
          const SizedBox(height: 8),
          Text(strings.overview, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 4
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              return GridView.builder(
                itemCount: metrics.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: columns == 1 ? 2.5 : 1.5,
                ),
                itemBuilder: (context, index) {
                  final item = metrics[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(item.$3, color: item.$4, size: 28),
                          Text(item.$2,
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),),
                          Text(item.$1, style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.recentActivity,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading:
                        CircleAvatar(child: Icon(Icons.people_alt_rounded)),
                    title: Text('Student and instructor management'),
                    subtitle:
                        Text('Manage school people and training records.'),
                  ),
                  const Divider(),
                  const ListTile(
                    leading:
                        CircleAvatar(child: Icon(Icons.directions_car_rounded)),
                    title: Text('Vehicles and lesson bookings'),
                    subtitle:
                        Text('Maintain vehicles and schedule driving lessons.'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
