import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';
import '../../core/supabase_client.dart';
import '../../core/exceptions/app_exceptions.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String> uploadRegistrationDocument({
    required String profileId,
    required String requestedRole,
    required String objectName,
    required File file,
  }) async {
    try {
      if (!await file.exists()) {
        throw AppException(
          'The selected document is no longer available. '
          'Please choose or take the photo again.',
        );
      }

      final fileSize = await file.length();
      if (fileSize > AppConfig.maximumDocumentBytes) {
        throw AppException('The document image must be smaller than 10 MB.');
      }

      final rawExtension = file.path.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png'}.contains(rawExtension)) {
        throw AppException('Please use a JPG or PNG document image.');
      }
      final extension = rawExtension == 'png'
          ? 'png'
          : rawExtension == 'jpeg'
          ? 'jpeg'
          : 'jpg';
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
      if (requestedRole != 'citizen' && requestedRole != 'tourist') {
        throw AppException('Invalid registration role.');
      }
      final roleFolder = requestedRole == 'citizen' ? 'citizens' : 'tourists';
      final path = '$roleFolder/$profileId/$objectName.$extension';
      await _client.storage
          .from(AppConfig.registrationDocumentsBucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );
      return path;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> removeRegistrationDocument(String path) async {
    try {
      await _client.storage.from(AppConfig.registrationDocumentsBucket).remove([
        path,
      ]);
    } catch (_) {
      // Best-effort cleanup. Anonymous storage policies intentionally do not
      // grant delete access, so production cleanup is handled server-side.
    }
  }
}
