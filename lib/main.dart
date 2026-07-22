import 'package:flutter/material.dart';

import 'core/supabase_client.dart';
import 'screens/auth/login_screen.dart';
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
      title: 'Tourism & Immigration System',
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

      // Start with login screen
      home: const LoginScreen(),

      // Define routes for navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/visa': (context) => const VisaApplicationScreen(),
      },
    );
  }
}