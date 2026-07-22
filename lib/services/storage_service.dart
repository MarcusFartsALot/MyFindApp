import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/exceptions/app_exceptions.dart';

class StorageService {
  static const _bucket = 'passport-documents';
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String> uploadPassportImage({
    required String userId,
    required File file,
    required String side, // 'front' or 'back'
  }) async {
    try {
      final ext = file.path.split('.').last;
      final path = '$userId/passport_$side.$ext';
      await _client.storage.from(_bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return path; // store the storage path; generate signed URLs on read
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  /// Passport photos are sensitive, so the bucket is private. Use
  /// this to get a short-lived URL whenever an officer/admin needs
  /// to actually view a document.
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, expiresInSeconds);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }
}
