import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:my_find/M500/models/visa_submission_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisaSubmissionService {
  final SupabaseClient _supabase;

  VisaSubmissionService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  bool hasPendingSubmission(List<VisaSubmission> submissions) {
    return submissions.any(
      (submission) => submission.status == SubmissionStatus.pending,
    );
  }

  bool hasBlockingApprovedVisa({
    required List<VisaSubmission> submissions,
    required Set<String> completedSevSubmissionIds,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final submission in submissions) {
      if (submission.status != SubmissionStatus.approved) {
        continue;
      }

      final expiry = submission.visaExpiryDate;

      if (expiry == null) {
        return true;
      }

      final expiryDate = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      );

      if (expiryDate.isBefore(today)) {
        continue;
      }

      if (submission.visaType == 'SEV' &&
          completedSevSubmissionIds.contains(submission.id)) {
        continue;
      }

      return true;
    }

    return false;
  }

  Future<List<VisaSubmission>> loadSubmissions(String profileId) async {
    final response = await _supabase
        .from('visa_submissions')
        .select()
        .eq('profile_id', profileId)
        .order(
          'submitted_at',
          ascending: false,
        );

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map(VisaSubmission.fromJson).toList();
  }

  Future<Set<String>> loadCompletedSevSubmissionIds(
    List<VisaSubmission> submissions,
  ) async {
    final completedIds = <String>{};

    for (final submission in submissions) {
      if (submission.status != SubmissionStatus.approved ||
          submission.visaType != 'SEV') {
        continue;
      }

      if (await _hasCompletedTravel(submission.id)) {
        completedIds.add(submission.id);
      }
    }

    return completedIds;
  }

  Future<void> cancelPendingSubmission({
    required VisaSubmission submission,
    required String profileId,
  }) async {
    final response = await _supabase
        .from('visa_submissions')
        .update({
          'status': 'cancelled',
        })
        .eq(
          'id',
          submission.id,
        )
        .eq(
          'profile_id',
          profileId,
        )
        .eq(
          'status',
          'pending',
        )
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'The pending application could not be cancelled.',
      );
    }

    await _logVisaActivity(
      userId: profileId,
      title: 'Visa Submission Cancelled',
      message:
          'Your visa submission (${submission.referenceId}) was cancelled.',
    );
  }

  Future<String> submitVisa({
    required String profileId,
    required String referenceId,
    required String transactionId,
    required String fullName,
    required String passportNumber,
    required String nationality,
    required String purposeOfVisit,
    required String arrivalDate,
    required String departureDate,
    required String visaType,
    required Uint8List pdfBytes,
    required String? pdfFileName,
  }) async {
    final applicationId = await _findApplicationId(
      referenceId: referenceId,
      transactionId: transactionId,
    );

    await _verifyApplication(
      applicationId: applicationId,
      passportNumber: passportNumber,
      arrivalDate: arrivalDate,
      departureDate: departureDate,
    );

    await _verifyApplicationOwnership(
      applicationId: applicationId,
      profileId: profileId,
    );

    await _checkVisaEligibility(
      applicationId: applicationId,
      profileId: profileId,
    );

    if (visaType != 'SEV' && visaType != 'MEV') {
      throw Exception(
        'Invalid visa type. Please select SEV or MEV.',
      );
    }

    final storagePath =
        'visa_submissions/'
        '$profileId/'
        '${DateTime.now().millisecondsSinceEpoch}.pdf';

    String? uploadedStoragePath;

    try {
      await _supabase.storage.from('visa-documents').uploadBinary(
            storagePath,
            pdfBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      uploadedStoragePath = storagePath;

      final pdfUrl = _supabase.storage
          .from('visa-documents')
          .getPublicUrl(storagePath);

      await _supabase.from('visa_submissions').insert({
        'profile_id': profileId,
        'application_id': applicationId,
        'reference_id': referenceId.trim().toUpperCase(),
        'full_name': fullName.trim(),
        'passport_number': passportNumber.trim().toUpperCase(),
        'nationality': nationality.trim(),
        'purpose_of_visit': purposeOfVisit.trim(),
        'arrival_date': arrivalDate.trim(),
        'departure_date': departureDate.trim(),
        'visa_type': visaType,
        'pdf_url': pdfUrl,
        'pdf_file_name': pdfFileName?.trim(),
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      final submittedReference = referenceId.trim().toUpperCase();

      await _logVisaActivity(
        userId: profileId,
        title: 'Visa Submission Submitted',
        message:
            'Your visa submission ($submittedReference) was sent for admin approval.',
      );

      uploadedStoragePath = null;

      return submittedReference;
    } catch (_) {
      if (uploadedStoragePath != null) {
        try {
          await _supabase.storage.from('visa-documents').remove([
            uploadedStoragePath,
          ]);
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<bool> _hasCompletedTravel(String submissionId) async {
    final rows = await _supabase
        .from('visa_travel_records')
        .select('actual_departure_at')
        .eq('submission_id', submissionId)
        .order(
          'actual_entry_at',
          ascending: false,
        )
        .limit(1);

    final travelRows = List<Map<String, dynamic>>.from(rows);

    if (travelRows.isEmpty) {
      return false;
    }

    final departure = travelRows.first['actual_departure_at']
        ?.toString()
        .trim();

    return departure != null && departure.isNotEmpty;
  }

  Future<String> _findApplicationId({
    required String referenceId,
    required String transactionId,
  }) async {
    final reference = referenceId.trim().toUpperCase();
    final transaction = transactionId.trim();

    if (reference.isEmpty) {
      throw Exception(
        'Reference ID could not be detected from the PDF.',
      );
    }

    if (transaction.isEmpty) {
      throw Exception(
        'Transaction ID could not be detected from the PDF.',
      );
    }

    if (reference.length < 8) {
      throw Exception(
        'Invalid Reference ID.',
      );
    }

    final referencePrefix = reference.substring(0, 8);

    final paymentRows = await _supabase
        .from('payment_transactions')
        .select(
          'application_id, stripe_transaction_id',
        )
        .eq(
          'stripe_transaction_id',
          transaction,
        );

    final payments = List<Map<String, dynamic>>.from(paymentRows);

    if (payments.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_FOUND: '
        'No application was found for the supplied Transaction ID.',
      );
    }

    final applicationIds = <String>{};

    for (final payment in payments) {
      final applicationId = payment['application_id']?.toString().trim();

      if (applicationId != null && applicationId.isNotEmpty) {
        applicationIds.add(applicationId);
      }
    }

    if (applicationIds.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_FOUND: '
        'The transaction is not linked to a visa application.',
      );
    }

    final matchingApplicationIds = <String>[];

    for (final applicationId in applicationIds) {
      if (applicationId.length < 8) {
        continue;
      }

      final prefix = applicationId.substring(0, 8).toUpperCase();

      if (prefix == referencePrefix) {
        matchingApplicationIds.add(applicationId);
      }
    }

    if (matchingApplicationIds.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_FOUND: '
        'Reference ID does not match the transaction application.',
      );
    }

    final uniqueMatches = matchingApplicationIds.toSet();

    if (uniqueMatches.length > 1) {
      throw Exception(
        'APPLICATION_AMBIGUOUS: '
        'Multiple applications match the supplied identifiers.',
      );
    }

    return uniqueMatches.first;
  }

  Future<void> _verifyApplication({
    required String applicationId,
    required String passportNumber,
    required String arrivalDate,
    required String departureDate,
  }) async {
    final applicationRows = await _supabase
        .from('visa_applications')
        .select(
          '''
              id,
              applicant_information(
                passport_number
              ),
              travel_information(
                arrival_date,
                departure_date
              )
              ''',
        )
        .eq(
          'id',
          applicationId,
        );

    final applications = List<Map<String, dynamic>>.from(applicationRows);

    if (applications.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_FOUND: '
        'Visa application does not exist.',
      );
    }

    if (applications.length > 1) {
      throw Exception(
        'APPLICATION_AMBIGUOUS: '
        'Multiple application records were returned.',
      );
    }

    final application = applications.first;

    final applicant = _extractRelatedMap(
      application['applicant_information'],
    );

    final databasePassport =
        applicant?['passport_number']?.toString().trim().toUpperCase() ?? '';

    final scannedPassport = passportNumber.trim().toUpperCase();

    if (databasePassport.isEmpty) {
      throw Exception(
        'The application does not contain a passport number.',
      );
    }

    if (scannedPassport.isEmpty) {
      throw Exception(
        'Passport number could not be detected from the PDF.',
      );
    }

    if (databasePassport != scannedPassport) {
      throw Exception(
        'PASSPORT_MISMATCH: '
        'The passport number in the PDF does not match the application.',
      );
    }

    final travel = _extractRelatedMap(
      application['travel_information'],
    );

    final databaseArrival = _normalizeDatabaseDate(
      travel?['arrival_date'],
    );

    final databaseDeparture = _normalizeDatabaseDate(
      travel?['departure_date'],
    );

    final scannedArrival = arrivalDate.trim();
    final scannedDeparture = departureDate.trim();

    if (databaseArrival.isEmpty) {
      throw Exception(
        'The application does not contain an arrival date.',
      );
    }

    if (databaseDeparture.isEmpty) {
      throw Exception(
        'The application does not contain a departure date.',
      );
    }

    if (scannedArrival.isEmpty) {
      throw Exception(
        'Arrival date could not be detected from the PDF.',
      );
    }

    if (scannedDeparture.isEmpty) {
      throw Exception(
        'Departure date could not be detected from the PDF.',
      );
    }

    if (databaseArrival != scannedArrival) {
      throw Exception(
        'DATE_MISMATCH: '
        'The arrival date in the PDF does not match the application.',
      );
    }

    if (databaseDeparture != scannedDeparture) {
      throw Exception(
        'DATE_MISMATCH: '
        'The departure date in the PDF does not match the application.',
      );
    }

    final arrival = DateTime.tryParse(scannedArrival);
    final departure = DateTime.tryParse(scannedDeparture);

    if (arrival == null || departure == null) {
      throw Exception(
        'INVALID_TRAVEL_DATES: Invalid travel dates.',
      );
    }

    if (departure.isBefore(arrival)) {
      throw Exception(
        'INVALID_TRAVEL_DATES: '
        'Departure date cannot be before arrival date.',
      );
    }
  }

  Future<void> _verifyApplicationOwnership({
    required String applicationId,
    required String profileId,
  }) async {
    final rows = await _supabase
        .from('visa_applications')
        .select('id, user_id')
        .eq(
          'id',
          applicationId,
        );

    final applications = List<Map<String, dynamic>>.from(rows);

    if (applications.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_FOUND: '
        'Visa application does not exist.',
      );
    }

    if (applications.length > 1) {
      throw Exception(
        'APPLICATION_AMBIGUOUS: '
        'Multiple application records were returned.',
      );
    }

    final application = applications.first;
    final applicationUserId = application['user_id']?.toString().trim();
    final currentProfileId = profileId.trim();

    if (applicationUserId == null || applicationUserId.isEmpty) {
      throw Exception(
        'APPLICATION_NOT_OWNED: '
        'The application has no valid owner.',
      );
    }

    if (applicationUserId != currentProfileId) {
      throw Exception(
        'APPLICATION_NOT_OWNED: '
        'This visa application does not belong to the current account.',
      );
    }
  }

  Future<void> _checkVisaEligibility({
    required String applicationId,
    required String profileId,
  }) async {
    final rows = await _supabase
        .from('visa_submissions')
        .select(
          '''
              id,
              application_id,
              status,
              visa_type,
              visa_expiry_date
              ''',
        )
        .eq(
          'profile_id',
          profileId,
        )
        .order(
          'submitted_at',
          ascending: false,
        );

    final submissions = List<Map<String, dynamic>>.from(rows);

    if (submissions.isEmpty) {
      return;
    }

    final currentApplicationId = applicationId.trim();

    for (final submission in submissions) {
      final submissionApplicationId =
          submission['application_id']?.toString().trim() ?? '';
      final status = submission['status']?.toString().trim().toLowerCase() ?? '';

      if (submissionApplicationId == currentApplicationId &&
          status == 'approved') {
        throw Exception(
          'APPLICATION_ALREADY_USED: '
          'This AI visa application has already been used for an approved visa. '
          'Please complete a new AI visa application before applying again.',
        );
      }
    }

    for (final submission in submissions) {
      final status = submission['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'pending') {
        throw Exception(
          'VISA_NOT_ELIGIBLE: '
          'You already have a pending visa application.',
        );
      }
    }

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    for (final submission in submissions) {
      final status = submission['status']?.toString().trim().toLowerCase() ?? '';

      if (status != 'approved') {
        continue;
      }

      final visaType =
          submission['visa_type']?.toString().trim().toUpperCase() ?? '';
      final expiryString = submission['visa_expiry_date']?.toString().trim();
      final expiry = expiryString == null || expiryString.isEmpty
          ? null
          : DateTime.tryParse(expiryString);

      if (expiry == null) {
        throw Exception(
          'VISA_NOT_ELIGIBLE: '
          'The existing approved visa has no valid expiry date.',
        );
      }

      final expiryDate = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
      );

      if (expiryDate.isBefore(today)) {
        continue;
      }

      if (visaType == 'SEV') {
        final submissionId = submission['id']?.toString().trim() ?? '';

        if (submissionId.isNotEmpty &&
            await _hasCompletedTravel(submissionId)) {
          continue;
        }
      }

      throw Exception(
        'VISA_NOT_ELIGIBLE: '
        'You already have a valid approved visa.',
      );
    }
  }

  Map<String, dynamic>? _extractRelatedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;

      if (first is Map<String, dynamic>) {
        return first;
      }
    }

    return null;
  }

  String _normalizeDatabaseDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final stringValue = value.toString().trim();

    if (stringValue.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(stringValue);

    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
    }

    return stringValue;
  }

  Future<void> _logVisaActivity({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': 'Activity',
        'is_read': false,
      });
    } catch (e) {
      debugPrint(
        'Unable to record visa activity: $e',
      );
    }
  }
}
