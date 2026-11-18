import 'dart:convert';
import 'dart:io';

import '../env_parser.dart';

class ConsoleColor {
  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';
}

enum LogLevel { debug, info, warning, error, critical }

class Log {
  static bool enabled = true;
  static LogLevel minLevel = LogLevel.debug;
  static bool consoleLogging = true; // controls colored console output
  static bool fileLogging = false; // disabled by default
  static String logDirectory = 'logs';

  static bool _configured = false;
  static bool _initialized = false;
  static File? _logFile;

  static Directory get _logDir => Directory(logDirectory);

  static void _configureFromEnv() {
    if (_configured) return;
    _configured = true;

    enabled = FlintEnv.getBool('LOG_ENABLED', enabled);
    consoleLogging = FlintEnv.getBool('LOG_TO_CONSOLE', consoleLogging);
    fileLogging = FlintEnv.getBool('LOG_TO_FILE', fileLogging);
    logDirectory = FlintEnv.get('LOG_DIR', logDirectory).trim();
    if (logDirectory.isEmpty) {
      logDirectory = 'logs';
    }

    final level = FlintEnv.get('LOG_LEVEL', '').toLowerCase().trim();
    const levels = {
      'debug': LogLevel.debug,
      'info': LogLevel.info,
      'warning': LogLevel.warning,
      'error': LogLevel.error,
      'critical': LogLevel.critical,
    };
    final parsed = levels[level];
    if (parsed != null) {
      minLevel = parsed;
    }
  }

  // Initialize logger
  static Future<void> init() async {
    _configureFromEnv();
    if (_initialized) return;
    _initialized = true;

    if (!fileLogging) {
      return;
    }

    if (!await _logDir.exists()) await _logDir.create(recursive: true);
    final fileName = _getLogFileName();
    _logFile = File('${_logDir.path}/$fileName');
    if (!await _logFile!.exists()) await _logFile!.create();
  }

  static String _getLogFileName() {
    final now = DateTime.now();
    return 'flint_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
  }

  static String _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return ConsoleColor.cyan;
      case LogLevel.info:
        return ConsoleColor.green;
      case LogLevel.warning:
        return ConsoleColor.yellow;
      case LogLevel.error:
        return ConsoleColor.red;
      case LogLevel.critical:
        return ConsoleColor.magenta;
    }
  }

  static void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    bool asJson = true, // default true for structured logging
  }) {
    _configureFromEnv();
    if (!enabled || level.index < minLevel.index) return;

    final time = DateTime.now().toIso8601String();
    final levelName = level.name.toUpperCase();
    final prefix = tag != null ? '[$tag]' : '';

    // Build JSON for file/cloud
    final jsonLog = jsonEncode({
      'timestamp': time,
      'level': levelName,
      'tag': tag ?? '',
      'message': message,
      'error': error?.toString(),
      'stack': stackTrace?.toString(),
    });

    // Build console-friendly message
    final consoleMessage =
        '$time [$levelName] $prefix $message${error != null ? '\n$error' : ''}${stackTrace != null ? '\n$stackTrace' : ''}';

    // Print colored console log in dev
    if (consoleLogging) {
      final color = _levelColor(level);
      print('$color$consoleMessage${ConsoleColor.reset}');
    }

    // Optionally write JSON to file
    _writeToFile(jsonLog);
  }

  static void _writeToFile(String message) async {
    if (!fileLogging) return;
    await init();
    if (_logFile == null) return;
    _logFile!.writeAsStringSync('$message\n', mode: FileMode.append);
  }

  // Helper methods
  static void debug(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.debug, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void info(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.info, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void warning(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warning, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void error(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void critical(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.critical, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void success(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.debug, message,
          tag: tag, error: error, stackTrace: stackTrace);
}
