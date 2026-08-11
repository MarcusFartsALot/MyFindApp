import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../models/profile_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/reset_password_screen.dart';
import 'role_router.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final AuthService _authService = AuthService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  Future<ProfileModel>? _profileFuture;
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _isPasswordRecovery = _requiresPasswordSetup(_authService.currentUser);
    _loadCurrentProfile();
    _authSubscription = _authService.authStateChanges.listen(_handleAuthState);
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    unawaited(_loadInitialLink());
  }

  void _handleAuthState(AuthState state) {
    if (!mounted) return;
    setState(() {
      if (state.event == AuthChangeEvent.passwordRecovery ||
          _requiresPasswordSetup(state.session?.user)) {
        _isPasswordRecovery = true;
      } else if (state.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
      }
      _profileFuture = state.session?.user == null
          ? null
          : _authService.fetchProfile(state.session!.user.id);
    });
  }

  bool _requiresPasswordSetup(User? user) =>
      user?.userMetadata?['password_setup_required'] == true;

  void _handleIncomingLink(Uri uri) {
    if (!mounted) return;
    if (AppConfig.isPasswordResetLink(uri)) {
      setState(() => _isPasswordRecovery = true);
    }
  }

  Future<void> _loadInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingLink(uri);
    } catch (_) {
      // Supabase will surface invalid/expired auth links through its auth state.
    }
  }

  void _loadCurrentProfile() {
    final user = _authService.currentUser;
    _profileFuture = user == null ? null : _authService.fetchProfile(user.id);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecovery) return const ResetPasswordScreen();
    if (_authService.currentSession == null || _profileFuture == null) {
      return const LoginScreen();
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
