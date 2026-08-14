import 'package:flutter/material.dart';

import 'package:my_find/M400/models/profile_model.dart';
import 'package:my_find/M400/services/auth_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/citizen_dashboard.dart';
import '../dashboard/tourist_dashboard.dart';

class RoleRouter extends StatelessWidget {
  final ProfileModel profile;

  const RoleRouter({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    switch (profile.role) {
      case 'citizen':
        if (!profile.isApproved) {
          return const _PortalOnlyNotice(
            message: 'This Citizen account is not approved for mobile access.',
          );
        }
        return CitizenDashboard(profile: profile);
      case 'tourist':
        if (!profile.isApproved) {
          return const _PortalOnlyNotice(
            message: 'This Tourist account is not approved for mobile access.',
          );
        }
        return TouristDashboard(profile: profile);
      case 'admin':
        return const _PortalOnlyNotice(
          message: 'Administrator accounts must use the Admin Portal.',
        );
      default:
        return const _PortalOnlyNotice(
          message: 'This account role cannot use the mobile application.',
        );
    }
  }
}

class _PortalOnlyNotice extends StatelessWidget {
  final String message;

  const _PortalOnlyNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 52),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
