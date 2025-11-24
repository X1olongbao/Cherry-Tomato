/// Simple logger helper to keep backend code UI-agnostic.
class Logger {
  static void i(String msg) => _print('INFO', msg);
  static void w(String msg) => _print('WARN', msg);
  static void e(String msg) => _print('ERROR', msg);

  static void _print(String level, String msg) {
    // In production you could route this to a real logging backend.
    // For now, keep it simple.
    // ignore: avoid_print
    print('[$level] $msg');
  }
}