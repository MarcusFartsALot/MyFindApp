import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../M400/models/profile_model.dart';

class NotificationsScreen extends StatefulWidget {
  final ProfileModel profile;

  const NotificationsScreen({super.key, required this.profile});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndMarkAsRead();
  }

  Future<void> _fetchAndMarkAsRead() async {
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', widget.profile.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allNotifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }

      // Mark unread notifications as read
      final unreadIds = _allNotifications
          .where((n) => n['is_read'] == false)
          .map((n) => n['id'])
          .toList();

      if (unreadIds.isNotEmpty) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .inFilter('id', unreadIds);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching notifications: $e");
    }
  }

  /// Formats ISO timestamp to a clean date and time string
  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final String month = months[date.month - 1];
      final String day = date.day.toString().padLeft(2, '0');
      final String year = date.year.toString();

      final int hourRaw = date.hour;
      final String period = hourRaw >= 12 ? 'PM' : 'AM';
      final int hour12 = hourRaw % 12 == 0 ? 12 : hourRaw % 12;
      final String hour = hour12.toString().padLeft(2, '0');
      final String minute = date.minute.toString().padLeft(2, '0');

      return "$day $month $year • $hour:$minute $period";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate notifications into the 2 requested categories
    final notificationItems = _allNotifications.where(
      (item) =>
          item['type'] == 'Notification' ||
          item['type'] == 'Warning' ||
          item['type'] == 'Alert',
    ).toList();
    final activityItems = _allNotifications
        .where((item) => item['type'] == 'Activity')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Inbox',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          bottom: TabBar(
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Notifications (${notificationItems.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Activities (${activityItems.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
            : TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            // Tab 1: Admin Alerts & Messages
            _buildNotificationListView(
              items: notificationItems,
              emptyTitle: 'No Admin Notifications',
              emptySubtitle: 'Important visa expiration alerts and official admin notices will appear here.',
              emptyIcon: Icons.notifications_off_outlined,
            ),
            // Tab 2: Tourist Activity Tracking Logs
            _buildNotificationListView(
              items: activityItems,
              emptyTitle: 'No Recent Activities',
              emptySubtitle: 'Your activity history (e.g. profile updates, password changes, visa submissions) will be logged here.',
              emptyIcon: Icons.assignment_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationListView({
    required List<Map<String, dynamic>> items,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: Icon(emptyIcon, size: 48, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAndMarkAsRead,
      color: const Color(0xFF1E3A8A),
      child: ListView.builder(
        // Drag up/down phone scroll physics
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isRead = item['is_read'] == true;
          final String title = item['title'] ?? 'Notification';
          final visual = _notificationVisual(item);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white
                  : visual.unreadBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead
                    ? const Color(0xFFE2E8F0)
                    : visual.unreadBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: visual.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visual.icon,
                    color: visual.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['message'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(item['created_at']),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  ({
    IconData icon,
    Color accent,
    Color unreadBackground,
    Color unreadBorder,
  }) _notificationVisual(Map<String, dynamic> item) {
    switch (item['type']) {
      case 'Notification':
        return (
          icon: Icons.info_outline_rounded,
          accent: const Color(0xFF1E3A8A),
          unreadBackground: const Color(0xFFEFF6FF),
          unreadBorder: const Color(0xFFBFDBFE),
        );
      case 'Warning':
        return (
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFD97706),
          unreadBackground: const Color(0xFFFFFBEB),
          unreadBorder: const Color(0xFFFDE68A),
        );
      case 'Alert':
        return (
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFDC2626),
          unreadBackground: const Color(0xFFFEF2F2),
          unreadBorder: const Color(0xFFFCA5A5),
        );
      case 'Activity':
        final title = item['title']?.toString() ?? '';
        IconData icon = Icons.task_alt_rounded;

        if (title.contains('Security')) {
          icon = Icons.shield_outlined;
        } else if (title.contains('Profile')) {
          icon = Icons.manage_accounts_outlined;
        } else if (title.contains('Visa Application')) {
          icon = Icons.airplane_ticket_outlined;
        }

        return (
          icon: icon,
          accent: const Color(0xFF1E3A8A),
          unreadBackground: const Color(0xFFEFF6FF),
          unreadBorder: const Color(0xFFBFDBFE),
        );
      default:
        return (
          icon: Icons.help_outline_rounded,
          accent: const Color(0xFF64748B),
          unreadBackground: const Color(0xFFF8FAFC),
          unreadBorder: const Color(0xFFCBD5E1),
        );
    }
  }
}
