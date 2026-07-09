import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'AI VISA/screens/visa_application_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (Replace with your actual URL and Anon Key)
  await Supabase.initialize(
    url: 'https://kfvhnpkkwxipschhlouk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtmdmhucGtrd3hpcHNjaGhsb3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxMzY4NzksImV4cCI6MjA5ODcxMjg3OX0.4IX5V5CvzClsiM4vuafW8NAwBVE1YhGDdmpeo1eaIWs',
  );

  runApp(const MyFindApp());
}

class MyFindApp extends StatelessWidget {
  const MyFindApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyFind Visa System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Colors.blue),
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
      // Since we assume the user is already logged in, we go straight to the Visa screen
      home: const VisaApplicationScreen(),
    );
  }
}