import 'dart:developer' as developer;

import '../models/smart_image_config.dart';

/// Lightweight, zero-dependency internal logger gated by
/// [SmartImageConfig.logLevel].
///
/// Routes through `dart:developer` so messages appear in the IDE/devtools log
/// view without polluting `stdout`. Production builds default to
/// [SmartImageLogLevel.error], so verbose tracing costs nothing unless opted
/// in.
class SmartLogger {
  const SmartLogger._();

  static const String _name = 'SmartImageX';

  static SmartImageLogLevel get _level => SmartImageConfig.instance.logLevel;

  /// Logs an error, optionally with its [error] object and [stackTrace].
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index >= SmartImageLogLevel.error.index) {
      developer.log(
        message,
        name: _name,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logs a warning.
  static void warning(String message) {
    if (_level.index >= SmartImageLogLevel.warning.index) {
      developer.log(message, name: _name, level: 900);
    }
  }

  /// Logs an informational lifecycle message.
  static void info(String message) {
    if (_level.index >= SmartImageLogLevel.info.index) {
      developer.log(message, name: _name, level: 800);
    }
  }

  /// Logs a verbose trace; the [message] builder is only invoked when verbose
  /// logging is active, so expensive string construction is avoided otherwise.
  static void verbose(String Function() message) {
    if (_level.index >= SmartImageLogLevel.verbose.index) {
      developer.log(message(), name: _name, level: 500);
    }
  }
}
