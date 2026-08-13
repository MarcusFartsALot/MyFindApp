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

  File? _newProfilePhoto;
  Uint8List? _webProfilePhoto;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _officialNameController = TextEditingController(text: widget.profile.fullName);
    _nicknameController = TextEditingController(
      text: widget.profile.nickname ?? widget.profile.fullName.split(' ')[0],
    );
    _emailController = TextEditingController(text: widget.profile.email);
  }

  @override
  void dispose() {
    _officialNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
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
          _showSnackBar("Invalid file. Please upload an image under 5MB.", isError: true);
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

      if (_webProfilePhoto != null || _newProfilePhoto != null) {
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

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      await _supabase.from('notifications').insert({
        'user_id': widget.profile.id,
        'title': 'Profile Updated',
        'message': 'Your personal details, photo, or security preferences were successfully updated on the system.',
        'type': 'Activity',
      });

      widget.onProfileUpdated();

      _showSnackBar("Profile details updated successfully!");
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar("Failed to update profile: $e", isError: true);
    }
  }

  void _showChangePasswordModal() {
    final pwdFormKey = GlobalKey<FormState>();
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    bool isUpdatingPwd = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              content: Form(
                key: pwdFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPwdController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Current Password'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPwdController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPwdController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm New Password'),
                      validator: (val) => Validators.confirmPassword(val, newPwdController.text),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
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

                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                        _showSnackBar("Your password has been changed successfully.");
                      }
                    } on AuthException catch (_) {
                      setModalState(() => isUpdatingPwd = false);
                      _showSnackBar("Passwords do not match or do not meet security requirements.", isError: true);
                    } catch (e) {
                      setModalState(() => isUpdatingPwd = false);
                      _showSnackBar("System Error.", isError: true);
                    }
                  },
                  child: isUpdatingPwd
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Password', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: _getAvatarImage(),
                        child: _getAvatarImage() == null
                            ? const Icon(Icons.person, size: 42, color: Color(0xFF94A3B8))
                            : null,
                      ),
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(color: Color(0xFF1E3A8A), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _officialNameController,
                  readOnly: true,
                  onTap: () {
                    _showSnackBar("Official name cannot be changed as it must match your identity documents.", isError: true);
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Nickname cannot be empty' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Change Password Button (Brought Up)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showChangePasswordModal,
                    child: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Save Profile Changes Button (Moved Below)
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
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Profile Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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