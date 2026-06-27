/// Centralised application logger.
///
/// Writes log entries to a rotating set of files under the app's documents
/// directory (`logs/`). Also prints to the console in debug mode.
///
/// Usage:
///   // Initialise once in main():
///   await AppLogger.instance.init();
///
///   // Log from anywhere:
///   AppLogger.instance.i('Dashboard loaded');
///   AppLogger.instance.e('Network call failed', error: e, stackTrace: s);
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Log severity levels – ordered by increasing importance.
enum LogLevel {
  debug('DEBUG', 0),
  info('INFO', 1),
  warn('WARN', 2),
  error('ERROR', 3);

  const LogLevel(this.label, this.priority);
  final String label;
  final int priority;
}

/// A lightweight, file-backed logger with automatic rotation.
///
/// Log files live in `<appDocDir>/logs/app.log` with up to [maxBackupFiles]
/// rotated copies (`app.log.1`, `app.log.2`, …). Rotation triggers when the
/// active file exceeds [maxFileSizeBytes].
class AppLogger {
  AppLogger._();

  /// Global singleton.
  static final AppLogger instance = AppLogger._();

  static const int _defaultMaxFileSize = 5 * 1024 * 1024; // 5 MB
  static const int _defaultMaxBackups = 3;

  /// Max size threshold before rotation (bytes).
  int maxFileSizeBytes = _defaultMaxFileSize;

  /// Number of rotated backup files to keep.
  int maxBackupFiles = _defaultMaxBackups;

  /// Minimum level to actually write.
  LogLevel minLevel = LogLevel.debug;

  bool _initialised = false;
  late String _logDir;
  late String _logFilePath;
  IOSink? _sink;

  /// Initialise the logger. Idempotent — safe to call multiple times.
  Future<void> init({
    int? maxFileSizeBytes,
    int? maxBackupFiles,
    LogLevel? minLevel,
  }) async {
    if (_initialised) return;

    this.maxFileSizeBytes = maxFileSizeBytes ?? _defaultMaxFileSize;
    this.maxBackupFiles = maxBackupFiles ?? _defaultMaxBackups;
    this.minLevel = minLevel ?? LogLevel.debug;

    final docs = await getApplicationDocumentsDirectory();
    _logDir = '${docs.path}/logs';
    _logFilePath = '$_logDir/app.log';

    await Directory(_logDir).create(recursive: true);
    _sink = File(_logFilePath).openWrite(mode: FileMode.append);
    _initialised = true;

    // Log after initialised – goes straight to file, no recursion.
    _writeLine(_rawLine(LogLevel.info, 'LOGGER',
        'Logger initialised – file: $_logFilePath'));
  }

  // ------------------------------------------------------------------
  //  Public logging helpers
  // ------------------------------------------------------------------

  void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.debug, tag, message, error: error, stackTrace: stackTrace);

  void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.info, tag, message, error: error, stackTrace: stackTrace);

  void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warn, tag, message, error: error, stackTrace: stackTrace);

  void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  /// Flush and close the file handle. Call on shutdown.
  Future<void> close() async {
    if (!_initialised) return;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _initialised = false;
  }

  /// Path to the active log file, or `null` if not initialised.
  String? get logFilePath => _initialised ? _logFilePath : null;

  /// Read the full contents of the current log file.
  Future<String> readAll() async {
    if (!_initialised) return '';
    try {
      final f = File(_logFilePath);
      if (await f.exists()) return await f.readAsString();
    } catch (_) {}
    return '';
  }

  // ------------------------------------------------------------------
  //  Internal
  // ------------------------------------------------------------------

  void _log(
    LogLevel level,
    String? tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.priority < minLevel.priority) return;

    final line =
        _rawLine(level, tag, message, error: error, stackTrace: stackTrace);

    // Console output in debug/profile mode
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint(line);
    }

    _writeLine(line);
  }

  String _rawLine(
    LogLevel level,
    String? tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final ts = DateTime.now().toIso8601String();
    final tagPart = tag != null ? '[$tag] ' : '';
    final buf = StringBuffer('$ts ${level.label} $tagPart$message');
    if (error != null) buf.write('\n  Error: $error');
    if (stackTrace != null) buf.write('\n  StackTrace:\n$stackTrace');
    return buf.toString();
  }

  void _writeLine(String line) {
    _sink?.writeln(line);
    // Fire-and-forget rotation check (async, non-blocking).
    _rotateIfNeeded();
  }

  Future<void> _rotateIfNeeded() async {
    if (!_initialised) return;
    try {
      final file = File(_logFilePath);
      final stat = await file.stat();
      if (stat.size < maxFileSizeBytes) return;

      // Close current handle
      await _sink?.flush();
      await _sink?.close();
      _sink = null;

      // Shift backups: app.log.2 → app.log.3, app.log.1 → app.log.2, …
      for (var i = maxBackupFiles - 1; i >= 1; i--) {
        final src = File('$_logFilePath.$i');
        final dst = File('$_logFilePath.${i + 1}');
        if (await src.exists()) {
          if (await dst.exists()) await dst.delete();
          await src.rename(dst.path);
        }
      }

      // Move current → app.log.1
      final firstBackup = File('$_logFilePath.1');
      if (await firstBackup.exists()) await firstBackup.delete();
      await file.rename(firstBackup.path);

      // Re-open fresh file
      _sink = File(_logFilePath).openWrite(mode: FileMode.append);
    } catch (_) {
      // Rotation failure must never be fatal.
    }
  }
}
