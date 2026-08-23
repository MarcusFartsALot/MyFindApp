import 'dart:async';

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
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _listenForNotifications();
  }

  void _listenForNotifications() {
    _notificationSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.profile.id)
        .listen(
          (data) {
            final notifications = List<Map<String, dynamic>>.from(data)
              ..sort((a, b) {
                final first = DateTime.tryParse(
                  a['created_at'] as String? ?? '',
                );
                final second = DateTime.tryParse(
                  b['created_at'] as String? ?? '',
                );
                return (second ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(first ?? DateTime.fromMillisecondsSinceEpoch(0));
              });

            if (mounted) {
              setState(() {
                _allNotifications = notifications;
                _isLoading = false;
              });
            }
          },
          onError: (Object error) {
            debugPrint('Notification realtime stream error: $error');
          },
        );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
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
    // Category division: Alerts (Admin approvals & urgent notices) vs Activities
    final adminAlerts = _allNotifications
        .where((n) => n['type'] == 'Alert')
        .toList();
    final activities = _allNotifications
        .where((n) => n['type'] != 'Alert')
        .toList();
    final unreadActivities = activities
        .where((notification) => notification['is_read'] == false)
        .length;
    final unreadAlerts = adminAlerts
        .where((notification) => notification['is_read'] == false)
        .length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Notifications & Activity',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          bottom: TabBar(
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Notifications ($unreadAlerts)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text('Activities ($unreadActivities)'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              )
            : TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildNotificationListView(
                    items: adminAlerts,
                    emptyTitle: 'No Notifications',
                    emptySubtitle:
                        'Important report approvals and official admin updates will appear here.',
                    emptyIcon: Icons.notifications_off_outlined,
                    isAlertCategory: true,
                  ),
                  _buildNotificationListView(
                    items: activities,
                    emptyTitle: 'No Recent Activities',
                    emptySubtitle:
                        'Your activity history (profile updates, password changes, and report submissions) will be logged here.',
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 48,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: const Color(0xFF1E3A8A),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isRead = item['is_read'] == true;
          final visual = _notificationVisual(item, isAlertCategory);

          return GestureDetector(
            onTap: isRead ? null : () => _markAsRead(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead
                    ? Colors.white
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRead
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFBFDBFE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
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
                      color: visual.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 20),
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
                                item['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Color(0xFF94A3B8),
                            ),
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
            ),
          );
        },
      ),
    );
  }

  ({IconData icon, Color color}) _notificationVisual(
    Map<String, dynamic> item,
    bool isAlert,
  ) {
    if (isAlert) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      if (title.contains('validated')) {
        return (icon: Icons.verified_rounded, color: const Color(0xFF15803D));
      }
      if (title.contains('rejected')) {
        return (icon: Icons.cancel_outlined, color: const Color(0xFFDC2626));
      }
      return (
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFDC2626),
      );
    }

    final title = (item['title'] as String? ?? '').toLowerCase();
    if (title.contains('submitted')) {
      return (icon: Icons.send_rounded, color: const Color(0xFF1E3A8A));
    }
    if (title.contains('report updated')) {
      return (icon: Icons.edit_note_rounded, color: const Color(0xFF7C3AED));
    }
    if (title.contains('password')) {
      return (icon: Icons.lock_reset_rounded, color: const Color(0xFFB45309));
    }
    if (title.contains('profile')) {
      return (
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF0284C7),
      );
    }
    return (icon: Icons.task_alt_rounded, color: const Color(0xFF15803D));
  }

  /// Marks just the notification the citizen opened as read. Updating local
  /// state first makes the highlighted card and the Activities badge respond
  /// immediately; the database update keeps the change after a refresh.
  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final notificationId = notification['id'];
    if (notificationId == null || notification['is_read'] == true) return;

    final itemIndex = _allNotifications.indexWhere(
      (item) => item['id'] == notificationId,
    );
    if (itemIndex == -1) return;

    final previousItem = Map<String, dynamic>.from(
      _allNotifications[itemIndex],
    );
    if (mounted) {
      setState(() {
        _allNotifications[itemIndex] = {
          ..._allNotifications[itemIndex],
          'is_read': true,
        };
      });
    }

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', widget.profile.id);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      if (mounted) {
        setState(() => _allNotifications[itemIndex] = previousItem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark this activity as read. Try again.'),
          ),
        );
      }
    }
  }
}
