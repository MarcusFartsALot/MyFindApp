import 'package:flutter/material.dart';
import 'report_success_dialog.dart';

/// Rejected selections are feedback about the picker, not a persistent form error.
Future<void> showEvidenceSelectionFeedback(
  BuildContext context,
  List<String> errors,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => ReportFeedbackDialog(
    title: 'Some files were not added',
    message:
        '${errors.join('\n\n')}\n\nOnly accepted files appear in your attachments. You can choose another file.',
    icon: Icons.info_outline_rounded,
    accent: const Color(0xFFB45309),
    primaryLabel: 'Got it',
    onDone: () => Navigator.of(dialogContext).pop(),
  ),
);

class EvidenceAddButton extends StatelessWidget {
  final VoidCallback onAdd;
  const EvidenceAddButton({super.key, required this.onAdd});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
        label: const Text('Add evidence'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1E3A8A),
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Photos or videos · under 10 MB each',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
    ],
  );
}

/// The same attachment row for new, saved and read-only incident evidence.
class EvidenceTile extends StatelessWidget {
  final String name;
  final String? detail;
  final VoidCallback onPreview;
  final VoidCallback? onRemove;
  const EvidenceTile({
    super.key,
    required this.name,
    this.detail,
    required this.onPreview,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final video = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
    ].contains(name.split('.').last.toLowerCase());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    video
                        ? Icons.play_circle_outline_rounded
                        : Icons.image_outlined,
                    size: 22,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [?detail, 'Tap to preview'].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: Color(0xFF64748B),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_right_rounded, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
