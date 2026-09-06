import '../widgets/report_log_card.dart';
import '../widgets/load_failure_card.dart';
import 'package:flutter/material.dart';

// Module Imports
import 'package:my_find/M400/models/profile_model.dart';
import 'package:my_find/M300/services/community_report_service.dart';
import 'package:my_find/M300/models/incident_report_model.dart';
import 'package:my_find/M300/widgets/edge_swipe_back.dart';

class ReportHistoryScreen extends StatefulWidget {
  final ProfileModel profile;
  final CommunityReportService service;

  const ReportHistoryScreen({
    super.key,
    required this.profile,
    required this.service,
  });

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  bool _isLoading = false;
  bool _loadFailed = false;
  List<IncidentReportModel> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  /// Fetches past reports using getUserReports from CommunityReportService
  Future<void> _fetchReports() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final List<Map<String, dynamic>> rawReports = await widget.service
          .getUserReports(widget.profile.email)
          .timeout(const Duration(seconds: 15));

      final reports = rawReports
          .map((data) => IncidentReportModel.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reports: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Report History',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
          ),
        ),
        body: RefreshIndicator(
          color: const Color(0xFF1E3A8A),
          onRefresh: _fetchReports,
          child: _isLoading
              ? const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 400,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                )
              : _loadFailed
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: LoadFailureCard(onRetry: _fetchReports),
                )
              : _reports.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 120,
                    child: _buildEmptyState(),
                  ),
                )
              : _buildReportList(),
        ),
      ),
    );
  }

  /// Empty state UI when no past reports are found
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 56,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No reports yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your submitted incident reports will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList() => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(14),
    itemCount: _reports.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, index) => ReportLogCard(report: _reports[index]),
  );
}
