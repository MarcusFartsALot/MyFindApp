/// Central configuration for the Flutter application.
///
/// The Supabase URL and anon key are public client settings. Never put the
/// Supabase service-role key in this file; it belongs only in the PHP server
/// environment.
class AppConfig {
  AppConfig._();

  // App
  static const String appName = 'MyFind';
  static const String appVersion = '1.0.0';

  // Supabase
  // These defaults let the project run with a plain `flutter run`. They can
  // still be overridden by using --dart-define for another environment.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kfvhnpkkwxipschhlouk.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtmdmhucGtrd3hpcHNjaGhsb3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxMzY4NzksImV4cCI6MjA5ODcxMjg3OX0.4IX5V5CvzClsiM4vuafW8NAwBVE1YhGDdmpeo1eaIWs',
  );
  static const String passwordResetRedirectUrl = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'io.myfind.app://reset-password',
  );

  // Supabase Storage
  static const String registrationDocumentsBucket = 'registration-documents';
  static const int maximumDocumentBytes = 10 * 1024 * 1024;

  // Google AI used by the existing AI Visa teammate module.
  // Supply the key with --dart-define=GOOGLE_AI_API_KEY=... . It is kept out
  // of source control because, unlike the Supabase anon key, it is billable.
  static const String googleAiApiKey = String.fromEnvironment(
    'GOOGLE_AI_API_KEY',
  );
  static const String googleAiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String googleAiModel = 'gemini-3.5-flash';
  static const String googleAiEndpoint =
      '$googleAiBaseUrl/models/$googleAiModel:generateContent';

  static void validateSupabase() {
    if (!supabaseUrl.startsWith('https://') || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Check the Supabase URL and anon key in lib/config/app_config.dart.',
      );
    }
  }

  static bool isPasswordResetLink(Uri uri) {
    final configured = Uri.parse(passwordResetRedirectUrl);
    return uri.scheme == configured.scheme && uri.host == configured.host;
  }
}
