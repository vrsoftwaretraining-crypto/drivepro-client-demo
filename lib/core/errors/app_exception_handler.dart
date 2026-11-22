// Developed by @Ramana Code Softwares

import '../logging/app_logger.dart';

/// Logs an operation failure once and rethrows it so callers can show UI feedback.
class AppExceptionHandler {
  AppExceptionHandler._();

  static Future<T> guard<T>(
    String operation,
    Future<T> Function() action, {
    String tag = 'App',
  }) async {
    try {
      return await action();
    } catch (error, stack) {
      AppLogger.error(operation, tag: tag, error: error, stackTrace: stack);
      rethrow;
    }
  }
}
