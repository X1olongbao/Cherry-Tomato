/// Represents an authenticated user in the Cherry Tomato backend.
/// Minimal fields to keep backend services UI-agnostic.
class AppUser {
  final String id;
  final String? email;
  final String? username;

  const AppUser({required this.id, this.email, this.username});
}