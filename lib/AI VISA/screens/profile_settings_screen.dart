import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../M400/models/profile_model.dart';
import '../../core/validators/validators.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final ProfileModel profile;
  final VoidCallback onProfileUpdated;

  const ProfileSettingsScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _officialNameController;
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;

  // NEW: Strict baseline tracking for text fields
  late String _initialNickname;

  File? _newProfilePhoto;
  Uint8List? _webProfilePhoto;

  bool _isSaving = false;
  bool _hasChanges = false;

  // NEW: Flag to track if the current photo preview is an unsaved change
  bool _photoHasUnsavedChanges = false;

  // Tourist Details from M100
  bool _isLoadingTourist = true;
  Map<String, dynamic>? _touristData;

  @override
  void initState() {
    super.initState();
    _officialNameController = TextEditingController(text: widget.profile.fullName);

    // Baseline the nickname perfectly on load
    _initialNickname = widget.profile.nickname ?? widget.profile.fullName.split(' ')[0];
    _nicknameController = TextEditingController(text: _initialNickname);

    _emailController = TextEditingController(text: widget.profile.email);

    _fetchTouristDetails();
  }

  @override
  void dispose() {
    _officialNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchTouristDetails() async {
    try {
      final data = await _supabase
          .from('tourists')
          .select()
          .eq('profile_id', widget.profile.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _touristData = data;
          _isLoadingTourist = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTourist = false);
      }
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  /// Custom UI Popup Dialog for Success, Error, and Validation Feedback
  void _showStatusDialog({
    required String title,
    required String message,
    bool isError = false,
    bool isInfo = false,
    String buttonText = "Understood",
    VoidCallback? onConfirm,
  }) {
    if (!mounted) return;

    final Color themeColor = isError
        ? const Color(0xFFDC2626)
        : (isInfo ? const Color(0xFF1E3A8A) : const Color(0xFF15803D));

    final IconData statusIcon = isError
        ? Icons.error_outline_rounded
        : (isInfo ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: themeColor, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (onConfirm != null) onConfirm();
                },
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: kIsWeb,
      );

      if (result != null) {
        final PlatformFile fileData = result.files.single;

        if (fileData.size > 5 * 1024 * 1024) {
          _showStatusDialog(
            title: "File Too Large",
            message: "The selected image exceeds 5MB. Please choose a smaller photo.",
            isError: true,
          );
          return;
        }

        setState(() {
          if (kIsWeb) {
            _webProfilePhoto = fileData.bytes;
          } else if (fileData.path != null) {
            _newProfilePhoto = File(fileData.path!);
          }
          _hasChanges = true;
          _photoHasUnsavedChanges = true; // Mark that the photo specifically changed
        });

        _showStatusDialog(
          title: "New Photo Selected",
          message: "Your new profile picture is ready. Click 'Save Profile Changes' below to apply it.",
          isInfo: true,
        );
      }
    } catch (e) {
      _showStatusDialog(
        title: "Photo Selection Failed",
        message: "An error occurred while choosing your image. Please try again.",
        isError: true,
      );
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusDialog(
        title: "Update Error",
        message: "Nickname fields cannot be empty.",
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? photoUrl = widget.profile.profileImage;

      // FIXED: Uses the strict tracking flags to accurately capture the specific action
      bool photoChanged = _photoHasUnsavedChanges;
      bool nicknameChanged = _nicknameController.text.trim() != _initialNickname.trim();

      if (photoChanged) {
        final String fileName =
            'tourists/${widget.profile.id}/profile_${DateTime.now().millisecondsSinceEpoch}.png';

        if (kIsWeb && _webProfilePhoto != null) {
          await _supabase.storage.from('registration-documents').uploadBinary(
            fileName,
            _webProfilePhoto!,
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
          );
        } else if (_newProfilePhoto != null) {
          await _supabase.storage.from('registration-documents').upload(
            fileName,
            _newProfilePhoto!,
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
          );
        }
        photoUrl = _supabase.storage.from('registration-documents').getPublicUrl(fileName);
      }

      await _supabase.from('profiles').update({
        'nickname': _nicknameController.text.trim(),
        'profile_image': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.profile.id);

      List<String> updatedItems = [];
      if (photoChanged) updatedItems.add("profile photo");
      if (nicknameChanged) updatedItems.add("nickname");

      String specificMessage = "Your profile was updated.";
      if (updatedItems.length == 1) {
        specificMessage = "Your ${updatedItems[0]} was successfully updated.";
      } else if (updatedItems.length > 1) {
        specificMessage = "Your ${updatedItems.join(' and ')} were successfully updated.";
      }

      if (updatedItems.isNotEmpty) {
        await _supabase.from('notifications').insert({
          'user_id': widget.profile.id,
          'title': 'Profile Updated',
          'message': specificMessage,
          'type': 'Activity',
        });
      }

      // Reset the tracking flags to prevent duplicate trigger bugs on next save
      setState(() {
        _isSaving = false;
        _hasChanges = false;
        _photoHasUnsavedChanges = false;
        _initialNickname = _nicknameController.text.trim();
      });

      widget.onProfileUpdated();

      // UI Success Modal Prompt
      _showStatusDialog(
        title: "Profile Updated Successfully!",
        message: specificMessage,
        isError: false,
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showStatusDialog(
        title: "Update Failed",
        message: "Unable to save your profile changes. Error: $e",
        isError: true,
      );
    }
  }

  void _showChangePasswordModal() {
    final pwdFormKey = GlobalKey<FormState>();
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    bool isUpdatingPwd = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 8),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18)),
                  SizedBox(height: 6),
                  Text('Enter your current password and a new secure password.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.normal)),
                ],
              ),
              contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
              content: Form(
                key: pwdFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPwdController,
                        obscureText: obscureCurrent,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                            onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                          ),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter your current password' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: newPwdController,
                        obscureText: obscureNew,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF94A3B8), size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                            onPressed: () => setModalState(() => obscureNew = !obscureNew),
                          ),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmPwdController,
                        obscureText: obscureConfirm,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF94A3B8), size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                            onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                          ),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                        ),
                        validator: (val) => Validators.confirmPassword(val, newPwdController.text),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(right: 24, bottom: 24, top: 16),
              actions: [
                TextButton(
                  onPressed: isUpdatingPwd ? null : () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    disabledBackgroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isUpdatingPwd
                      ? null
                      : () async {
                    if (!pwdFormKey.currentState!.validate()) return;

                    setModalState(() => isUpdatingPwd = true);

                    try {
                      await _supabase.auth.signInWithPassword(
                        email: widget.profile.email,
                        password: currentPwdController.text,
                      );

                      await _supabase.auth.updateUser(
                        UserAttributes(password: newPwdController.text),
                      );

                      await _supabase.from('notifications').insert({
                        'user_id': widget.profile.id,
                        'title': 'Security Update',
                        'message': 'Your account password has been successfully changed.',
                        'type': 'Activity',
                      });

                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                        // UI Prompt on Password Success
                        _showStatusDialog(
                          title: "Password Changed!",
                          message: "Your account password have been successfully updated. You can now use your new password for future logins.",
                          isError: false,
                        );
                      }
                    } on AuthException catch (_) {
                      setModalState(() => isUpdatingPwd = false);
                      _showStatusDialog(
                        title: "Password Update Failed",
                        message: "The current password entered is incorrect.",
                        isError: true,
                      );
                    } catch (e) {
                      setModalState(() => isUpdatingPwd = false);
                      _showStatusDialog(
                        title: "System Error",
                        message: "A network or system error occurred while updating your password.",
                        isError: true,
                      );
                    }
                  },
                  child: isUpdatingPwd
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPassportPreview(String passportUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Passport Document',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  passportUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('Unable to load passport document image.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getAvatarImage() {
    if (kIsWeb && _webProfilePhoto != null) {
      return MemoryImage(_webProfilePhoto!);
    } else if (_newProfilePhoto != null) {
      return FileImage(_newProfilePhoto!);
    } else if (widget.profile.profileImage != null && widget.profile.profileImage!.isNotEmpty) {
      return NetworkImage(widget.profile.profileImage!);
    }
    return null;
  }

  Widget _buildReadOnlyField(String label, String value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? passportUrl = _touristData?['passport_front_url'];

    if (passportUrl != null && passportUrl.isNotEmpty && !passportUrl.startsWith('http')) {
      try {
        passportUrl = _supabase.storage.from('registration-documents').getPublicUrl(passportUrl);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tourist Profile Details',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: _getAvatarImage(),
                        child: _getAvatarImage() == null
                            ? const Icon(Icons.person, size: 44, color: Color(0xFF94A3B8))
                            : null,
                      ),
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E3A8A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'ACCOUNT DETAILS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _officialNameController,
                  readOnly: true,
                  onTap: () {
                    _showStatusDialog(
                      title: "Official Name Locked",
                      message: "Your official full name cannot be changed directly as it must strictly match your verified travel passport and identity documents.",
                      isInfo: true,
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Official Name',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    suffixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nicknameController,
                  onChanged: (_) => _markAsChanged(),
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nickname cannot be empty' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  onTap: () {
                    _showStatusDialog(
                      title: "Registered Email",
                      message: "Your email is your unique account identifier and cannot be modified from profile settings.",
                      isInfo: true,
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    suffixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'TOURIST REGISTRATION INFORMATION',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),

                if (_isLoadingTourist)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_touristData == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No tourist registration record linked to this account.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                else ...[
                    _buildReadOnlyField(
                      'Passport Number',
                      _touristData?['passport_number']?.toString() ?? 'N/A',
                      icon: Icons.badge_outlined,
                    ),
                    _buildReadOnlyField(
                      'Passport Issuing Country',
                      _touristData?['passport_issuing_country']?.toString() ?? 'N/A',
                      icon: Icons.public_outlined,
                    ),
                    _buildReadOnlyField(
                      'Country of Residence',
                      _touristData?['country_of_residence']?.toString() ?? 'N/A',
                      icon: Icons.home_work_outlined,
                    ),
                    _buildReadOnlyField(
                      'Passport Issue Date',
                      _touristData?['passport_issue_date']?.toString() ?? 'N/A',
                      icon: Icons.calendar_today_outlined,
                    ),
                    _buildReadOnlyField(
                      'Passport Expiry Date',
                      _touristData?['passport_expiry_date']?.toString() ?? 'N/A',
                      icon: Icons.calendar_month_outlined,
                    ),
                    _buildReadOnlyField(
                      'Verification Status',
                      (_touristData?['verification_status']?.toString() ?? 'N/A').toUpperCase(),
                      icon: Icons.verified_user_outlined,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'UPLOADED PASSPORT DOCUMENT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    if (passportUrl != null && passportUrl.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                passportUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Document preview unavailable',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _touristData?['verification_status'] == 'approved' ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                                        color: _touristData?['verification_status'] == 'approved' ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _touristData?['verification_status'] == 'approved' ? 'Identity Verified' : 'Verification Pending',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _touristData?['verification_status'] == 'approved' ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showPassportPreview(passportUrl!),
                                    icon: const Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF1E3A8A)),
                                    label: const Text(
                                      'View Full Document',
                                      style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'No passport document uploaded on file.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showChangePasswordModal,
                    child: const Text(
                      'Change Password',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      disabledBackgroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _hasChanges && !_isSaving ? _saveProfileChanges : null,
                    child: _isSaving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      'Save Profile Changes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}