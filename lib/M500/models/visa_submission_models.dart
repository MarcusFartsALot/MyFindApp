enum SubmissionStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class VisaSubmission {
  final String id;
  final String applicationId;
  final String referenceId;
  final String fullName;
  final String passportNumber;
  final String nationality;
  final String purposeOfVisit;
  final String arrivalDate;
  final String departureDate;
  final String visaType;
  final DateTime? visaExpiryDate;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final String? pdfUrl;
  final String? pdfFileName;

  VisaSubmission({
    required this.id,
    required this.applicationId,
    required this.referenceId,
    required this.fullName,
    required this.passportNumber,
    required this.nationality,
    required this.purposeOfVisit,
    required this.arrivalDate,
    required this.departureDate,
    required this.visaType,
    this.visaExpiryDate,
    required this.submittedAt,
    required this.status,
    this.pdfUrl,
    this.pdfFileName,
  });

  factory VisaSubmission.fromJson(
      Map<String, dynamic> json,
      ) {
    return VisaSubmission(
      id: json['id']?.toString() ?? '',
      applicationId: json['application_id']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      passportNumber: json['passport_number']?.toString() ?? '',
      nationality: json['nationality']?.toString() ?? '',
      purposeOfVisit: json['purpose_of_visit']?.toString() ?? '',
      arrivalDate: json['arrival_date']?.toString() ?? '',
      departureDate: json['departure_date']?.toString() ?? '',
      visaType: _normalizeVisaType(json['visa_type']),
      visaExpiryDate: json['visa_expiry_date'] == null
          ? null
          : DateTime.tryParse(json['visa_expiry_date'].toString()),
      submittedAt: _parseDateTime(json['submitted_at']),
      status: _parseStatus(json['status']),
      pdfUrl: json['pdf_url']?.toString(),
      pdfFileName: json['pdf_file_name']?.toString(),
    );
  }

  static String _normalizeVisaType(dynamic value) {
    final type = value?.toString().toUpperCase();

    if (type == 'MEV') {
      return 'MEV';
    }

    return 'SEV';
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    return DateTime.tryParse(value.toString()) ??
        DateTime.now();
  }

  static SubmissionStatus _parseStatus(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'approved':
        return SubmissionStatus.approved;
      case 'rejected':
        return SubmissionStatus.rejected;
      case 'cancelled':
        return SubmissionStatus.cancelled;
      case 'pending':
      default:
        return SubmissionStatus.pending;
    }
  }
}
