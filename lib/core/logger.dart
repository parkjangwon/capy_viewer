import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as logger_pkg;

class DebugOnlyFilter extends logger_pkg.LogFilter {
  DebugOnlyFilter({bool Function()? isEnabled})
      : _isEnabled = isEnabled ?? (() => kDebugMode);

  final bool Function() _isEnabled;

  @override
  bool shouldLog(logger_pkg.LogEvent event) {
    final minimumLevel = level ?? logger_pkg.Logger.level;
    return _isEnabled() && event.level.value >= minimumLevel.value;
  }
}

class Logger {
  static final Logger _instance = Logger._();
  late final logger_pkg.Logger _logger;

  Logger._() {
    _logger = logger_pkg.Logger(filter: DebugOnlyFilter());
  }

  factory Logger() => _instance;

  void d(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  void i(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void w(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void e(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
