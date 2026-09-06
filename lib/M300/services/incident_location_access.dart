import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shared permission handling. Call only when a reporting flow needs GPS.
class IncidentLocationAccess {
  /// Ask once on dashboard entry; denied users can still browse and pin manually.
  static Future<void> requestAtLogin(BuildContext context) async {
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        if (!context.mounted) return;
        final allow = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Use your location?'),
            content: const Text(
              'Location helps you pin an incident nearby. You can still browse the risk map and choose a pin manually without it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (allow == true && context.mounted) {
          await Geolocator.requestPermission();
        }
      }
    } catch (_) {
      // Permission APIs may be unavailable; manual location remains usable.
    }
  }

  static Future<bool> request(BuildContext context) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        await _settings(
          context,
          'Location is switched off',
          'Enable device location to use GPS, or continue with a manual incident pin.',
          Geolocator.openLocationSettings,
        );
      }
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever && context.mounted) {
      await _settings(
        context,
        'Location permission is disabled',
        'Allow location in app settings to use GPS. You can still choose an incident pin manually.',
        Geolocator.openAppSettings,
      );
    }
    if (permission == LocationPermission.denied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission was not granted. Choose an incident pin manually, or try Use GPS again.',
          ),
        ),
      );
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<void> _settings(
    BuildContext context,
    String title,
    String message,
    Future<bool> Function() openSettings,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Use manual pin'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            await openSettings();
          },
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
}
