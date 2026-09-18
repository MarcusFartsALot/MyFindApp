import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Added for date formatting
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

  /// Formats ISO timestamp to local timezone (Malaysia)
  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      // 1. Force UTC parsing in case Supabase omits the 'Z' indicator
      String parseString = isoString;
      if (!parseString.endsWith('Z')) {
        parseString += 'Z';
      }

      // 2. Parse as UTC, then convert to device's local timezone
      DateTime utcTime = DateTime.parse(parseString);
      DateTime localTime = utcTime.toLocal();

      // 3. Format beautifully using the intl package
      return DateFormat('dd MMM yyyy • hh:mm a').format(localTime);
    } catch (_) {
      return isoString; // Fallback if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate notifications into the 2 requested categories
    final adminAlerts = _allNotifications.where((n) => n['type'] == 'Alert').toList();
    final touristActivities = _allNotifications.where((n) => n['type'] != 'Alert').toList();

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
                    Text('Notifications (${adminAlerts.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Activities (${touristActivities.length})'),
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
              items: adminAlerts,
              emptyTitle: 'No Admin Notifications',
              emptySubtitle: 'Important visa expiration alerts and official admin notices will appear here.',
              emptyIcon: Icons.notifications_off_outlined,
              isAlertCategory: true,
            ),
            // Tab 2: Tourist Activity Tracking Logs
            _buildNotificationListView(
              items: touristActivities,
              emptyTitle: 'No Recent Activities',
              emptySubtitle: 'Your activity history (e.g. profile updates, password changes, visa submissions) will be logged here.',
              emptyIcon: Icons.assignment_outlined,
              isAlertCategory: false,
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
    required bool isAlertCategory,
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
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isRead = item['is_read'] == true;
          final String title = item['title'] ?? 'Notification';

          IconData displayIcon = Icons.task_alt_rounded;
          if (isAlertCategory) {
            displayIcon = Icons.warning_amber_rounded;
          } else {
            if (title.contains('Security')) {
              displayIcon = Icons.shield_outlined;
            } else if (title.contains('Profile')) {
              displayIcon = Icons.manage_accounts_outlined;
            } else if (title.contains('Visa Application')) {
              displayIcon = Icons.airplane_ticket_outlined;
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white
                  : (isAlertCategory ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead
                    ? const Color(0xFFE2E8F0)
                    : (isAlertCategory ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE)),
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
                    color: isAlertCategory
                        ? const Color(0xFFDC2626).withOpacity(0.1)
                        : const Color(0xFF1E3A8A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    displayIcon,
                    color: isAlertCategory ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
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
}