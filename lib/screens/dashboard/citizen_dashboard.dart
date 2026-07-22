import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class CitizenDashboard extends StatelessWidget {
  final ProfileModel profile;
  const CitizenDashboard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${profile.fullName}'),
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
      body: const Center(
        child: Text('Citizen dashboard - build local-resident features here.'),
      ),
    );
  }
}
