import 'package:supabase_flutter/supabase_flutter.dart';

/// A single, user-friendly exception type. Every service in this app
/// catches raw Supabase/network errors and rethrows this instead, so
/// UI code never has to know about AuthException, PostgrestException,
/// StorageException, etc.
class AppException implements Exception {
  final String message;
  final String? code;
  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class ExceptionMapper {
  ExceptionMapper._();

  static AppException map(Object error) {
    if (error is AuthException) {
      return AppException(_mapAuthMessage(error), code: error.statusCode?.toString());
    }
    if (error is PostgrestException) {
      return AppException(_mapPostgrestMessage(error), code: error.code);
    }
    if (error is StorageException) {
      return AppException(_mapStorageMessage(error), code: error.statusCode);
    }
    return AppException('Something went wrong. Please try again.');
  }

  static String _mapAuthMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('password')) {
      return 'Password does not meet the required security rules.';
    }
    return e.message;
  }

  static String _mapPostgrestMessage(PostgrestException e) {
    if (e.code == '23505') {
      // unique_violation
      if (e.message.contains('email')) return 'This email is already registered.';
      if (e.message.contains('passport_no')) return 'This passport number is already registered.';
      if (e.message.contains('ic_number')) return 'This IC number is already registered.';
      return 'This record already exists.';
    }
    if (e.code == '23514') {
      return 'Some of the information provided is invalid.';
    }
    return 'Could not complete the request. Please try again.';
  }

  static String _mapStorageMessage(StorageException e) {
    if (e.statusCode == '413') return 'The file is too large to upload.';
    if (e.statusCode == '404') return 'Uploaded file could not be found.';
    return 'Document upload failed. Please try again.';
  }
}
