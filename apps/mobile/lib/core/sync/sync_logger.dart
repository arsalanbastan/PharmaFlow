import 'package:logger/logger.dart';

enum SyncLogLevel { info, warning, error, debug }

class SyncLogger {
  SyncLogger._();

  static final SyncLogger instance = SyncLogger._();

  final Logger _logger = Logger(printer: SimplePrinter(printTime: true));

  void log(
    SyncLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final text = '[SYNC][${level.name.toUpperCase()}] $message';

    switch (level) {
      case SyncLogLevel.info:
        _logger.i(text);
        break;
      case SyncLogLevel.warning:
        _logger.w(text);
        break;
      case SyncLogLevel.error:
        _logger.e(text, error: error, stackTrace: stackTrace);
        break;
      case SyncLogLevel.debug:
        _logger.d(text);
        break;
    }
  }

  void info(String message) => log(SyncLogLevel.info, message);

  void warning(String message) => log(SyncLogLevel.warning, message);

  void debug(String message) => log(SyncLogLevel.debug, message);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(SyncLogLevel.error, message, error: error, stackTrace: stackTrace);
  }
}
