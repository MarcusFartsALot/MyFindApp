import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../M400/models/profile_model.dart';
import '../screens/notifications_screen.dart'; // Adjust import path if needed

class DynamicNotificationBell extends StatelessWidget {
  final ProfileModel profile;

  const DynamicNotificationBell({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // 1. Listen to the user's notifications in real-time
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', profile.id),
      builder: (context, snapshot) {
        // 2. Check if there are any unread notifications
        final notifications = snapshot.data ?? [];
        final bool hasUnread = notifications.any(
          (item) => item['is_read'] == false,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            // Bell Icon Button
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF0F172A),
                size: 26,
              ),
              onPressed: () {
                // Navigate to Notifications Screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(profile: profile),
                  ),
                );
              },
            ),

            // 3. Red Badge / Dot (Positioned at bottom-right of icon)
            if (hasUnread)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626), // Red dot
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white, // White outline for clarity
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
