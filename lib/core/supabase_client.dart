import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../M400/services/recovery_safe_session_storage.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static final sessionStorage = RecoverySafeSessionStorage(
    backingStore: SharedPreferencesLocalStorage(
      persistSessionKey:
          'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token',
    ),
  );

  static Future<void> initialize() async {
    AppConfig.validateSupabase();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
        localStorage: sessionStorage,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
