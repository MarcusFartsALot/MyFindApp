import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_find/M400/models/profile_model.dart';
import 'package:my_find/M400/services/auth_service.dart';
import '../auth/about_screen.dart';
import 'role_router.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSubscription;
  Future<ProfileModel>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
    _authSubscription = _authService.authStateChanges.listen(_handleAuthState);
  }

  void _handleAuthState(AuthState state) {
    if (!mounted) return;
    setState(() {
      _profileFuture = state.session?.user == null
          ? null
          : _authService.fetchProfile(state.session!.user.id);
    });
  }

  void _loadCurrentProfile() {
    final user = _authService.currentUser;
    _profileFuture = user == null ? null : _authService.fetchProfile(user.id);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authService.currentSession == null || _profileFuture == null) {
      return const AboutScreen();
    }

    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error?.toString() ??
                          'Your account profile could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _authService.signOut,
                      child: const Text('Return to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return RoleRouter(profile: snapshot.data!);
      },
    );
  }
}
