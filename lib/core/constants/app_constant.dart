import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get supabaseUrl {
    final url = dotenv.get('SUPABASE_URL', fallback: '');
    _validateUrl(url);
    return url;
  }

  static String get supabaseAnonKey {
    final key = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
    _validateKey(key);
    return key;
  }

  static const String appName = 'IoT Monitoring';

  static void _validateUrl(String url) {
    if (url.isEmpty) {
      throw Exception('SUPABASE_URL is not set in .env file');
    }
    if (url == 'https://YOUR-PROJECT.supabase.co') {
      throw Exception(
        'Please update SUPABASE_URL in .env file with your actual Supabase URL',
      );
    }
    if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
      throw Exception('Invalid Supabase URL format: $url');
    }
  }

  static void _validateKey(String key) {
    if (key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not set in .env file');
    }
    if (key == 'your-anon-key-here') {
      throw Exception(
        'Please update SUPABASE_ANON_KEY in .env file with your actual Supabase anon key',
      );
    }
    if (key.length < 20) {
      throw Exception('Supabase anon key appears to be invalid');
    }
  }
}

class AppRoutes {
  static const String home = '/';
  static const String history = '/history';
  static const String charts = '/charts';
}
