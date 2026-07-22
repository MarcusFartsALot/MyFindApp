import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

/// Web-only admin shell (see role_router.dart for the gating logic).
/// Uses a NavigationRail since admins will always be on a
/// desktop-width browser window.
class AdminDashboard extends StatefulWidget {
  final ProfileModel profile;
  const AdminDashboard({super.key, required this.profile});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  static const _sections = [
    'Overview',
    'Pending Verifications',
    'Users',
    'Officers & Roles',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - ${widget.profile.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: _sections
                .map((s) => NavigationRailDestination(
                      icon: const Icon(Icons.circle_outlined),
                      selectedIcon: const Icon(Icons.circle),
                      label: Text(s),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: Text('${_sections[_selectedIndex]} - build this section out next.'),
            ),
          ),
        ],
      ),
    );
  }
}
