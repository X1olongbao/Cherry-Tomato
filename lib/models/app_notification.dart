// Removed unused Flutter import

/// Lightweight in-app notification model.
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? read,
  }) => AppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        createdAt: createdAt ?? this.createdAt,
        read: read ?? this.read,
      );
}