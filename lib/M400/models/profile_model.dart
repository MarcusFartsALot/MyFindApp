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
  final String? nickname;
  final String? profileImage;
  final String? preferredLanguage;

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
    this.nickname,
    this.profileImage,
    this.preferredLanguage,
  });

  factory ProfileModel.fromRecords(
      Map<String, dynamic> profile,
      Map<String, dynamic>? roleDetails,
      ) {
    final role = profile['role'] as String? ?? 'tourist';
    final details = roleDetails ?? const <String, dynamic>{};
    return ProfileModel(
      id: profile['id'] as String,
      authId: profile['auth_id'] as String,
      fullName: profile['full_name'] as String,
      email: profile['email'] as String,
      phoneNumber: profile['phone_number'] as String?,
      nationality: profile['nationality'] as String?,
      passportNo: details['passport_number'] as String?,
      icNumber: details['ic_number'] as String?,
      role: role,
      verificationStatus: role == 'admin'
          ? 'approved'
          : (details['verification_status'] as String? ?? 'pending'),
      passportFrontUrl: details['passport_front_url'] as String?,
      passportBackUrl: details['passport_back_url'] as String?,
      nickname: profile['nickname'] as String?,
      profileImage: profile['profile_image'] as String?,
      preferredLanguage: profile['preferred_language'] as String? ?? 'English',
    );
  }

  bool get isTourist => role == 'tourist';
  bool get isCitizen => role == 'citizen';
  bool get isOfficer => role == 'officer';
  bool get isAdmin => role == 'admin';
  bool get isApproved =>
      isAdmin || isOfficer || verificationStatus == 'approved';
}