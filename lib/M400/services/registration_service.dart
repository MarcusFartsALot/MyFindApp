import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/supabase_client.dart';
import 'document_ocr_service.dart';
import 'storage_service.dart';

class RegistrationService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();

  Future<String> submitApplication({
    required String fullName,
    required String email,
    required String requestedRole,
    required String identityNumber,
    required File documentImage,
    required String extractedText,
    File? documentBackImage,
    DateTime? passportIssueDate,
    DateTime? passportExpiryDate,
    String? passportIssuingCountry,
    String? countryOfResidence,
    String? phoneNumber,
    String? nationality,
  }) async {
    if (requestedRole != 'citizen' && requestedRole != 'tourist') {
      throw AppException('Please select Citizen or Tourist.');
    }
    if (phoneNumber?.trim().isEmpty ?? true) {
      throw AppException('Phone number is required.');
    }
    if (nationality?.trim().isEmpty ?? true) {
      throw AppException('Nationality is required.');
    }
    if (extractedText.replaceAll(RegExp(r'\s'), '').length < 20) {
      throw AppException(
        'The picture is not clear enough. Please take a photo again.',
      );
    }
    if (requestedRole == 'citizen' && documentBackImage == null) {
      throw AppException('Please add a photo of the back of your MyKad.');
    }
    if (!DocumentOcrService.identityNumberMatches(
      extractedText: extractedText,
      identityNumber: identityNumber,
      requestedRole: requestedRole,
    )) {
      throw AppException(
        DocumentOcrService.identityMismatchMessage(requestedRole),
      );
    }
    if (requestedRole == 'tourist') {
      if (passportExpiryDate == null ||
          !passportExpiryDate.isAfter(DateTime.now())) {
        throw AppException('Enter a valid future passport expiry date.');
      }
      if (passportIssueDate != null &&
          passportIssueDate.isAfter(passportExpiryDate)) {
        throw AppException(
          'Passport issue date must be before its expiry date.',
        );
      }
      if (passportIssuingCountry?.trim().isEmpty ?? true) {
        throw AppException('Enter the passport issuing country.');
      }
    }

    final profileId = _uuid.v4();
    final frontObjectName = requestedRole == 'citizen'
        ? 'mykad_front'
        : 'passport_front';
    String? documentPath;
    String? documentBackPath;

    try {
      documentPath = await _storage.uploadRegistrationDocument(
        profileId: profileId,
        requestedRole: requestedRole,
        objectName: frontObjectName,
        file: documentImage,
      );
      if (documentBackImage != null) {
        documentBackPath = await _storage.uploadRegistrationDocument(
          profileId: profileId,
          requestedRole: requestedRole,
          objectName: requestedRole == 'citizen'
              ? 'mykad_back'
              : 'passport_back',
          file: documentBackImage,
        );
      }

      await _client.rpc(
        'submit_registration_application',
        params: {
          'p_profile_id': profileId,
          'p_full_name': fullName.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_phone_number': phoneNumber!.trim(),
          'p_nationality': nationality!.trim(),
          'p_role': requestedRole,
          'p_identity_number': identityNumber.trim().toUpperCase(),
          'p_front_path': documentPath,
          'p_back_path': documentBackPath,
          'p_passport_issue_date': passportIssueDate == null
              ? null
              : _dateOnly(passportIssueDate),
          'p_passport_expiry_date': passportExpiryDate == null
              ? null
              : _dateOnly(passportExpiryDate),
          'p_passport_issuing_country': _nullIfEmpty(passportIssuingCountry),
          'p_country_of_residence': _nullIfEmpty(countryOfResidence),
        },
      );

      return profileId;
    } on AppException {
      if (documentPath != null) {
        await _storage.removeRegistrationDocument(documentPath);
      }
      if (documentBackPath != null) {
        await _storage.removeRegistrationDocument(documentBackPath);
      }
      rethrow;
    } catch (error) {
      if (documentPath != null) {
        await _storage.removeRegistrationDocument(documentPath);
      }
      if (documentBackPath != null) {
        await _storage.removeRegistrationDocument(documentBackPath);
      }
      throw ExceptionMapper.map(error);
    }
  }

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
