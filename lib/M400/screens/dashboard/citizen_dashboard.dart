import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_find/M400/models/profile_model.dart';

import 'package:my_find/M300/services/community_report_service.dart';
import 'package:my_find/M300/screens/report_history_screen.dart';
import 'package:my_find/M300/screens/risk_map_screen.dart';
import 'package:my_find/M300/screens/submit_report_screen.dart';
import 'package:my_find/M300/screens/track_status_screen.dart';
import 'package:my_find/M300/screens/me_screen.dart';
import 'package:my_find/M300/screens/notifications_screen.dart';

class CitizenDashboard extends StatefulWidget {
  final ProfileModel profile;

  const CitizenDashboard({super.key, required this.profile});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _selectedIndex = 0;
  late ProfileModel _currentProfile;
  late final CommunityReportService _reportService;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _reportService = CommunityReportService();
  }

  /// Refreshes profile state from database
  Future<void> _refreshProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('auth_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _currentProfile = ProfileModel.fromRecords(profileData, null);
        });
      }
    } catch (e) {
      debugPrint("Error refreshing profile: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      const RiskMapScreen(),
      TrackStatusScreen(
        service: _reportService,
        userEmail: _currentProfile.email,
      ),
      MeScreen(profile: _currentProfile, onProfileUpdated: _refreshProfile),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MyFind',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'CITIZEN DASHBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            // Dynamic Notification Bell with Unread Badge Indicator
            _DynamicNotificationBell(profile: _currentProfile),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Container(
            key: ValueKey<int>(_selectedIndex),
            child: screens[_selectedIndex],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF1E3A8A),
            unselectedItemColor: const Color(0xFF94A3B8),
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                activeIcon: Icon(Icons.grid_view_rounded),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map_rounded),
                label: 'Risk Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.track_changes_outlined),
                activeIcon: Icon(Icons.track_changes_rounded),
                label: 'Track Ticket',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the main Citizen Overview Tab
  Widget _buildHomeTab() {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(20.0),
      children: [
        // Greeting Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  _currentProfile.nickname ?? _currentProfile.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF15803D)),
                  SizedBox(width: 4),
                  Text(
                    'CITIZEN VERIFIED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Gradient Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentProfile.fullName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentProfile.email,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _passDetail(
                    'PHONE',
                    _currentProfile.phoneNumber ?? 'NOT PROVIDED',
                  ),
                  _passDetail('ROLE', _currentProfile.role.toUpperCase()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Portal Section Header
        const Text(
          'Community Reporting Portal',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        // Risk Map is the primary community-wide information view.
        _AnimatedActionCard(
          title: 'Community Risk Map',
          subtitle: 'Explore validated incident zones across Kuala Lumpur',
          icon: Icons.map_outlined,
          color: const Color(0xFF7C3AED),
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(height: 12),

        // Action Card 1: Submit Report
        _AnimatedActionCard(
          title: 'Report an Incident',
          subtitle: 'Submit unauthorized employment or visa violation reports',
          icon: Icons.error_outline_rounded,
          color: const Color(0xFF1E3A8A),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubmitReportScreen(
                  profile: _currentProfile,
                  service: _reportService,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Action Card 2: Track Ticket
        _AnimatedActionCard(
          title: 'Track Ticket Status',
          subtitle: 'Check progress and updates on your submitted reports',
          icon: Icons.track_changes_rounded,
          color: const Color(0xFF0284C7),
          onTap: () => setState(() => _selectedIndex = 2),
        ),
        const SizedBox(height: 12),

        // Action Card 3: Report History Screen
        _AnimatedActionCard(
          title: 'My Report History',
          subtitle:
              'Review past incident submissions and administrative status',
          icon: Icons.manage_search_rounded,
          color: const Color(0xFF059669),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportHistoryScreen(
                  profile: _currentProfile,
                  service: _reportService,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _passDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Keeps the unread badge live and surfaces newly-arrived administrative
/// alerts as an in-app MyFind dialog while the citizen is using the app.
class _DynamicNotificationBell extends StatefulWidget {
  final ProfileModel profile;

  const _DynamicNotificationBell({required this.profile});

  @override
  State<_DynamicNotificationBell> createState() =>
      _DynamicNotificationBellState();
}

class _DynamicNotificationBellState extends State<_DynamicNotificationBell> {
  final _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _pendingPopups = [];
  final Set<String> _knownNotificationIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> _notifications = const [];
  bool _receivedInitialSnapshot = false;
  bool _showingPopup = false;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  @override
  void didUpdateWidget(covariant _DynamicNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _subscription?.cancel();
      _knownNotificationIds.clear();
      _pendingPopups.clear();
      _notifications = const [];
      _receivedInitialSnapshot = false;
      _subscribeToNotifications();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    _subscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.profile.id)
        .listen(
          _handleNotificationSnapshot,
          onError: (Object error) {
            debugPrint('Citizen notification stream error: $error');
          },
        );
  }

  void _handleNotificationSnapshot(List<Map<String, dynamic>> data) {
    final notifications = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) {
        final first = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final second = DateTime.tryParse(b['created_at']?.toString() ?? '');
        return (second ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          first ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });

    if (!_receivedInitialSnapshot) {
      _receivedInitialSnapshot = true;
      _knownNotificationIds.addAll(
        notifications.map((item) => item['id']?.toString() ?? ''),
      );
    } else {
      final newAlerts = notifications.where((item) {
        final id = item['id']?.toString() ?? '';
        return id.isNotEmpty &&
            !_knownNotificationIds.contains(id) &&
            item['is_read'] == false &&
            item['type'] == 'Alert';
      }).toList();

      _knownNotificationIds.addAll(
        notifications.map((item) => item['id']?.toString() ?? ''),
      );
      _pendingPopups.addAll(newAlerts.reversed);
    }

    if (mounted) {
      setState(() => _notifications = notifications);
      _showNextPopup();
    }
  }

  Future<void> _showNextPopup() async {
    if (_showingPopup || _pendingPopups.isEmpty || !mounted) return;
    _showingPopup = true;
    final notification = _pendingPopups.removeAt(0);
    final title = notification['title']?.toString() ?? 'Report update';
    final message =
        notification['message']?.toString() ??
        'There is a new update to one of your reports.';
    final isRejected = title.toLowerCase().contains('reject');
    final accent = isRejected
        ? const Color(0xFFDC2626)
        : const Color(0xFF15803D);
    final icon = isRejected ? Icons.cancel_rounded : Icons.verified_rounded;

    final openNotifications = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: const Text('View notifications'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Later'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (openNotifications == true && mounted) {
      await _markAsRead(notification);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(profile: widget.profile),
        ),
      );
    }

    _showingPopup = false;
    if (mounted && _pendingPopups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNextPopup());
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = notification['id'];
    if (id == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', widget.profile.id);
    } catch (error) {
      debugPrint('Could not mark popup notification as read: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((item) => item['is_read'] == false);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(profile: widget.profile),
              ),
            );
          },
        ),
        if (hasUnread)
          Positioned(
            right: 10,
            bottom: 12,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
