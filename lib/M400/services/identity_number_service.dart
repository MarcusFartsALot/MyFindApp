import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/supabase_client.dart';
import '../../core/validators/validators.dart';
import 'document_ocr_service.dart';

class IdentityNumberService {
  IdentityNumberService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;

  static String duplicateMessage(String role) => role == 'citizen'
      ? 'This IC number is already registered. Please sign in or contact support.'
      : 'This passport number is already registered. Please sign in or contact support.';

  Future<void> ensureAvailable({
    required String role,
    required String number,
  }) async {
    if (role != 'citizen' && role != 'tourist') {
      throw AppException('Please select Citizen or Tourist.');
    }
    final validation = role == 'citizen'
        ? Validators.malaysianIC(number)
        : Validators.passportNumber(number);
    if (validation != null) throw AppException(validation);
    try {
      final result = await _client
          .rpc(
            'module400_registration_identity_available',
            params: {
              'p_role': role,
              'p_identity_number': DocumentOcrService.normalizeIdentityNumber(
                number,
                requestedRole: role,
              ),
            },
          )
          .timeout(const Duration(seconds: 15));
      if (result == false) {
        throw AppException(
          duplicateMessage(role),
          code: 'identity_already_registered',
        );
      }
      if (result != true) {
        throw AppException(
          'Could not check this identity number. Please try again.',
        );
      }
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') {
        throw AppException(
          'Identity-number checking is not configured yet. Please contact the administrator.',
          code: 'identity_check_not_configured',
        );
      }
      throw AppException(
        'Could not check this identity number. Please try again.',
      );
    } catch (_) {
      throw AppException(
        'Could not check this identity number. Check your connection and try again.',
      );
    }
  }
}
