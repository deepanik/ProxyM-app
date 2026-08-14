enum LogLevel { info, warning, error, debug }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata,
  });

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19);
    final metaStr = metadata != null ? ' | metadata: $metadata' : '';
    return '[$timeStr] [${level.name.toUpperCase()}] [$category] $message$metaStr';
  }
}

class DiagnosticsLogger {
  static final DiagnosticsLogger instance = DiagnosticsLogger._internal();
  DiagnosticsLogger._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(LogLevel level, String category, String message, [Map<String, dynamic>? metadata]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata,
    );

    _logs.add(entry);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    print(entry.toString());
  }

  void info(String category, String message, [Map<String, dynamic>? meta]) =>
      log(LogLevel.info, category, message, meta);

  void warn(String category, String message, [Map<String, dynamic>? meta]) =>
      log(LogLevel.warning, category, message, meta);

  void error(String category, String message, [Map<String, dynamic>? meta]) =>
      log(LogLevel.error, category, message, meta);

  void debug(String category, String message, [Map<String, dynamic>? meta]) =>
      log(LogLevel.debug, category, message, meta);

  void clear() => _logs.clear();
}
