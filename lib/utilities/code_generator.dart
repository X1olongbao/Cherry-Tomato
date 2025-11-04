import 'dart:math';

/// Generates a random 6-character alphanumeric verification code.
String generateVerificationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random.secure();
  return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
}