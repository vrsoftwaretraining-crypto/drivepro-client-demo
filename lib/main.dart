// Developed by @Ramana Code Softwares

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/errors/startup_error_app.dart';
import 'core/logging/app_logger.dart';
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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      AppLogger.info('Firebase initialized successfully');

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
