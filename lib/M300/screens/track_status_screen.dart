import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/incident_report_model.dart';
import '../services/community_report_service.dart';
import 'edit_report_screen.dart';

class TrackStatusScreen extends StatefulWidget {
  final CommunityReportService service;
  final String userEmail;
  final VoidCallback? onLogout;

  const TrackStatusScreen({
    super.key,
    required this.service,
    required this.userEmail,
    this.onLogout,
  });

  @override
  State<TrackStatusScreen> createState() => _TrackStatusScreenState();
}

class _TrackStatusScreenState extends State<TrackStatusScreen> {
  final TextEditingController _ticketController = TextEditingController();

  bool _isLoadingList = true;
  List<Map<String, dynamic>> _myReports = [];

  @override
  void initState() {
    super.initState();
    _fetchUserReports();
  }

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  /// Fetch all reports for the current user
  Future<void> _fetchUserReports() async {
    setState(() => _isLoadingList = true);
    try {
      final reports = await widget.service.getUserReports(widget.userEmail);
      if (mounted) {
        setState(() {
          _myReports = reports;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load past tickets: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  /// Status badge generator
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'resolved':
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'in progress':
      case 'under investigation':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'rejected':
      case 'dismissed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      default: // Pending / Pending Review
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Single Ticket Card UI
  Widget _buildReportCard(Map<String, dynamic> report) {
    final ticketId = report['ticket_id'] ?? 'N/A';
    final category = report['category'] ?? 'General Incident';
    final status = (report['status'] ?? 'Pending').toString();
    final date = report['created_at'] != null
        ? DateTime.parse(
      report['created_at'],
    ).toLocal().toString().split(' ')[0]
        : 'Recent';
    final description = report['description'] ?? '';

    // Check if status allows editing
    final isEditable =
        status.toLowerCase() == 'pending' ||
            status.toLowerCase() == 'pending review';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      ticketId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ticketId));
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 6),
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Submitted: $date',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                if (isEditable)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.edit_note,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    ),
                    label: const Text(
                      'Edit Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    onPressed: () async {
                      final model = IncidentReportModel.fromJson(report);
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditReportScreen(
                            report: model,
                            service: widget.service,
                          ),
                        ),
                      );
                      _fetchUserReports();
                    },
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live "LIKE" search filter
    final searchQuery = _ticketController.text.trim().toLowerCase();
    final filteredReports = _myReports.where((report) {
      if (searchQuery.isEmpty) return true;
      final ticketId = (report['ticket_id'] ?? '').toString().toLowerCase();
      return ticketId.contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Track Report Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.onLogout != null)
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, color: Color(0xFF0F172A)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUserReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Ticket ID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Type any digits or characters to filter your tickets instantly.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Live Search Field
              TextField(
                controller: _ticketController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by Ticket ID (e.g. REP-6710)...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0F172A),
                  ),
                  suffixIcon: _ticketController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () {
                      _ticketController.clear();
                      setState(() {});
                    },
                  )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E3A8A),
                      width: 1.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // User Tickets Section Header (Cleaned up, no extra refresh icon)
              Text(
                searchQuery.isEmpty
                    ? 'My Submitted Tickets'
                    : 'Matching Tickets (${filteredReports.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingList)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  ),
                )
              else if (filteredReports.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.inbox_outlined,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        searchQuery.isEmpty
                            ? 'No previous reports found'
                            : 'No tickets found matching "$searchQuery"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        searchQuery.isEmpty
                            ? 'Reports you submit will automatically show up here.'
                            : 'Try searching with a different ticket ID fragment.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) {
                    return _buildReportCard(filteredReports[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}