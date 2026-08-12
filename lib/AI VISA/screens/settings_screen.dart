import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../M400/models/profile_model.dart';
import '../../M400/services/auth_service.dart';
import '../../M400/screens/auth/login_screen.dart';
import '../services/translation_service.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ProfileModel profile;
  final VoidCallback onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  late String _currentLanguage;

  final List<String> _languages = [
    'English',
    'Bahasa Melayu',
    '中文 (Chinese)',
    '日本語 (Japanese)',
    '한국어 (Korean)',
  ];

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.profile.preferredLanguage ?? 'English';
  }

  Future<void> _updateLanguage(String newLang) async {
    try {
      await _supabase.from('profiles').update({
        'preferred_language': newLang,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.profile.id);

      setState(() => _currentLanguage = newLang);
      widget.onProfileUpdated();

      _showSnackBar("Language changed to $newLang");
    } catch (e) {
      _showSnackBar("Failed to update language.", isError: true);
    }
  }

  void _showDraggableLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Visual Drag Handle Pill
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DynamicText(
                        'Select Preferred Language',
                        targetLanguage: _currentLanguage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      itemCount: _languages.length,
                      itemBuilder: (context, index) {
                        final lang = _languages[index];
                        final bool isSelected = lang == _currentLanguage;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          title: Text(
                            lang,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E3A8A))
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            _updateLanguage(lang);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: DynamicText(
          'Settings',
          targetLanguage: _currentLanguage,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF1E3A8A), size: 20),
                  ),
                  title: DynamicText('Profile', targetLanguage: _currentLanguage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: DynamicText('Edit nickname, photo & password', targetLanguage: _currentLanguage, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileSettingsScreen(
                          profile: widget.profile,
                          onProfileUpdated: widget.onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.language_rounded, color: Color(0xFF1E3A8A), size: 20),
                  ),
                  title: DynamicText('Preferred Language', targetLanguage: _currentLanguage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(_currentLanguage, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: _showDraggableLanguageSelector,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
              title: DynamicText(
                'Sign Out',
                targetLanguage: _currentLanguage,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626)),
              ),
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}