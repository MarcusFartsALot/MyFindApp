import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/validators/validators.dart';
import '../../M400/models/profile_model.dart';

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

  File? _newProfilePhoto;
  Uint8List? _webProfilePhoto;

  bool _isSaving = false;
  bool _hasChanges = false;

  // Citizen Details from public.citizens
  bool _isLoadingCitizen = true;
  Map<String, dynamic>? _citizenData;

  @override
  void initState() {
    super.initState();
    _officialNameController = TextEditingController(
      text: widget.profile.fullName,
    );
    _nicknameController = TextEditingController(
      text: widget.profile.nickname ?? widget.profile.fullName.split(' ')[0],
    );
    _emailController = TextEditingController(text: widget.profile.email);

    _fetchCitizenDetails();
  }

  @override
  void dispose() {
    _officialNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Fetches Citizen National ID record linked to this user's profile_id
  Future<void> _fetchCitizenDetails() async {
    try {
      final data = await _supabase
          .from('citizens')
          .select()
          .eq('profile_id', widget.profile.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _citizenData = data;
          _isLoadingCitizen = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCitizen = false);
      }
    }
  }

  /// Helper to convert relative storage paths to full public URLs
  String? _resolveStorageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    try {
      return _supabase.storage
          .from('registration-documents')
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
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
          _showSnackBar(
            "Invalid file. Please upload an image under 5MB.",
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
        });
      }
    } catch (e) {
      _showSnackBar("Error selecting photo. Please try again.", isError: true);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? photoUrl = widget.profile.profileImage;

      // Upload profile image to S3 bucket under citizens/{profile_id}/
      if (_webProfilePhoto != null || _newProfilePhoto != null) {
        final String fileName =
            'citizens/${widget.profile.id}/profile_${DateTime.now().millisecondsSinceEpoch}.png';

        if (kIsWeb && _webProfilePhoto != null) {
          await _supabase.storage
              .from('registration-documents')
              .uploadBinary(
                fileName,
                _webProfilePhoto!,
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              );
        } else if (_newProfilePhoto != null) {
          await _supabase.storage
              .from('registration-documents')
              .upload(
                fileName,
                _newProfilePhoto!,
                fileOptions: const FileOptions(
                  contentType: 'image/png',
                  upsert: true,
                ),
              );
        }
        photoUrl = _supabase.storage
            .from('registration-documents')
            .getPublicUrl(fileName);
      }

      // Update profiles table
      await _supabase
          .from('profiles')
          .update({
            'nickname': _nicknameController.text.trim(),
            'profile_image': photoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.profile.id);

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      // Insert Activity Notification
      await _supabase.from('notifications').insert({
        'user_id': widget.profile.id,
        'title': 'Profile Updated',
        'message': 'Your personal details or photo were successfully updated.',
        'type': 'Activity',
      });

      widget.onProfileUpdated();
      _showSnackBar("Profile details updated successfully!");
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar("Failed to update profile: $e", isError: true);
    }
  }

  /// Refined Change Password Dialog (Removed duplicate X button, updated label)
  void _showChangePasswordModal() {
    final pwdFormKey = GlobalKey<FormState>();
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    bool isUpdatingPwd = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? currentPasswordError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: Color(0xFF1E3A8A),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Change Password',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Update password for security',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),

                      // Form Fields
                      Form(
                        key: pwdFormKey,
                        child: Column(
                          children: [
                            // Current Password
                            TextFormField(
                              controller: currentPwdController,
                              obscureText: obscureCurrent,
                              onChanged: (_) {
                                if (currentPasswordError != null) {
                                  setModalState(
                                    () => currentPasswordError = null,
                                  );
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                hintText: 'Enter current password',
                                errorText: currentPasswordError,
                                prefixIcon: const Icon(
                                  Icons.vpn_key_outlined,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureCurrent
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      obscureCurrent = !obscureCurrent;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1E3A8A),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Please enter your current password'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // New Password
                            TextFormField(
                              controller: newPwdController,
                              obscureText: obscureNew,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                hintText: 'Enter new password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureNew
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      obscureNew = !obscureNew;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1E3A8A),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 16),

                            // Confirm New Password
                            TextFormField(
                              controller: confirmPwdController,
                              obscureText: obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                hintText: 'Re-enter new password',
                                prefixIcon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      obscureConfirm = !obscureConfirm;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1E3A8A),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (val) => Validators.confirmPassword(
                                val,
                                newPwdController.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isUpdatingPwd
                                  ? null
                                  : () async {
                                      if (!pwdFormKey.currentState!
                                          .validate()) {
                                        return;
                                      }

                                      setModalState(() {
                                        isUpdatingPwd = true;
                                        currentPasswordError = null;
                                      });

                                      try {
                                        final currentUser =
                                            _supabase.auth.currentUser;
                                        if (currentUser?.id !=
                                            widget.profile.authId) {
                                          throw const AuthException(
                                            'Your session has expired. Please sign in again.',
                                          );
                                        }
                                        final authEmail = currentUser?.email
                                            ?.trim()
                                            .toLowerCase();
                                        if (authEmail == null ||
                                            authEmail.isEmpty) {
                                          throw const AuthException(
                                            'Your Supabase account email is unavailable. Please sign in again.',
                                          );
                                        }

                                        // This app's installed Supabase SDK does not yet
                                        // support UserAttributes.currentPassword. Sign in
                                        // with the current password to verify it first.
                                        final signInResponse = await _supabase
                                            .auth
                                            .signInWithPassword(
                                              // Use the email from auth.users, not a
                                              // profile record that could be stale.
                                              email: authEmail,
                                              password:
                                                  currentPwdController.text,
                                            );

                                        if (signInResponse.user?.id !=
                                            widget.profile.authId) {
                                          throw const AuthException(
                                            'The current password could not be verified.',
                                          );
                                        }

                                        await _supabase.auth.updateUser(
                                          UserAttributes(
                                            password: newPwdController.text,
                                          ),
                                        );

                                        // Activity logging must not make a successful
                                        // password change look like a failure.
                                        try {
                                          await _supabase
                                              .from('notifications')
                                              .insert({
                                                'user_id': widget.profile.id,
                                                'title': 'Password Changed',
                                                'message':
                                                    'Your account password was changed successfully.',
                                                'type': 'Activity',
                                                'is_read': false,
                                              });
                                        } catch (error) {
                                          debugPrint(
                                            'Could not log password-change activity: $error',
                                          );
                                        }

                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (mounted) {
                                          _showSnackBar(
                                            "Your password has been changed successfully.",
                                          );
                                        }
                                      } on AuthException catch (error) {
                                        setModalState(() {
                                          isUpdatingPwd = false;
                                          currentPasswordError =
                                              error.message.contains('expired')
                                              ? error.message
                                              : 'This password does not match your signed-in Supabase account.';
                                        });
                                      } catch (e) {
                                        setModalState(() {
                                          isUpdatingPwd = false;
                                          currentPasswordError =
                                              'Unable to change password. Please try again.';
                                        });
                                      }
                                    },
                              child: isUpdatingPwd
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Change Password',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDocumentPreview(String title, String documentUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
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
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    documentUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 250,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'Unable to load document image.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ImageProvider? _getAvatarImage() {
    if (kIsWeb && _webProfilePhoto != null) {
      return MemoryImage(_webProfilePhoto!);
    } else if (_newProfilePhoto != null) {
      return FileImage(_newProfilePhoto!);
    } else if (widget.profile.profileImage != null &&
        widget.profile.profileImage!.isNotEmpty) {
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String title, String? rawPath) {
    final String? fullUrl = _resolveStorageUrl(rawPath);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (fullUrl != null && fullUrl.isNotEmpty) ...[
            ClipRRect(
              child: Image.network(
                fullUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showDocumentPreview(title, fullUrl),
                  icon: const Icon(
                    Icons.zoom_in_rounded,
                    size: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                  label: const Text(
                    'View Full Document',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8FAFC),
              child: const Text(
                'No document image uploaded.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status =
        _citizenData?['verification_status']?.toString().toUpperCase() ??
        'PENDING';
    final String? verifiedAt = _citizenData?['verified_at']?.toString();
    final String? rejectionReason = _citizenData?['rejection_reason']
        ?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profile & Citizen Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Picker
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: _getAvatarImage(),
                        child: _getAvatarImage() == null
                            ? const Icon(
                                Icons.person,
                                size: 44,
                                color: Color(0xFF94A3B8),
                              )
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
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Information Section
                const Text(
                  'ACCOUNT DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _officialNameController,
                  readOnly: true,
                  onTap: () {
                    _showSnackBar(
                      "Official name cannot be changed as it must match your identity documents.",
                      isError: true,
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Official Full Name',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nicknameController,
                  onChanged: (_) => _markAsChanged(),
                  decoration: InputDecoration(
                    labelText: 'Preferred Nickname',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Nickname cannot be empty'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Citizen National Identity Details
                const Text(
                  'CITIZEN NATIONAL IDENTIFICATION (MYKAD)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                if (_isLoadingCitizen)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_citizenData == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No citizen identity record linked to this account.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                else ...[
                  _buildReadOnlyField(
                    'IC / MyKad Number',
                    _citizenData?['ic_number']?.toString() ?? 'N/A',
                    icon: Icons.badge_outlined,
                  ),
                  _buildReadOnlyField(
                    'Verification Status',
                    status,
                    icon: Icons.verified_user_outlined,
                  ),
                  if (verifiedAt != null && verifiedAt.isNotEmpty)
                    _buildReadOnlyField(
                      'Verified On',
                      verifiedAt.split('T')[0],
                      icon: Icons.event_available_outlined,
                    ),
                  if (rejectionReason != null && rejectionReason.isNotEmpty)
                    _buildReadOnlyField(
                      'Rejection Reason',
                      rejectionReason,
                      icon: Icons.error_outline,
                    ),

                  const SizedBox(height: 16),

                  // Uploaded National Registration Documents
                  const Text(
                    'UPLOADED REGISTRATION DOCUMENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildDocumentCard(
                    'MyKad (Front)',
                    _citizenData?['ic_front_url'],
                  ),
                  _buildDocumentCard(
                    'MyKad (Back)',
                    _citizenData?['ic_back_url'],
                  ),
                ],

                const SizedBox(height: 28),

                // Security & Actions
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _showChangePasswordModal,
                    child: const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _hasChanges && !_isSaving
                        ? _saveProfileChanges
                        : null,
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Profile Changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
