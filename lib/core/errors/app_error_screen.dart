// Developed by @Ramana Code Softwares

import 'package:material_ui/material_ui.dart';

class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 56, color: colors.error),
                const SizedBox(height: 20),
                Text('Unable to start DrivePro',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,),
                const SizedBox(height: 10),
                Text(
                  'The app could not connect to its required services. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
