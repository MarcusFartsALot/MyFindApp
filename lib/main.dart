import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'core/supabase_client.dart';
import 'M400/screens/auth/login_screen.dart';
import 'M400/screens/router/session_gate.dart';
import 'AI VISA/screens/visa_application_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const MyFindApp());
}

class MyFindApp extends StatelessWidget {
  const MyFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.blue),
          titleTextStyle: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      // Restores valid sessions and handles Supabase password-recovery links.
      home: const SessionGate(),

      // Define routes for navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/visa': (context) => const VisaApplicationScreen(),
      },
    );
  }
}
