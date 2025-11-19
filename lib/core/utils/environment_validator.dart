class EnvironmentValidator {
  static void validateSupabaseConfig(String url, String anonKey) {
    if (url.isEmpty || anonKey.isEmpty) {
      throw const FormatException(
        'Supabase configuration is incomplete. '
        'Please check your environment variables.',
      );
    }

    if (!url.startsWith('https://')) {
      throw const FormatException(
        'Supabase URL must start with https://',
      );
    }

    if (!url.contains('.supabase.co')) {
      throw const FormatException(
        'Invalid Supabase URL format',
      );
    }

    if (anonKey.length < 20) {
      throw const FormatException(
        'Supabase anon key appears to be invalid',
      );
    }
  }
}