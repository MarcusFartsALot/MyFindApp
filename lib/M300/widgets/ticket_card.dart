import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/incident_report_model.dart';

class TicketCard extends StatelessWidget {
  final String ticketId, category, description, date;
  final IncidentReportStatus status;
  final VoidCallback? onOpen;
  const TicketCard({
    super.key,
    required this.ticketId,
    required this.category,
    required this.description,
    required this.date,
    required this.status,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      IncidentReportStatus.pendingReview => const Color(0xFF92400E),
      IncidentReportStatus.validated => const Color(0xFF15803D),
      IncidentReportStatus.rejected => const Color(0xFFB91C1C),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticketId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy ticket ID',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: ticketId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ticket ID copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 17),
              ),
            ],
          ),
          Text(
            category,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '● ${status.label}',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: Icon(
                status.canEdit
                    ? Icons.edit_outlined
                    : Icons.visibility_outlined,
                size: 17,
              ),
              label: Text(
                status.canEdit ? 'Edit report' : 'View details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
