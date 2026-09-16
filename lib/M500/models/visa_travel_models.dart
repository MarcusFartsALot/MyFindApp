enum VisaTravelState {
  noVisa,
  notEntered,
  active,
  expiringSoon,
  departureNotReported,
  departed,
  used,
  expired,
}

class VisaTravelRecord {
  final String id;
  final String submissionId;
  final DateTime actualEntryAt;
  final String entryMethod;
  final String entryPoint;
  final String? entryReference;
  final String? entryChangeReason;
  final DateTime stayUntilDate;
  final DateTime? actualDepartureAt;
  final String? departureMethod;
  final String? departurePoint;
  final String? departureReference;
  final String? departureChangeReason;
  final DateTime? updatedAt;

  const VisaTravelRecord({
    required this.id,
    required this.submissionId,
    required this.actualEntryAt,
    required this.entryMethod,
    required this.entryPoint,
    this.entryReference,
    this.entryChangeReason,
    required this.stayUntilDate,
    this.actualDepartureAt,
    this.departureMethod,
    this.departurePoint,
    this.departureReference,
    this.departureChangeReason,
    this.updatedAt,
  });

  factory VisaTravelRecord.fromJson(Map<String, dynamic> json) {
    return VisaTravelRecord(
      id: json['id']?.toString() ?? '',
      submissionId: json['submission_id']?.toString() ?? '',
      actualEntryAt: DateTime.parse(
        json['actual_entry_at'].toString(),
      ).toLocal(),
      entryMethod: json['entry_method']?.toString() ?? '',
      entryPoint: json['entry_point']?.toString() ?? '',
      entryReference: _textOrNull(json['entry_reference']),
      entryChangeReason: _textOrNull(json['entry_change_reason']),
      stayUntilDate: DateTime.parse(
        json['stay_until_date'].toString(),
      ),
      actualDepartureAt: json['actual_departure_at'] == null
          ? null
          : DateTime.parse(
        json['actual_departure_at'].toString(),
      ).toLocal(),
      departureMethod: _textOrNull(json['departure_method']),
      departurePoint: _textOrNull(json['departure_point']),
      departureReference: _textOrNull(json['departure_reference']),
      departureChangeReason: _textOrNull(json['departure_change_reason']),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(
        json['updated_at'].toString(),
      ).toLocal(),
    );
  }

  bool get isOpen => actualDepartureAt == null;
}

class PlannedTravelInformation {
  final String? airline;
  final String? flightNumber;
  final String? intendedDestination;
  final String? hotelName;
  final String? hotelAddress;
  final String? accommodationType;

  const PlannedTravelInformation({
    this.airline,
    this.flightNumber,
    this.intendedDestination,
    this.hotelName,
    this.hotelAddress,
    this.accommodationType,
  });

  factory PlannedTravelInformation.fromJson(Map<String, dynamic> json) {
    return PlannedTravelInformation(
      airline: _textOrNull(json['airline']),
      flightNumber: _textOrNull(json['flight_number']),
      intendedDestination: _textOrNull(json['intended_destination']),
      hotelName: _textOrNull(json['hotel_name']),
      hotelAddress: _textOrNull(json['hotel_address']),
      accommodationType: _textOrNull(json['accommodation_type']),
    );
  }

  bool get hasAirTravelInformation =>
      (airline ?? '').isNotEmpty || (flightNumber ?? '').isNotEmpty;

  String? get inferredMethod => hasAirTravelInformation ? 'AIR' : null;

  String? get transportReference {
    final values = <String>[
      if ((airline ?? '').isNotEmpty) airline!,
      if ((flightNumber ?? '').isNotEmpty) flightNumber!,
    ];
    return values.isEmpty ? null : values.join(' · ');
  }

  bool get hasAnyData =>
      (airline ?? '').isNotEmpty ||
          (flightNumber ?? '').isNotEmpty ||
          (intendedDestination ?? '').isNotEmpty ||
          (hotelName ?? '').isNotEmpty ||
          (hotelAddress ?? '').isNotEmpty ||
          (accommodationType ?? '').isNotEmpty;
}

class VisaTravelVisa {
  final String submissionId;
  final String profileId;
  final String applicationId;
  final String referenceId;
  final String visaType;
  final String status;
  final DateTime effectiveDate;
  final DateTime expiryDate;
  final DateTime? plannedArrivalDate;
  final DateTime? plannedDepartureDate;

  const VisaTravelVisa({
    required this.submissionId,
    required this.profileId,
    required this.applicationId,
    required this.referenceId,
    required this.visaType,
    required this.status,
    required this.effectiveDate,
    required this.expiryDate,
    this.plannedArrivalDate,
    this.plannedDepartureDate,
  });

  factory VisaTravelVisa.fromJson(Map<String, dynamic> json) {
    return VisaTravelVisa(
      submissionId: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      applicationId: json['application_id']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      visaType: json['visa_type']?.toString().toUpperCase() ?? '',
      status: json['status']?.toString().toLowerCase() ?? '',
      effectiveDate: DateTime.parse(
        json['visa_effective_date'].toString(),
      ),
      expiryDate: DateTime.parse(
        json['visa_expiry_date'].toString(),
      ),
      plannedArrivalDate: json['arrival_date'] == null
          ? null
          : DateTime.parse(json['arrival_date'].toString()),
      plannedDepartureDate: json['departure_date'] == null
          ? null
          : DateTime.parse(json['departure_date'].toString()),
    );
  }

  bool get isSEV => visaType == 'SEV';
  bool get isMEV => visaType == 'MEV';
}

class VisaTravelContext {
  final VisaTravelVisa? visa;
  final PlannedTravelInformation? plannedTravel;
  final List<VisaTravelRecord> records;
  final VisaTravelState state;
  final int? remainingDays;

  const VisaTravelContext({
    required this.visa,
    required this.plannedTravel,
    required this.records,
    required this.state,
    required this.remainingDays,
  });

  VisaTravelRecord? get currentOpenRecord {
    for (final record in records) {
      if (record.isOpen) return record;
    }
    return null;
  }

  VisaTravelRecord? get latestRecord =>
      records.isEmpty ? null : records.first;
}

String? _textOrNull(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
