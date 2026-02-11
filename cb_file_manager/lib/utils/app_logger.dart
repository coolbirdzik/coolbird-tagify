import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized logging utility for the application.
///
/// Usage:
/// ```dart
/// AppLogger.debug('Debug message');
/// AppLogger.info('Info message');
/// AppLogger.warning('Warning message');
/// AppLogger.error('Error message', error: e, stackTrace: st);
/// AppLogger.perf('Perf message') // performance logs (written to perf log file in debug)
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.debug,
  );

  /// Log a debug message
  static void debug(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  static void info(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  static void warning(dynamic message,
      {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  static void error(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error message
  static void fatal(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Performance log helper — writes to logger and appends to a perf log file
  /// Only writes to disk in non-release builds to avoid I/O in production.
  static void perf(String message) {
    // Always emit to the in-memory logger
    _logger.d(message);

    // Also emit via dart:developer so Flutter DevTools Logging definitely captures it
    try {
      developer.log(message, name: 'cb_file_manager.perf', level: 800);
    } catch (_) {}

    // Ensure it also appears in the stdout/terminal
    try {
      debugPrint(message);
    } catch (_) {}

    // Append to a persistent perf log file in debug/profile for offline analysis
    if (!kReleaseMode) {
      _appendPerfLog(message); // fire-and-forget
    }
  }

  static Future<void> _appendPerfLog(String message) async {
    try {
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}${Platform.pathSeparator}cb_file_manager_perf.log');
      final ts = DateTime.now().toIso8601String();
      await file.writeAsString('[$ts] $message\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // ignore — logging must not crash the app
    }
  }

  /// Set the log level
  static void setLevel(Level level) {
    Logger.level = level;
  }
}
