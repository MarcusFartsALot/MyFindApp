import 'package:flutter/material.dart';

class LoadFailureCard extends StatelessWidget {
  const LoadFailureCard({
    super.key,
    required this.onRetry,
    this.message =
        'We could not reach the service. Check your Wi-Fi or mobile data, then try again.',
  });
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5FC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Color(0xFF243C91), size: 36),
        const SizedBox(height: 12),
        const Text(
          'Unable to refresh',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
