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
      return AppException(
        _mapAuthMessage(error),
        code: error.statusCode?.toString(),
      );
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
      return 'Invalid email or password. If your application was just '
          'approved, use your IC or passport number as the first password.';
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
    const safeDatabaseMessages = [
      'Email is already registered.',
      'IC number is already registered.',
      'Passport number is already registered.',
      'Phone number is required.',
      'Nationality is required.',
      'Passport expiry date must be in the future.',
      'Passport issue date must be before its expiry date.',
      'Passport issuing country is required.',
    ];
    for (final message in safeDatabaseMessages) {
      if (e.message.contains(message)) return message;
    }
    if (e.code == 'PGRST202') {
      return 'The registration service is not configured correctly. '
          'Please contact support.';
    }
    if (e.code == '23505') {
      // unique_violation
      if (e.message.contains('email')) {
        return 'This email is already registered.';
      }
      if (e.message.contains('passport_number')) {
        return 'This passport number is already registered.';
      }
      if (e.message.contains('ic_number')) {
        return 'This IC number is already registered.';
      }
      return 'This record already exists.';
    }
    if (e.code == '23514') {
      return 'Some of the information provided is invalid.';
    }
    if (e.code == '42501') {
      return 'You are not authorized to complete this request.';
    }
    return 'Could not complete the request. Please try again.';
  }

  static String _mapStorageMessage(StorageException e) {
    final message = e.message.toLowerCase();
    if (e.statusCode == '413') return 'The file is too large to upload.';
    if (message.contains('bucket not found')) {
      return 'Document storage is not configured. '
          'Ask an administrator to create the registration-documents bucket.';
    }
    if (e.statusCode == '404') {
      return 'The selected document could not be uploaded. '
          'Please choose or take the photo again.';
    }
    return 'Document upload failed. Please try again.';
  }
}
