enum IncidentReportStatus {
  pendingReview,
  validated,
  rejected;

  static IncidentReportStatus fromRaw(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'validated':
        return IncidentReportStatus.validated;
      case 'rejected':
        return IncidentReportStatus.rejected;
      case 'pending review':
      default:
        return IncidentReportStatus.pendingReview;
    }
  }

  String get label => switch (this) {
    IncidentReportStatus.pendingReview => 'Pending Review',
    IncidentReportStatus.validated => 'Validated',
    IncidentReportStatus.rejected => 'Rejected',
  };

  bool get canEdit => this == IncidentReportStatus.pendingReview;
}

class IncidentReportModel {
  final String id;
  final String ticketId;
  final String creatorIcHash;
  final String creatorProfileId;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String category;
  final String urgencyLevel;
  final String location;
  final String address;
  final DateTime incidentDate;
  final String incidentTime;
  final String description;
  final double? latitude;
  final double? longitude;
  final List<String> mediaPaths;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentReportModel({
    required this.id,
    required this.ticketId,
    required this.creatorIcHash,
    required this.creatorProfileId,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.category,
    required this.urgencyLevel,
    required this.location,
    required this.address,
    required this.incidentDate,
    required this.incidentTime,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.mediaPaths,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media_paths'];
    return IncidentReportModel(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      creatorIcHash: json['creator_ic_hash'] as String? ?? '',
      creatorProfileId: json['creator_profile_id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String,
      category: json['category'] as String,
      urgencyLevel: json['urgency_level'] as String? ?? 'Normal',
      location: json['location'] as String,
      address: json['address'] as String,
      incidentDate: DateTime.parse(json['incident_date'] as String),
      incidentTime: (json['incident_time'] as String).substring(0, 5),
      description: json['description'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mediaPaths: rawMedia is List
          ? rawMedia.whereType<String>().toList(growable: false)
          : const [],
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  IncidentReportStatus get statusType => IncidentReportStatus.fromRaw(status);

  bool get canEdit => statusType.canEdit;
}

typedef IncidentReportDto = IncidentReportModel;
