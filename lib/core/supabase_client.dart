import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://kfvhnpkkwxipschhlouk.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtmdmhucGtrd3hpcHNjaGhsb3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxMzY4NzksImV4cCI6MjA5ODcxMjg3OX0.4IX5V5CvzClsiM4vuafW8NAwBVE1YhGDdmpeo1eaIWs',
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
