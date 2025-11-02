/// Represents an authenticated user in the Cherry Tomato backend.
/// Minimal fields to keep backend services UI-agnostic.
class AppUser {
  final String id;
  final String? email;

  const AppUser({required this.id, this.email});
}