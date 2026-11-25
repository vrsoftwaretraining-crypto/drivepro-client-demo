// Developed by @Ramana Code Softwares

import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../firebase_options.dart';
import '../logging/app_logger.dart';
import 'app_error_screen.dart';

class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({super.key});

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info('Firebase initialized after retry');
      if (!mounted) return;
      runApp(const ProviderScope(child: DriveProApp()));
    } catch (error, stack) {
      AppLogger.error('Firebase initialization retry failed',
          error: error, stackTrace: stack,);
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            AppErrorScreen(onRetry: _retrying ? null : _retry),
            if (_retrying)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
