import 'package:logger/logger.dart' as logger_pkg;

class Logger {
  static final Logger _instance = Logger._();
  late final logger_pkg.Logger _logger;

  Logger._() {
    _logger = logger_pkg.Logger();
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