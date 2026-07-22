import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../auth/login_screen.dart';

/// Where officers review tourist applications submitted with
/// passport documents - the "approval" side of requirement #3.
class OfficerDashboard extends StatefulWidget {
  final ProfileModel profile;
  const OfficerDashboard({super.key, required this.profile});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  final _profileService = ProfileService();
  late Future<List<ProfileModel>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _profileService.fetchPendingTourists();
  }

  void _refresh() {
    setState(() => _pendingFuture = _profileService.fetchPendingTourists());
  }

  Future<void> _approve(ProfileModel p) async {
    try {
      await _profileService.approveTourist(p.id);
      _refresh();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _reject(ProfileModel p) async {
    final reason = await _promptReason();
    if (reason == null || reason.isEmpty) return;
    try {
      await _profileService.rejectTourist(p.id, reason: reason);
      _refresh();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<String?> _promptReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Officer - ${widget.profile.fullName}'),
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
      body: FutureBuilder<List<ProfileModel>>(
        future: _pendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final pending = snapshot.data ?? [];
          if (pending.isEmpty) {
            return const Center(child: Text('No pending applications.'));
          }
          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final p = pending[i];
              return ListTile(
                title: Text(p.fullName),
                subtitle: Text('${p.nationality ?? ''} - Passport ${p.passportNo ?? ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => _approve(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      onPressed: () => _reject(p),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
