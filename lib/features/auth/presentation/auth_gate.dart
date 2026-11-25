// Developed by @Ramana Code Softwares

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
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
        if (user == null) return const PublicLandingPage();

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
