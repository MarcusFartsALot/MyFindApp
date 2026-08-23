import 'package:flutter/material.dart';
import '../../M400/models/profile_model.dart';
import 'settings_screen.dart';

class MeScreen extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onProfileUpdated;

  const MeScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  ImageProvider? _getAvatarImage() {
    if (profile.profileImage != null && profile.profileImage!.isNotEmpty) {
      return NetworkImage(profile.profileImage!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String nickname = profile.nickname ?? profile.fullName.split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20.0),
        children: [
          // Top User Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: _getAvatarImage(),
                  child: _getAvatarImage() == null
                      ? const Icon(Icons.person, size: 36, color: Color(0xFF94A3B8))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Nickname: $nickname',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings Box Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined, color: Color(0xFF1E3A8A), size: 22),
              ),
              title: const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Manage Profile & Sign Out',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      profile: profile,
                      onProfileUpdated: onProfileUpdated,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}