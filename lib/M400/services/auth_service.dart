import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/supabase_client.dart';
import '../models/profile_model.dart';
import 'recovery_safe_session_storage.dart';

class AuthService {
  AuthService({
    SupabaseClient? client,
    RecoverySafeSessionStorage? sessionStorage,
  }) : _client = client ?? SupabaseConfig.client,
       _sessionStorage =
           sessionStorage ??
           (client == null ? SupabaseConfig.sessionStorage : null);

  final SupabaseClient _client;
  final RecoverySafeSessionStorage? _sessionStorage;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  bool get hasTrustedSession =>
      _sessionStorage?.isTrusted(currentSession) ?? false;

  Future<ProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw AppException('Login failed. Please try again.');
      }

      try {
        final profile = await fetchProfile(user.id);
        if (response.session == null ||
            RecoverySafeSessionStorage.sessionId(response.session) !=
                RecoverySafeSessionStorage.sessionId(currentSession)) {
          throw AppException(
            'Your login session changed. Please sign in again.',
          );
        }
        if ((profile.isCitizen || profile.isTourist) && profile.isApproved) {
          await _sessionStorage?.admitPasswordLogin(response.session!);
        }
        return profile;
      } catch (_) {
        await _safeSignOut();
        rethrow;
      }
    } on AppException {
      rethrow;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  Future<ProfileModel> fetchProfile(String authId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('auth_id', authId)
          .single();
      final role = profile['role'] as String?;
      final roleTable = switch (role) {
        'admin' => null,
        'citizen' => 'citizens',
        'tourist' => 'tourists',
        // Kept for compatibility with the existing officer dashboard.
        'officer' => null,
        _ => throw AppException('This account has an unsupported role.'),
      };

      Map<String, dynamic>? roleDetails;
      if (roleTable != null) {
        try {
          roleDetails = await _client
              .from(roleTable)
              .select()
              .eq('profile_id', profile['id'])
              .single();
        } on PostgrestException catch (error) {
          if (error.code == 'PGRST116') {
            throw AppException(
              'Your $role account details are incomplete. Please contact support.',
            );
          }
          rethrow;
        }
      }

      final result = ProfileModel.fromRecords(profile, roleDetails);
      return result;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST116') {
        throw AppException(
          'Your account profile is unavailable. Please contact support.',
        );
      }
      throw ExceptionMapper.map(error);
    } catch (error) {
      if (error is AppException) rethrow;
      throw ExceptionMapper.map(error);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      // Anonymous users receive only an eligibility result, never profile data.
      // Do not read profiles directly or put a service-role key in the app.
      final eligibility = await _client.rpc(
        'module400_password_reset_eligibility',
        params: {'p_email': normalizedEmail},
      );
      switch (eligibility) {
        case 'eligible':
          break;
        case 'not_registered':
          throw AppException(
            'Email not registered in system.',
            code: 'reset_email_not_registered',
          );
        case 'admin_portal':
          throw AppException(
            'Administrator accounts must reset their password in the Admin Portal.',
            code: 'reset_admin_portal_required',
          );
        case 'not_active':
          throw AppException(
            'This email has a registration but no active login account. '
            'Wait for administrator approval or contact support.',
            code: 'reset_account_not_active',
          );
        default:
          throw AppException('Could not verify this email. Please try again.');
      }
      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: AppConfig.passwordResetRedirectUrl,
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw AppException(
          'Password reset email checking is not configured yet. Please contact support.',
          code: 'reset_email_check_not_configured',
        );
      }
      throw AppException('Could not verify this email. Please try again.');
    } on AuthException catch (error) {
      final isEmailLimit =
          error.statusCode?.toString() == '429' ||
          error.message.toLowerCase().contains('email rate limit');
      if (isEmailLimit) {
        throw AppException(
          'The reset-email service has reached its hourly sending limit. '
          'Please wait up to one hour before trying again.',
          code: 'reset_email_rate_limit',
        );
      }
      throw ExceptionMapper.map(error);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      if (_client.auth.currentSession == null) {
        throw AppException(
          'This password reset link is invalid or has expired. Request a new link.',
        );
      }
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AppException {
      rethrow;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  Future<void> signOut() async {
    try {
      try {
        await _sessionStorage?.removePersistedSession();
      } finally {
        await _client.auth.signOut();
      }
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await signOut();
    } catch (_) {
      // Do not mask the original authentication/profile error.
    }
  }

  Future<void> completePasswordRecovery(String newPassword) async {
    await updatePassword(newPassword);
    // Clear before any success dialog, even if the screen was disposed while
    // the password request was running.
    await discardRecoverySession();
  }

  Future<void> discardRecoverySession() async {
    try {
      await _sessionStorage?.removePersistedSession();
    } finally {
      try {
        // This SDK clears its in-memory session before contacting the server.
        await _client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // A network failure must not retain a local recovery login.
      }
    }
  }
}
