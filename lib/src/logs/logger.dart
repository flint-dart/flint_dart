import 'dart:convert';
import 'dart:io';

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

  static final Directory logDir = Directory('logs');
  static File? _logFile;

  // Initialize logger
  static Future<void> init() async {
    if (!await logDir.exists()) await logDir.create(recursive: true);
    final fileName = _getLogFileName();
    _logFile = File('${logDir.path}/$fileName');
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

    // Always write JSON to file
    _writeToFile(jsonLog);
  }

  static void _writeToFile(String message) async {
    await init();
    if (_logFile == null) return;
    _logFile!.writeAsStringSync(message + '\n', mode: FileMode.append);
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
}
