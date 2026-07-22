class ProfileModel {
  final String id;
  final String authId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? nationality;
  final String? passportNo;
  final String? icNumber;
  final String role;
  final String verificationStatus;
  final String? passportFrontUrl;
  final String? passportBackUrl;

  ProfileModel({
    required this.id,
    required this.authId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.nationality,
    this.passportNo,
    this.icNumber,
    required this.role,
    required this.verificationStatus,
    this.passportFrontUrl,
    this.passportBackUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        authId: json['auth_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        phoneNumber: json['phone_number'] as String?,
        nationality: json['nationality'] as String?,
        passportNo: json['passport_no'] as String?,
        icNumber: json['ic_number'] as String?,
        role: json['role'] as String? ?? 'tourist',
        verificationStatus: json['verification_status'] as String? ?? 'pending',
        passportFrontUrl: json['passport_front_url'] as String?,
        passportBackUrl: json['passport_back_url'] as String?,
      );

  bool get isTourist => role == 'tourist';
  bool get isCitizen => role == 'citizen';
  bool get isOfficer => role == 'officer';
  bool get isAdmin => role == 'admin';
  bool get isApproved => verificationStatus == 'approved';
}
