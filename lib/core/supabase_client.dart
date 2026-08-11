import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> initialize() async {
    AppConfig.validateSupabase();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
