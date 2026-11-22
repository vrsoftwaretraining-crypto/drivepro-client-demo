// Developed by @Ramana Code Softwares

import 'dart:developer' as developer;

enum AppLogLevel { debug, info, warning, error }

/// Central application logger. Avoid logging passwords, tokens, or personal data.
class AppLogger {
  AppLogger._();

  static void Function(String message, AppLogLevel level)? testSink;

  static void debug(String message, {String tag = 'DrivePro'}) =>
      _write(message, AppLogLevel.debug, tag);
  static void info(String message, {String tag = 'DrivePro'}) =>
      _write(message, AppLogLevel.info, tag);
  static void warning(String message, {String tag = 'DrivePro'}) =>
      _write(message, AppLogLevel.warning, tag);
  static void error(
    String message, {
    String tag = 'DrivePro',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final details = error == null ? message : '$message: $error';
    _write(details, AppLogLevel.error, tag, stackTrace: stackTrace);
  }

  static void _write(
    String message,
    AppLogLevel level,
    String tag, {
    StackTrace? stackTrace,
  }) {
    final formatted = '[$tag] $message';
    final sink = testSink;
    if (sink != null) {
      sink(formatted, level);
      return;
    }
    developer.log(
      formatted,
      name: 'DrivePro',
      level: switch (level) {
        AppLogLevel.debug => 500,
        AppLogLevel.info => 800,
        AppLogLevel.warning => 900,
        AppLogLevel.error => 1000,
      },
      stackTrace: stackTrace,
    );
  }
}
