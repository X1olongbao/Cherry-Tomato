/// Centralized constants for backend configuration.
class Constants {
  // Supabase connection
  static const String supabaseUrl = 'https://mkbjyfyrhubufuqfkooz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rYmp5ZnlyaHVidWZ1cWZrb296Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNTQ5NzQsImV4cCI6MjA3NzYzMDk3NH0.C_nl_tud79C-UJGOMTa44DnuT2-PZzzSezCKsV9CZo8';

  // Supabase table for sessions
  static const String remoteTable = 'pomodoro_sessions';

  // Backend endpoints for Supabase Admin actions (Edge Functions or secure backend)
  // Set these to your deployed function URLs.
  static const String adminCreateUserUrl =
      'https://mkbjyfyrhubufuqfkooz.functions.supabase.co/create_user';
  static const String adminUpdatePasswordUrl =
      'https://mkbjyfyrhubufuqfkooz.functions.supabase.co/update_password';
  static const String adminUpsertProfileUrl =
      'https://mkbjyfyrhubufuqfkooz.functions.supabase.co/upsert_profile';

  // EmailJS configuration (public client-side values)
  // These are used to send verification codes directly from Flutter.
  static const String emailJsServiceId = 'service_oe4q4yn';
  static const String emailJsTemplateId = 'template_x9rq88m';
  static const String emailJsPublicKey = 'PqRWC7QjlXrrkQx54';
}