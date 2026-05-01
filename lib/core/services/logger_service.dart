import 'package:logger/logger.dart';

class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 2, errorMethodCount: 8),
  );

  static bool debugEnabled = true;

  static void d(String message) {
    if (debugEnabled) _logger.d(message);
  }

  static void i(String message) => _logger.i(message);
  static void w(String message) => _logger.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
