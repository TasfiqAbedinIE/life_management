import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppBootstrap {
  AppBootstrap._();

  static const _supabaseUrlKey = 'bootstrap_supabase_url';
  static const _supabaseAnonKey = 'bootstrap_supabase_anon_key';
  static bool _initialized = false;

  static Future<void> ensureInitialized({bool allowAssetLoad = true}) async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    var url = prefs.getString(_supabaseUrlKey);
    var anonKey = prefs.getString(_supabaseAnonKey);

    if ((url == null || anonKey == null) && allowAssetLoad) {
      await dotenv.load(fileName: '.env');
      url = dotenv.env['SUPABASE_URL'];
      anonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (url != null && anonKey != null) {
        await prefs.setString(_supabaseUrlKey, url);
        await prefs.setString(_supabaseAnonKey, anonKey);
      }
    }

    if (url == null || anonKey == null) {
      throw StateError('Supabase configuration is unavailable.');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);

    _initialized = true;
  }
}
