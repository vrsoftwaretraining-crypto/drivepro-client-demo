// Developed by @Ramana Code Softwares

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/errors/startup_error_app.dart';
import 'core/logging/app_logger.dart';
import 'core/demo/demo_backend.dart';
import 'core/services/backend.dart';
import 'core/services/emulator.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);

      AppLogger.error(
        'Flutter framework exception',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error(
        'Uncaught platform exception',
        error: error,
        stackTrace: stack,
      );

      return true;
    };

    try {
      if (demoMode) {
        // Demo build: no Firebase project, no database. Sample data lives in memory only.
        await DemoBackend.install();
        AppLogger.info('Demo mode: in-memory sample data installed');
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        connectEmulators(Firebase.app());

        AppLogger.info('Firebase initialized successfully');
      }

      runApp(
        const ProviderScope(
          child: DriveProApp(),
        ),
      );
    } catch (error, stack) {
      AppLogger.error(
        'Application startup failed',
        error: error,
        stackTrace: stack,
      );

      runApp(const StartupErrorApp());
    }
  }, (error, stack) {
    AppLogger.error(
      'Uncaught asynchronous exception',
      error: error,
      stackTrace: stack,
    );
  });
}
