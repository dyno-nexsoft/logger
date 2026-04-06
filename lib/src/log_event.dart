import 'package:clock/clock.dart';

import 'log_level.dart';

class LogEvent {
  final Level level;
  final dynamic message;
  final Object? error;
  final StackTrace? stackTrace;

  /// Time when this log was created.
  ///
  /// If not provided, the current time will be used.
  final DateTime time;

  LogEvent(
    this.level,
    this.message, {
    DateTime? time,
    this.error,
    this.stackTrace,
  }) : time = time ?? clock.now();

  Map<String, dynamic> toJson() {
    var stackTrace = this.stackTrace;
    if (level >= Level.warning) {
      stackTrace = StackTrace.current;
    }
    return {
      'level': level.name,
      'message': message,
      'time': time.millisecondsSinceEpoch,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }
}
