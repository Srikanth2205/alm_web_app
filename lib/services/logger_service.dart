class LoggerService {
  static bool _initialized = false;
  static List<String> _logs = [];

  static Future<void> initialize() async {
    _initialized = true;
  }

  static Future<void> log(String message) async {
    if (!_initialized) {
      await initialize();
    }
    
    _logs.add('${DateTime.now()}: $message');
    // For development, print to console
    print('LOG: $message');
  }

  static List<String> getLogs() {
    return List.from(_logs);
  }

  static void clearLogs() {
    _logs.clear();
  }
} 