import 'package:flutter/material.dart';
import '../models/incident_report_model.dart';

/// Read-only submission log. Expansion never navigates to an editor or viewer.
class ReportLogCard extends StatelessWidget {
  const ReportLogCard({super.key, required this.report});
  final IncidentReportModel report;
  @override
  Widget build(BuildContext context) {
    final date = report.createdAt.toLocal().toString().substring(0, 16);
    final color = switch (report.statusType) {
      IncidentReportStatus.pendingReview => const Color(0xFF92400E),
      IncidentReportStatus.validated => const Color(0xFF15803D),
      IncidentReportStatus.rejected => const Color(0xFFB91C1C),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(report.id),
          tilePadding: const EdgeInsets.all(14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          trailing: const Icon(
            Icons.expand_more_rounded,
            color: Color(0xFF243C91),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.ticketId,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF243C91),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '● ${report.statusType.label}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Submitted $date',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0)),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Place · ${report.location}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Urgency · ${report.urgencyLevel}  ·  ${report.mediaPaths.length} attachments',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Submission log only. Manage your report in Track Ticket.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
