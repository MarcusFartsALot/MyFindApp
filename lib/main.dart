import 'dart:async';
import 'M300/services/notification_popup_observer.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'core/supabase_client.dart';
import 'M400/screens/auth/login_screen.dart';
import 'M400/screens/auth/reset_password_screen.dart';
import 'M400/screens/router/session_gate.dart';
import 'AI VISA/screens/visa_application_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const MyFindApp());
}

class MyFindApp extends StatefulWidget {
  const MyFindApp({super.key});

  @override
  State<MyFindApp> createState() => _MyFindAppState();
}

class _MyFindAppState extends State<MyFindApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;
  bool _recoveryRouteIsOpen = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen(
      _handleAuthState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase authentication callback failed: $error');
      },
    );
  }

  void _handleAuthState(AuthState state) {
    if (state.event != AuthChangeEvent.passwordRecovery ||
        state.session == null ||
        _recoveryRouteIsOpen) {
      return;
    }

    _recoveryRouteIsOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _recoveryRouteIsOpen = false;
        return;
      }

      unawaited(_showPasswordRecovery(navigator));
    });
  }

  Future<void> _showPasswordRecovery(NavigatorState navigator) async {
    await navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/reset-password'),
        builder: (_) => const ResetPasswordScreen(),
      ),
      (_) => false,
    );
    _recoveryRouteIsOpen = false;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [NotificationPopupObserver.instance],
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
