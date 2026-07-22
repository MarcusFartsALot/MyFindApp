import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../dashboard/tourist_dashboard.dart';
import '../dashboard/citizen_dashboard.dart';
import '../dashboard/officer_dashboard.dart';
import '../dashboard/admin_dashboard.dart';

/// Sends the signed-in user to the dashboard that matches their
/// role. This is the one place that answers "mobile app vs admin
/// website" - it's a SINGLE Flutter codebase, built for multiple
/// targets:
///
///   flutter run -d chrome              -> runs as a website (web)
///   flutter build web                  -> produces a deployable website
///   flutter build apk / flutter build ipa -> produces the mobile app
///
/// Since admins realistically work from a desk, the admin dashboard
/// only renders when kIsWeb is true. If an admin account somehow
/// logs into the mobile build, they see a message instead of a
/// squeezed-down admin UI - the intent is "admin lives on the web
/// portal", not "admin is locked out of the code".
class RoleRouter extends StatelessWidget {
  final ProfileModel profile;
  const RoleRouter({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    switch (profile.role) {
      case 'tourist':
        return TouristDashboard(profile: profile);
      case 'citizen':
        return CitizenDashboard(profile: profile);
      case 'officer':
        return OfficerDashboard(profile: profile);
      case 'admin':
        if (kIsWeb) {
          return AdminDashboard(profile: profile);
        }
        return const _AdminWebOnlyNotice();
      default:
        return const _UnknownRoleScreen();
    }
  }
}

class _AdminWebOnlyNotice extends StatelessWidget {
  const _AdminWebOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.desktop_windows_outlined, size: 48),
              SizedBox(height: 16),
              Text(
                'The admin dashboard is only available on the web portal. '
                'Please sign in from a desktop browser.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownRoleScreen extends StatelessWidget {
  const _UnknownRoleScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Your account role could not be determined.')),
    );
  }
}
