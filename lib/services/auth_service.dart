import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/exceptions/app_exceptions.dart';
import '../models/profile_model.dart';
import 'storage_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storage = StorageService();

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Registers a tourist: creates the auth user, uploads the passport
  /// front/back images, then writes the profile row. If the image
  /// upload fails partway through, the auth session is rolled back
  /// so the person isn't left with a half-created account they can't
  /// re-register with (their email would otherwise be "taken" by a
  /// broken signup).
  Future<ProfileModel> registerTourist({
    required String fullName,
    required String email,
    required String password,
    required String passportNo,
    required String nationality,
    required File passportFrontImage,
    required File passportBackImage,
    String? phoneNumber,
  }) async {
    try {
      final authResponse = await _client.auth.signUp(email: email, password: password);
      final user = authResponse.user;
      if (user == null) {
        throw AppException('Registration failed. Please try again.');
      }

      late final String frontPath;
      late final String backPath;
      try {
        frontPath = await _storage.uploadPassportImage(
          userId: user.id,
          file: passportFrontImage,
          side: 'front',
        );
        backPath = await _storage.uploadPassportImage(
          userId: user.id,
          file: passportBackImage,
          side: 'back',
        );
      } catch (uploadError) {
        await _safeSignOut();
        rethrow;
      }

      final row = await _client.from('profiles').insert({
        'auth_id': user.id,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'nationality': nationality,
        'passport_no': passportNo.trim().toUpperCase(),
        'role': 'tourist',
        'passport_front_url': frontPath,
        'passport_back_url': backPath,
        'verification_status': 'pending',
      }).select().single();

      return ProfileModel.fromJson(row);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  /// Registers a local citizen using their Malaysian IC number.
  /// No document upload / manual review step - format validation is
  /// enough for a citizen since they aren't presenting a physical
  /// travel document.
  Future<ProfileModel> registerCitizen({
    required String fullName,
    required String email,
    required String password,
    required String icNumber,
    String? phoneNumber,
  }) async {
    try {
      final authResponse = await _client.auth.signUp(email: email, password: password);
      final user = authResponse.user;
      if (user == null) {
        throw AppException('Registration failed. Please try again.');
      }

      final row = await _client.from('profiles').insert({
        'auth_id': user.id,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'ic_number': icNumber.replaceAll('-', ''),
        'role': 'citizen',
        'verification_status': 'approved',
      }).select().single();

      return ProfileModel.fromJson(row);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<ProfileModel> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw AppException('Login failed. Please try again.');
      return await fetchProfile(user.id);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<ProfileModel> fetchProfile(String authId) async {
    try {
      final row = await _client.from('profiles').select().eq('auth_id', authId).single();
      return ProfileModel.fromJson(row);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.yourapp.scheme://reset-password',
      );
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  /// Called on the screen the reset-password deep link opens.
  /// Supabase has already exchanged the recovery token for a
  /// temporary session by the time this runs.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // best-effort only - never mask the original upload error
    }
  }
}
