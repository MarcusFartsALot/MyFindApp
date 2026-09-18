import 'package:flutter/foundation.dart' show debugPrint;
import 'package:my_find/M500/models/visa_travel_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisaTravelService {
  final SupabaseClient _supabase;

  VisaTravelService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // Context
  Future<VisaTravelContext> getTravelContext(String profileId) async {
    final visa = await _getCurrentApprovedVisa(profileId);

    if (visa == null) {
      return const VisaTravelContext(
        visa: null,
        plannedTravel: null,
        records: [],
        state: VisaTravelState.noVisa,
        remainingDays: null,
      );
    }

    final results = await Future.wait([
      getTravelRecords(visa.submissionId),
      getPlannedTravelInformation(visa.applicationId),
    ]);

    final records = results[0] as List<VisaTravelRecord>;
    final plannedTravel = results[1] as PlannedTravelInformation?;
    final state = calculateTravelState(
      visa: visa,
      records: records,
    );

    await _createTemporalNotificationIfNeeded(
      userId: visa.profileId,
      referenceId: visa.referenceId,
      state: state,
    );

    return VisaTravelContext(
      visa: visa,
      plannedTravel: plannedTravel,
      records: records,
      state: state,
      remainingDays: calculateRemainingDays(records),
    );
  }

  // Visa
  Future<VisaTravelVisa?> _getCurrentApprovedVisa(String profileId) async {
    final response = await _supabase
        .from('visa_submissions')
        .select(
      'id, profile_id, application_id, reference_id, visa_type, status, '
          'visa_effective_date, visa_expiry_date, arrival_date, '
          'departure_date, approved_at',
    )
        .eq('profile_id', profileId)
        .eq('status', 'approved')
        .order('approved_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) return null;

    final today = _dateOnly(DateTime.now());
    VisaTravelVisa? historicalVisa;

    for (final row in rows) {
      if (row['visa_effective_date'] == null ||
          row['visa_expiry_date'] == null ||
          row['visa_type'] == null) {
        continue;
      }

      final visa = VisaTravelVisa.fromJson(row);
      final effective = _dateOnly(visa.effectiveDate);
      final expiry = _dateOnly(visa.expiryDate);

      if (today.isBefore(effective)) continue;
      if (!today.isAfter(expiry)) return visa;

      historicalVisa ??= visa;
    }

    return historicalVisa;
  }

  Future<VisaTravelVisa> _getVisaBySubmissionId(
      String submissionId,
      ) async {
    final response = await _supabase
        .from('visa_submissions')
        .select(
      'id, profile_id, application_id, reference_id, visa_type, status, '
          'visa_effective_date, visa_expiry_date, arrival_date, departure_date',
    )
        .eq('id', submissionId)
        .single();

    final row = Map<String, dynamic>.from(response);

    if (row['visa_effective_date'] == null ||
        row['visa_expiry_date'] == null ||
        row['visa_type'] == null) {
      throw Exception(
        'INVALID_VISA_DATA: Visa validity information is incomplete.',
      );
    }

    return VisaTravelVisa.fromJson(row);
  }

  // Planned travel (read only)
  Future<PlannedTravelInformation?> getPlannedTravelInformation(
      String applicationId,
      ) async {
    final response = await _supabase
        .from('travel_information')
        .select(
      'airline, flight_number, intended_destination, '
          'hotel_name, hotel_address, accommodation_type',
    )
        .eq('application_id', applicationId)
        .maybeSingle();

    if (response == null) return null;

    return PlannedTravelInformation.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> _logTravelActivity({
    required String userId,
    required String title,
    required String message,
  }) async {
    if (userId.trim().isEmpty) return;

    try {
      await _supabase
          .from('notifications')
          .insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': 'Activity',
        'is_read': false,
      });
    } catch (_) {
      // Activity logging must never make a valid travel declaration fail.
    }
  }

  Future<void> _createTemporalNotificationIfNeeded({
    required String userId,
    required String referenceId,
    required VisaTravelState state,
  }) async {
    final recipientId = userId.trim();
    final trimmedReferenceId = referenceId.trim();

    if (recipientId.isEmpty) return;

    if (trimmedReferenceId.isEmpty) {
      debugPrint(
        'Unable to record temporal notification: reference ID is empty.',
      );
      return;
    }

    late final String title;
    late final String message;
    late final String type;

    if (state == VisaTravelState.expiringSoon) {
      title = 'Stay Expiring Soon [$trimmedReferenceId]';
      message = 'Your permitted stay is approaching its expiry date. '
          'Please review your travel status.';
      type = 'Warning';
    } else if (state == VisaTravelState.departureNotReported) {
      title = 'Departure Not Reported [$trimmedReferenceId]';
      message = 'Your permitted stay has ended and no departure has been '
          'reported. Please report your departure.';
      type = 'Alert';
    } else {
      return;
    }

    try {
      final existingRows = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', recipientId)
          .eq('title', title)
          .limit(1);

      if (existingRows.isNotEmpty) return;

      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
      });
    } catch (e) {
      debugPrint(
        'Unable to record temporal notification: $e',
      );
    }
  }

  // Records
  Future<List<VisaTravelRecord>> getTravelRecords(
      String submissionId,
      ) async {
    final response = await _supabase
        .from('visa_travel_records')
        .select()
        .eq('submission_id', submissionId)
        .order('actual_entry_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(VisaTravelRecord.fromJson)
        .toList();
  }

  // Arrival
  Future<VisaTravelRecord> reportArrival({
    required String submissionId,
    required DateTime actualEntryAt,
    required String entryMethod,
    required String entryPoint,
    String? entryReference,
    String? plannedEntryMethod,
    String? plannedEntryPoint,
    String? entryChangeReason,
  }) async {
    final visa = await _getVisaBySubmissionId(submissionId);

    _validateVisaForArrival(
      visa: visa,
      actualEntryAt: actualEntryAt,
    );

    final records = await getTravelRecords(submissionId);

    if (records.any((record) => record.isOpen)) {
      throw Exception(
        'TRAVEL_ALREADY_ACTIVE: An arrival is already active.',
      );
    }

    if (visa.isSEV && records.isNotEmpty) {
      throw Exception(
        'SEV_ALREADY_USED: This single-entry visa already has a travel record.',
      );
    }

    final method = _normalizeMethod(entryMethod);
    final point = entryPoint.trim();

    if (point.isEmpty) {
      throw Exception(
        'ENTRY_POINT_REQUIRED: Please provide the actual entry point.',
      );
    }

    final significantChange = hasSignificantTravelChange(
      plannedMethod: plannedEntryMethod,
      actualMethod: method,
      plannedPoint: plannedEntryPoint,
      actualPoint: point,
    );

    final reason = entryChangeReason?.trim() ?? '';

    if (significantChange && reason.isEmpty) {
      throw Exception(
        'CHANGE_REASON_REQUIRED: Please explain the travel information change.',
      );
    }

    final stayUntil = DateTime(
      actualEntryAt.year,
      actualEntryAt.month,
      actualEntryAt.day,
    ).add(const Duration(days: 30));

    final inserted = await _supabase
        .from('visa_travel_records')
        .insert({
      'submission_id': submissionId,
      'actual_entry_at': actualEntryAt.toUtc().toIso8601String(),
      'entry_method': method,
      'entry_point': point,
      'entry_reference': _nullableText(entryReference),
      'entry_change_reason': significantChange ? reason : null,
      'stay_until_date': _formatDate(stayUntil),
    })
        .select()
        .single();

    final record = VisaTravelRecord.fromJson(
      Map<String, dynamic>.from(inserted),
    );

    await _logTravelActivity(
      userId: visa.profileId,
      title: 'Arrival Recorded',
      message:
      'Your arrival at $point was recorded for visa ${visa.referenceId}.',
    );

    return record;
  }

  // Departure
  Future<VisaTravelRecord> reportDeparture({
    required String submissionId,
    required DateTime actualDepartureAt,
    required String departureMethod,
    required String departurePoint,
    String? departureReference,
    String? plannedDepartureMethod,
    String? plannedDeparturePoint,
    String? departureChangeReason,
  }) async {
    final visa = await _getVisaBySubmissionId(submissionId);

    if (visa.status != 'approved') {
      throw Exception(
        'VISA_NOT_APPROVED: Only an approved visa can report departure.',
      );
    }

    final records = await getTravelRecords(submissionId);

    VisaTravelRecord? openRecord;
    for (final record in records) {
      if (record.isOpen) {
        openRecord = record;
        break;
      }
    }

    if (openRecord == null) {
      throw Exception(
        'NO_ACTIVE_TRAVEL: No active arrival record was found.',
      );
    }

    if (actualDepartureAt.isBefore(openRecord.actualEntryAt)) {
      throw Exception(
        'INVALID_DEPARTURE_TIME: Departure cannot be earlier than arrival.',
      );
    }

    if (actualDepartureAt.isAfter(DateTime.now())) {
      throw Exception(
        'FUTURE_DEPARTURE_NOT_ALLOWED: Actual departure time cannot be in the future.',
      );
    }

    final method = _normalizeMethod(departureMethod);
    final point = departurePoint.trim();

    if (point.isEmpty) {
      throw Exception(
        'DEPARTURE_POINT_REQUIRED: Please provide the actual departure point.',
      );
    }

    final significantChange = hasSignificantTravelChange(
      plannedMethod: plannedDepartureMethod,
      actualMethod: method,
      plannedPoint: plannedDeparturePoint,
      actualPoint: point,
    );

    final reason = departureChangeReason?.trim() ?? '';

    if (significantChange && reason.isEmpty) {
      throw Exception(
        'CHANGE_REASON_REQUIRED: Please explain the travel information change.',
      );
    }

    final updated = await _supabase
        .from('visa_travel_records')
        .update({
      'actual_departure_at':
      actualDepartureAt.toUtc().toIso8601String(),
      'departure_method': method,
      'departure_point': point,
      'departure_reference': _nullableText(departureReference),
      'departure_change_reason': significantChange ? reason : null,
    })
        .eq('id', openRecord.id)
        .eq('submission_id', submissionId)
        .isFilter('actual_departure_at', null)
        .select()
        .single();

    final record = VisaTravelRecord.fromJson(
      Map<String, dynamic>.from(updated),
    );

    await _logTravelActivity(
      userId: visa.profileId,
      title: 'Departure Recorded',
      message:
      'Your departure from $point was recorded for visa ${visa.referenceId}.',
    );

    return record;
  }

  // State
  VisaTravelState calculateTravelState({
    required VisaTravelVisa visa,
    required List<VisaTravelRecord> records,
  }) {
    final today = _dateOnly(DateTime.now());
    final expiry = _dateOnly(visa.expiryDate);
    final latest = records.isEmpty ? null : records.first;

    if (latest != null) {
      if (latest.actualDepartureAt != null) {
        if (visa.isSEV) return VisaTravelState.used;
        if (today.isAfter(expiry)) return VisaTravelState.expired;
        return VisaTravelState.departed;
      }

      final stayUntil = _dateOnly(latest.stayUntilDate);

      if (today.isAfter(stayUntil)) {
        return VisaTravelState.departureNotReported;
      }

      final remaining = stayUntil.difference(today).inDays;

      if (remaining <= 10) {
        return VisaTravelState.expiringSoon;
      }

      return VisaTravelState.active;
    }

    if (today.isAfter(expiry)) {
      return VisaTravelState.expired;
    }

    return VisaTravelState.notEntered;
  }

  int? calculateRemainingDays(List<VisaTravelRecord> records) {
    if (records.isEmpty) return null;

    final latest = records.first;
    if (latest.actualDepartureAt != null) return 0;

    final today = _dateOnly(DateTime.now());
    final stayUntil = _dateOnly(latest.stayUntilDate);
    final remaining = stayUntil.difference(today).inDays;

    return remaining < 0 ? 0 : remaining;
  }

  bool hasSignificantTravelChange({
    String? plannedMethod,
    required String actualMethod,
    String? plannedPoint,
    required String actualPoint,
  }) {
    final plannedMethodValue =
        plannedMethod?.trim().toUpperCase() ?? '';
    final actualMethodValue = actualMethod.trim().toUpperCase();
    final plannedPointValue = _normalizeComparisonText(plannedPoint);
    final actualPointValue = _normalizeComparisonText(actualPoint);

    final methodChanged = plannedMethodValue.isNotEmpty &&
        plannedMethodValue != actualMethodValue;

    final pointChanged = plannedPointValue.isNotEmpty &&
        plannedPointValue != actualPointValue;

    return methodChanged || pointChanged;
  }

  void _validateVisaForArrival({
    required VisaTravelVisa visa,
    required DateTime actualEntryAt,
  }) {
    if (visa.status != 'approved') {
      throw Exception(
        'VISA_NOT_APPROVED: Only an approved visa can report arrival.',
      );
    }

    final entryDate = _dateOnly(actualEntryAt);
    final effectiveDate = _dateOnly(visa.effectiveDate);
    final expiryDate = _dateOnly(visa.expiryDate);

    if (entryDate.isBefore(effectiveDate)) {
      throw Exception(
        'ENTRY_BEFORE_VISA_EFFECTIVE: Arrival cannot be before the visa effective date.',
      );
    }

    if (entryDate.isAfter(expiryDate)) {
      throw Exception(
        'VISA_EXPIRED: Arrival cannot be reported after visa expiry.',
      );
    }

    if (actualEntryAt.isAfter(DateTime.now())) {
      throw Exception(
        'FUTURE_ARRIVAL_NOT_ALLOWED: Actual arrival time cannot be in the future.',
      );
    }
  }

  String _normalizeMethod(String value) {
    final method = value.trim().toUpperCase();
    const allowed = {'AIR', 'LAND', 'SEA'};

    if (!allowed.contains(method)) {
      throw Exception(
        'INVALID_TRAVEL_METHOD: Travel method must be AIR, LAND, or SEA.',
      );
    }

    return method;
  }

  String _normalizeComparisonText(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
