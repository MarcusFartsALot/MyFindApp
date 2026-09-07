import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared responsive confirmation for report actions and status updates.
class ReportFeedbackDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? ticketId;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;
  final Color accent;
  final VoidCallback onDone;
  const ReportFeedbackDialog({
    super.key,
    required this.title,
    required this.message,
    this.ticketId,
    this.primaryLabel = 'Done',
    this.secondaryLabel,
    this.onSecondary,
    this.icon = Icons.check_circle_rounded,
    this.accent = const Color(0xFF15803D),
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
              child: Icon(icon, color: accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            if (ticketId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TICKET REFERENCE NUMBER',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      ticketId!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: ticketId!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ticket ID copied to clipboard.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy ticket ID'),
                    ),
                  ],
                ),
              ),
            if (ticketId != null) const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onPressed: onDone,
                child: Text(primaryLabel, textAlign: TextAlign.center),
              ),
            ),
            if (secondaryLabel != null)
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                ),
                child: Text(secondaryLabel!),
              ),
          ],
        ),
      ),
    ),
  );
}

class ReportSuccessDialog extends StatelessWidget {
  final String ticketId;
  final VoidCallback onDone;
  const ReportSuccessDialog({
    super.key,
    required this.ticketId,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) => ReportFeedbackDialog(
    title: 'Report submitted',
    message:
        'Your incident report was submitted successfully and is pending review.',
    ticketId: ticketId,
    onDone: onDone,
  );
}
