import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/supabase_client.dart';

/// Exact-file comparison against Storage's server-generated standard-upload
/// checksum. This is not facial recognition or a perceptual image comparison.
class DocumentDuplicateService {
  DocumentDuplicateService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;
  static const duplicateMessage =
      'This identity document image is already used by another registration. '
      'Please use your own MyKad or passport image.';

  static Future<String> fingerprint(File image) async {
    if (!await image.exists()) {
      throw AppException(
        'The selected image is no longer available. Choose it again.',
      );
    }
    if (await image.length() > AppConfig.maximumDocumentBytes) {
      throw AppException('The document image must be smaller than 10 MB.');
    }
    return (await md5.bind(image.openRead()).first).toString();
  }

  Future<void> ensureAvailable(File image) async {
    final hash = await fingerprint(image);
    try {
      final available = await _client.rpc(
        'module400_registration_document_available',
        params: {'p_fingerprint': hash},
      );
      if (available == false) throw AppException(duplicateMessage);
      if (available != true) {
        throw AppException(
          'Document uniqueness could not be checked. Please try again.',
        );
      }
    } on AppException {
      rethrow;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
