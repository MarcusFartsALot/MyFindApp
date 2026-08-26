import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/incident_report_model.dart';
import '../services/community_report_service.dart';
import 'edit_report_screen.dart';

enum _TicketStatusFilter { all, pending, validated, rejected }

extension on _TicketStatusFilter {
  String get label => switch (this) {
    _TicketStatusFilter.all => 'All statuses',
    _TicketStatusFilter.pending => 'Pending Review',
    _TicketStatusFilter.validated => 'Validated',
    _TicketStatusFilter.rejected => 'Rejected',
  };

  bool matches(IncidentReportStatus status) => switch (this) {
    _TicketStatusFilter.all => true,
    _TicketStatusFilter.pending => status == IncidentReportStatus.pendingReview,
    _TicketStatusFilter.validated => status == IncidentReportStatus.validated,
    _TicketStatusFilter.rejected => status == IncidentReportStatus.rejected,
  };
}

enum _TicketTimelineFilter { all, last7Days, last30Days, last90Days, thisYear }

extension on _TicketTimelineFilter {
  String get label => switch (this) {
    _TicketTimelineFilter.all => 'All time',
    _TicketTimelineFilter.last7Days => 'Last 7 days',
    _TicketTimelineFilter.last30Days => 'Last 30 days',
    _TicketTimelineFilter.last90Days => 'Last 90 days',
    _TicketTimelineFilter.thisYear => 'This year',
  };

  bool matches(DateTime? submittedAt, DateTime now) {
    if (this == _TicketTimelineFilter.all) return true;
    if (submittedAt == null) return false;

    return switch (this) {
      _TicketTimelineFilter.all => true,
      _TicketTimelineFilter.last7Days => !submittedAt.isBefore(
        now.subtract(const Duration(days: 7)),
      ),
      _TicketTimelineFilter.last30Days => !submittedAt.isBefore(
        now.subtract(const Duration(days: 30)),
      ),
      _TicketTimelineFilter.last90Days => !submittedAt.isBefore(
        now.subtract(const Duration(days: 90)),
      ),
      _TicketTimelineFilter.thisYear => submittedAt.year == now.year,
    };
  }
}

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
  _TicketStatusFilter _statusFilter = _TicketStatusFilter.all;
  _TicketTimelineFilter _timelineFilter = _TicketTimelineFilter.all;

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

  Widget _buildStatusBadge(IncidentReportStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case IncidentReportStatus.validated:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.verified_rounded;
        break;
      case IncidentReportStatus.rejected:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_rounded;
        break;
      case IncidentReportStatus.pendingReview:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _submittedAt(Map<String, dynamic> report) {
    return DateTime.tryParse(report['created_at']?.toString() ?? '')?.toLocal();
  }

  void _clearFilters() {
    _ticketController.clear();
    setState(() {
      _statusFilter = _TicketStatusFilter.all;
      _timelineFilter = _TicketTimelineFilter.all;
    });
  }

  Future<T?> _showFilterPicker<T>({
    required String title,
    required String subtitle,
    required T selectedValue,
    required List<T> values,
    required String Function(T value) labelFor,
    required IconData icon,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: const Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...values.map((value) {
                  final selected = value == selectedValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => Navigator.of(sheetContext).pop(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  labelFor(value),
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xFF1E3A8A)
                                        : const Color(0xFF334155),
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF1E3A8A)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterSelector({
    required String caption,
    required String value,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE2E8F0),
              width: isActive ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: Color(0xFF64748B),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStatusFilter() async {
    final value = await _showFilterPicker<_TicketStatusFilter>(
      title: 'Filter by status',
      subtitle: 'Show tickets with a selected review status.',
      selectedValue: _statusFilter,
      values: _TicketStatusFilter.values,
      labelFor: (option) => option.label,
      icon: Icons.tune_rounded,
    );
    if (!mounted || value == null) return;
    setState(() => _statusFilter = value);
  }

  Future<void> _selectTimelineFilter() async {
    final value = await _showFilterPicker<_TicketTimelineFilter>(
      title: 'Filter by timeline',
      subtitle: 'Choose when the ticket was submitted.',
      selectedValue: _timelineFilter,
      values: _TicketTimelineFilter.values,
      labelFor: (option) => option.label,
      icon: Icons.date_range_rounded,
    );
    if (!mounted || value == null) return;
    setState(() => _timelineFilter = value);
  }

  /// Single Ticket Card UI
  Widget _buildReportCard(Map<String, dynamic> report) {
    final ticketId = report['ticket_id'] ?? 'N/A';
    final category = report['category'] ?? 'General Incident';
    final status = IncidentReportStatus.fromRaw(report['status']?.toString());
    final date = report['created_at'] != null
        ? DateTime.parse(
            report['created_at'],
          ).toLocal().toString().split(' ')[0]
        : 'Recent';
    final description = report['description'] ?? '';

    final isEditable = status.canEdit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ticketId,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            tooltip: 'Copy ticket ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: ticketId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ticket ID copied.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const Divider(height: 24, color: Color(0xFFE2E8F0)),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted $date',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (isEditable)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
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
                  const Text(
                    'Editing locked',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
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
    final searchQuery = _ticketController.text.trim().toLowerCase();
    final now = DateTime.now();
    final filteredReports = _myReports.where((report) {
      final ticketId = (report['ticket_id'] ?? '').toString().toLowerCase();
      final matchesTicket =
          searchQuery.isEmpty || ticketId.contains(searchQuery);
      final matchesStatus = _statusFilter.matches(
        IncidentReportStatus.fromRaw(report['status']?.toString()),
      );
      final matchesTimeline = _timelineFilter.matches(
        _submittedAt(report),
        now,
      );
      return matchesTicket && matchesStatus && matchesTimeline;
    }).toList();
    final hasActiveFilters =
        searchQuery.isNotEmpty ||
        _statusFilter != _TicketStatusFilter.all ||
        _timelineFilter != _TicketTimelineFilter.all;

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

              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Tickets',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (hasActiveFilters)
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                      label: const Text('Reset filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterSelector(
                      caption: 'Status',
                      value: _statusFilter.label,
                      icon: Icons.tune_rounded,
                      isActive: _statusFilter != _TicketStatusFilter.all,
                      onTap: _selectStatusFilter,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFilterSelector(
                      caption: 'Timeline',
                      value: _timelineFilter.label,
                      icon: Icons.date_range_rounded,
                      isActive: _timelineFilter != _TicketTimelineFilter.all,
                      onTap: _selectTimelineFilter,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // User Tickets Section Header (Cleaned up, no extra refresh icon)
              Text(
                !hasActiveFilters
                    ? 'My Submitted Tickets'
                    : 'Filtered Tickets (${filteredReports.length})',
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
                        !hasActiveFilters
                            ? 'No previous reports found'
                            : 'No tickets match the selected filters',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !hasActiveFilters
                            ? 'Reports you submit will automatically show up here.'
                            : 'Change the Ticket ID, status, or timeline filter and try again.',
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
