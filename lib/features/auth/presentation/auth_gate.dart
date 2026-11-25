// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_backend.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/backend.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import 'account_setup_page.dart';
import 'public_landing_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _LoadingScreen(),
      error: (error, stack) =>
          _MessageScreen(message: 'Authentication error: $error'),
      data: (user) {
        if (user == null) return demoMode ? const _DemoAccessScreen() : const PublicLandingPage();

        final profile = ref.watch(appUserProvider);
        return profile.when(
          loading: () => const _LoadingScreen(),
          error: (error, stack) =>
              _MessageScreen(message: 'Profile error: $error'),
          data: (appUser) {
            if (appUser == null || !appUser.active ||
                !const ['admin', 'instructor', 'student'].contains(appUser.role)) {
              return const _MessageScreen(
                message:
                    'Your account profile is inactive or has an unsupported role. Please contact your school administrator.',
                allowSignOut: true,
              );
            }
            final skipped = ref.watch(setupSkippedProvider);
            if (appUser.needsSetup &&
                (appUser.mustChangePassword || !skipped.contains(appUser.uid))) {
              return AccountSetupPage(user: appUser);
            }
            return DashboardPage(user: appUser);
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageScreen extends ConsumerWidget {
  const _MessageScreen({
    required this.message,
    this.allowSignOut = false,
  });

  final String message;
  final bool allowSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (allowSignOut) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Demo-only role shortcuts. Each button signs into the seeded in-memory account
/// so the client can inspect all portals without typing credentials.
class _DemoAccessScreen extends StatelessWidget {
  const _DemoAccessScreen();

  Future<void> _openRole(BuildContext context, String email, String role) async {
    try {
      await Backend.auth.signInWithEmailAndPassword(email: email, password: 'demo');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $role demo: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drive_eta_rounded, size: 64, color: Color(0xFF1E5AA8)),
                const SizedBox(height: 12),
                Text('DrivePro Client Demo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Choose any portal to explore. No login or password is required.', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _DemoRoleCard(icon: Icons.admin_panel_settings, title: 'Admin Portal', subtitle: 'Manage the school and view all modules', color: const Color(0xFF1E5AA8), onTap: () => _openRole(context, demoAdminEmail, 'Admin')),
                    _DemoRoleCard(icon: Icons.school_rounded, title: 'Instructor Portal', subtitle: 'View instructor schedule and students', color: const Color(0xFF18866B), onTap: () => _openRole(context, demoInstructorEmail, 'Instructor')),
                    _DemoRoleCard(icon: Icons.person_rounded, title: 'Student Portal', subtitle: 'View bookings, progress and payments', color: const Color(0xFF8053B8), onTap: () => _openRole(context, demoStudentEmail, 'Student')),
                    _DemoRoleCard(icon: Icons.public_rounded, title: 'Public Website', subtitle: 'Explore courses, instructors and booking pages', color: const Color(0xFFB26A24), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PublicLandingPage()))),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Demo data is temporary and resets when the page reloads.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoRoleCard extends StatelessWidget {
  const _DemoRoleCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: .12), foregroundColor: color, child: Icon(icon)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12)),
              ])),
              Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      ),
    ),
  );
}
