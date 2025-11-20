enum SessionType { pomodoro, shortBreak, longBreak }

extension SessionTypeMapper on SessionType {
  String get dbValue {
    switch (this) {
      case SessionType.pomodoro:
        return 'pomodoro';
      case SessionType.shortBreak:
        return 'short_break';
      case SessionType.longBreak:
        return 'long_break';
    }
  }

  static SessionType fromDb(String? value) {
    switch (value) {
      case 'short_break':
        return SessionType.shortBreak;
      case 'long_break':
        return SessionType.longBreak;
      case 'pomodoro':
      default:
        return SessionType.pomodoro;
    }
  }
}

