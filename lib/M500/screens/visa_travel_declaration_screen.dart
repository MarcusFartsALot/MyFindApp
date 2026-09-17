import 'package:flutter/material.dart';
import 'package:my_find/M500/models/visa_travel_models.dart';
import 'package:my_find/M500/services/visa_travel_service.dart';

class VisaTravelDeclarationScreen
    extends StatefulWidget {
  final String profileId;

  const VisaTravelDeclarationScreen({
    super.key,
    required this.profileId,
  });

  @override
  State<VisaTravelDeclarationScreen>
  createState() =>
      _VisaTravelDeclarationScreenState();
}

class _VisaTravelDeclarationScreenState
    extends State<VisaTravelDeclarationScreen> {
  final VisaTravelService _travelService =
  VisaTravelService();

  bool _isLoading = true;
  bool _isSubmitting = false;

  String? _errorMessage;

  VisaTravelContext? _travelContext;

  @override
  void initState() {
    super.initState();

    _loadTravelContext();
  }
// Load

  Future<void> _loadTravelContext() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final context =
      await _travelService
          .getTravelContext(
        widget.profileId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _travelContext = context;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
// Build

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Travel Declaration',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.w800,
            color:
            Color(0xFF0F172A),
          ),
        ),
        backgroundColor:
        Colors.white,
        foregroundColor:
        const Color(0xFF0F172A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize:
          const Size.fromHeight(1),
          child: Container(
            height: 1,
            color:
            const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh:
        _loadTravelContext,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding:
        const EdgeInsets.all(20),
        children: [
          _buildErrorCard(
            _errorMessage!,
          ),
          const SizedBox(
            height: 16,
          ),
          SizedBox(
            height: 48,
            child:
            ElevatedButton.icon(
              onPressed:
              _loadTravelContext,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text(
                'Try Again',
              ),
            ),
          ),
        ],
      );
    }

    final travelContext =
        _travelContext;

    if (travelContext == null ||
        travelContext.visa == null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(20),
        children: [
          _buildNoVisaCard(),
        ],
      );
    }

    final visa =
    travelContext.visa!;

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(
        parent:
        BouncingScrollPhysics(),
      ),
      padding:
      const EdgeInsets.all(20),
      children: [
        _buildVisaCard(
          visa,
          travelContext,
        ),

        const SizedBox(
          height: 16,
        ),

        _buildPlannedTravelCard(
          visa,
          travelContext.plannedTravel,
        ),

        const SizedBox(
          height: 16,
        ),

        _buildCurrentTravelSection(
          visa,
          travelContext,
        ),

        if (travelContext
            .records.isNotEmpty) ...[
          const SizedBox(
            height: 24,
          ),
          _buildTravelHistory(
            travelContext,
          ),
        ],

        const SizedBox(
          height: 30,
        ),
      ],
    );
  }
// Visa Card

  Widget _buildVisaCard(
      VisaTravelVisa visa,
      VisaTravelContext travelContext,
      ) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
            const Color(0xFF1E3A8A)
                .withValues(alpha: 0.18),
            blurRadius: 18,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.all(8),
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.12),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child:
                const Icon(
                  Icons
                      .verified_user_rounded,
                  color:
                  Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Text(
                      'CURRENT VISA',
                      style:
                      TextStyle(
                        color:
                        Colors.white60,
                        fontSize:
                        10,
                        fontWeight:
                        FontWeight
                            .w700,
                        letterSpacing:
                        1,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      visa.visaType,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        19,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStateBadge(
                travelContext.state,
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child:
                _visaDetail(
                  'EFFECTIVE',
                  _formatDate(
                    visa.effectiveDate,
                  ),
                ),
              ),
              Expanded(
                child:
                _visaDetail(
                  'VALID UNTIL',
                  _formatDate(
                    visa.expiryDate,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          _visaDetail(
            'REFERENCE',
            visa.referenceId,
          ),
        ],
      ),
    );
  }

  Widget _visaDetail(
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
          const TextStyle(
            color:
            Colors.white54,
            fontSize: 9,
            fontWeight:
            FontWeight.w700,
            letterSpacing:
            0.6,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          value,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 13,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

// ============================================================
// PLANNED TRAVEL
// SOURCE: visa_submissions
// ============================================================

  Widget _buildPlannedTravelCard(
      VisaTravelVisa visa,
      PlannedTravelInformation? plannedTravel,
      ) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.event_note_rounded,
            title: 'Planned Travel',
          ),
          const SizedBox(height: 18),

          _informationRow(
            'Planned Arrival',
            visa.plannedArrivalDate == null
                ? 'Not available'
                : _formatDate(
              visa.plannedArrivalDate!,
            ),
          ),

          _informationRow(
            'Planned Departure',
            visa.plannedDepartureDate == null
                ? 'Not available'
                : _formatDate(
              visa.plannedDepartureDate!,
            ),
          ),

          if (plannedTravel != null) ...[
            if (plannedTravel.inferredMethod != null)
              _informationRow(
                'Planned Method',
                plannedTravel.inferredMethod!,
              ),

            if ((plannedTravel.airline ?? '').isNotEmpty)
              _informationRow(
                'Airline',
                plannedTravel.airline!,
              ),

            if ((plannedTravel.flightNumber ?? '').isNotEmpty)
              _informationRow(
                'Flight Number',
                plannedTravel.flightNumber!,
              ),

            if ((plannedTravel.intendedDestination ?? '')
                .isNotEmpty)
              _informationRow(
                'Destination',
                plannedTravel.intendedDestination!,
              ),

            if ((plannedTravel.hotelName ?? '').isNotEmpty)
              _informationRow(
                'Accommodation',
                plannedTravel.hotelName!,
              ),

            if ((plannedTravel.accommodationType ?? '')
                .isNotEmpty)
              _informationRow(
                'Accommodation Type',
                plannedTravel.accommodationType!,
              ),

            if ((plannedTravel.hotelAddress ?? '').isNotEmpty)
              _informationRow(
                'Address',
                plannedTravel.hotelAddress!,
              ),
          ],

          const SizedBox(height: 2),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: Color(0xFF64748B),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Planned arrival and departure dates come from the verified AI Visa Application PDF. Additional travel information is read from the original application and is not modified here.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Current Travel State

  Widget _buildCurrentTravelSection(
      VisaTravelVisa visa,
      VisaTravelContext travelContext,
      ) {
    switch (
    travelContext.state) {
      case VisaTravelState.notEntered:
        return _buildNotEnteredCard(
          visa,
        );

      case VisaTravelState.active:
      case VisaTravelState
          .expiringSoon:
      case VisaTravelState
          .departureNotReported:
        return _buildActiveStayCard(
          visa,
          travelContext,
        );

      case VisaTravelState.departed:
        return _buildDepartedMEVCard(
          visa,
        );

      case VisaTravelState.used:
        return _buildUsedSEVCard();

      case VisaTravelState.expired:
        return _buildExpiredCard(
          visa,
          travelContext,
        );

      case VisaTravelState.noVisa:
        return _buildNoVisaCard();
    }
  }
// Not Entered

  Widget _buildNotEnteredCard(
      VisaTravelVisa visa,
      ) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon:
            Icons.flight_land_rounded,
            title:
            'Travel Declaration',
          ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            'No arrival has been reported for this visa.',
            style:
            TextStyle(
              fontSize:
              14,
              fontWeight:
              FontWeight.w600,
              color:
              Color(
                0xFF0F172A,
              ),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Report your actual arrival after entering Malaysia.',
            style:
            TextStyle(
              fontSize:
              12,
              height:
              1.5,
              color:
              Color(
                0xFF64748B,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width:
            double.infinity,
            height: 48,
            child:
            ElevatedButton.icon(
              onPressed:
              _isSubmitting
                  ? null
                  : () {
                _showArrivalForm(
                  visa,
                );
              },
              icon:
              const Icon(
                Icons.login_rounded,
              ),
              label:
              const Text(
                'Report Arrival',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                const Color(
                  0xFF1E3A8A,
                ),
                foregroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
// Active Stay

  Widget _buildActiveStayCard(
      VisaTravelVisa visa,
      VisaTravelContext travelContext,
      ) {
    final record =
        travelContext
            .currentOpenRecord;

    if (record == null) {
      return _buildNotEnteredCard(
        visa,
      );
    }

    final remaining =
        travelContext
            .remainingDays ??
            0;

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon:
            Icons.schedule_rounded,
            title:
            'Current Stay',
          ),

          const SizedBox(
            height: 20,
          ),

          if (travelContext.state ==
              VisaTravelState
                  .departureNotReported)
            _warningBox(
              'Departure has not been reported after the permitted stay deadline.',
            )
          else
            _remainingDaysCard(
              remaining,
              travelContext.state,
            ),

          const SizedBox(
            height: 20,
          ),

          _informationRow(
            'Actual Arrival',
            _formatDateTime(
              record.actualEntryAt,
            ),
          ),

          _informationRow(
            'Entry Method',
            record.entryMethod,
          ),

          _informationRow(
            'Entry Point',
            record.entryPoint,
          ),

          if ((record.entryReference ??
              '')
              .isNotEmpty)
            _informationRow(
              'Reference',
              record.entryReference!,
            ),

          _informationRow(
            'Permitted Stay Until',
            _formatDate(
              record.stayUntilDate,
            ),
          ),

          if ((record.entryChangeReason ??
              '')
              .isNotEmpty)
            _informationRow(
              'Entry Change Reason',
              record.entryChangeReason!,
            ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width:
            double.infinity,
            height: 48,
            child:
            ElevatedButton.icon(
              onPressed:
              _isSubmitting
                  ? null
                  : () {
                _showDepartureForm(
                  visa,
                  record,
                );
              },
              icon:
              const Icon(
                Icons.logout_rounded,
              ),
              label:
              const Text(
                'Report Departure',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                const Color(
                  0xFF1E3A8A,
                ),
                foregroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
// Mev Departed

  Widget _buildDepartedMEVCard(
      VisaTravelVisa visa,
      ) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon:
            Icons.repeat_rounded,
            title:
            'Travel Declaration',
          ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            'Your previous journey has been completed.',
            style:
            TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),
              fontSize:
              14,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Your MEV remains valid until ${_formatDate(visa.expiryDate)}. '
                'You can report another arrival when you enter Malaysia again.',
            style:
            const TextStyle(
              color:
              Color(
                0xFF64748B,
              ),
              fontSize:
              12,
              height:
              1.5,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width:
            double.infinity,
            height: 48,
            child:
            ElevatedButton.icon(
              onPressed:
              _isSubmitting
                  ? null
                  : () {
                _showArrivalForm(
                  visa,
                );
              },
              icon:
              const Icon(
                Icons
                    .flight_land_rounded,
              ),
              label:
              const Text(
                'Report New Arrival',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                const Color(
                  0xFF1E3A8A,
                ),
                foregroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
// Used Sev

  Widget _buildUsedSEVCard() {
    return _sectionCard(
      child:
      const Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .task_alt_rounded,
                color:
                Color(
                  0xFF1E3A8A,
                ),
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                'Journey Completed',
                style:
                TextStyle(
                  fontSize:
                  15,
                  fontWeight:
                  FontWeight
                      .w800,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            'This single-entry visa has been used. '
                'Your previous travel declaration remains available in Travel History below.',
            style:
            TextStyle(
              color:
              Color(
                0xFF64748B,
              ),
              fontSize:
              12,
              height:
              1.5,
            ),
          ),
        ],
      ),
    );
  }
// Expired

  Widget _buildExpiredCard(
      VisaTravelVisa visa,
      VisaTravelContext travelContext,
      ) {
    final canReportHistoricalArrival =
        travelContext.records.isEmpty;

    return _sectionCard(
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Visa Expired',
            style:
            TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),
              fontSize:
              15,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            'This visa is expired. Existing travel records remain available below.',
            style:
            TextStyle(
              color:
              Color(
                0xFF64748B,
              ),
              fontSize:
              12,
              height:
              1.5,
            ),
          ),
          if (canReportHistoricalArrival) ...[
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              width:
              double.infinity,
              height: 48,
              child:
              ElevatedButton.icon(
                onPressed:
                _isSubmitting
                    ? null
                    : () {
                  _showArrivalForm(
                    visa,
                  );
                },
                icon:
                const Icon(
                  Icons.login_rounded,
                ),
                label:
                const Text(
                  'Report Historical Arrival',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF1E3A8A,
                  ),
                  foregroundColor:
                  Colors.white,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
// Travel History

  Widget _buildTravelHistory(
      VisaTravelContext travelContext,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Travel History',
          style:
          TextStyle(
            color:
            Color(
              0xFF0F172A,
            ),
            fontSize:
            16,
            fontWeight:
            FontWeight.w800,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        ...List.generate(
          travelContext
              .records.length,
              (index) {
            final record =
            travelContext
                .records[index];

            final tripNumber =
                travelContext
                    .records.length -
                    index;

            return Padding(
              padding:
              const EdgeInsets.only(
                bottom: 12,
              ),
              child:
              _sectionCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trip #$tripNumber',
                          style:
                          const TextStyle(
                            fontSize:
                            14,
                            fontWeight:
                            FontWeight
                                .w800,
                            color:
                            Color(
                              0xFF0F172A,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          record.isOpen
                              ? 'CURRENT'
                              : 'COMPLETED',
                          style:
                          TextStyle(
                            fontSize:
                            9,
                            fontWeight:
                            FontWeight
                                .w800,
                            color: record
                                .isOpen
                                ? const Color(
                              0xFF15803D,
                            )
                                : const Color(
                              0xFF1E3A8A,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _informationRow(
                      'Arrival',
                      _formatDateTime(
                        record
                            .actualEntryAt,
                      ),
                    ),

                    _informationRow(
                      'Entry',
                      '${record.entryMethod} · ${record.entryPoint}',
                    ),

                    if ((record
                        .entryReference ??
                        '')
                        .isNotEmpty)
                      _informationRow(
                        'Entry Reference',
                        record
                            .entryReference!,
                      ),

                    if (record
                        .actualDepartureAt !=
                        null)
                      _informationRow(
                        'Departure',
                        _formatDateTime(
                          record
                              .actualDepartureAt!,
                        ),
                      ),

                    if ((record.departureMethod ??
                        '')
                        .isNotEmpty &&
                        (record.departurePoint ??
                            '')
                            .isNotEmpty)
                      _informationRow(
                        'Exit',
                        '${record.departureMethod} · ${record.departurePoint}',
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
// Arrival Form

  Future<void> _showArrivalForm(
      VisaTravelVisa visa,
      ) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final plannedTravel = _travelContext?.plannedTravel;
    final String? plannedMethod = plannedTravel?.inferredMethod;
    final String? plannedPoint = null;
    final String? plannedReference = plannedTravel?.transportReference;

    String method = plannedMethod ?? 'AIR';

    final pointController = TextEditingController();
    final referenceController = TextEditingController(
      text: plannedReference ?? '',
    );
    final reasonController = TextEditingController();

    bool requiresReason = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
              modalContext,
              setModalState,
              ) {
            void checkDifference() {
              final changed =
              _travelService
                  .hasSignificantTravelChange(
                plannedMethod:
                plannedMethod,
                actualMethod:
                method,
                plannedPoint:
                plannedPoint,
                actualPoint:
                pointController.text,
              );

              setModalState(() {
                requiresReason =
                    changed;
              });
            }

            return _formSheet(
              title:
              'Report Actual Arrival',
              icon:
              Icons.flight_land_rounded,
              child: Column(
                children: [
                  _plannedDateBox(
                    label:
                    'Planned Arrival',
                    date: visa
                        .plannedArrivalDate,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  _dateTimeSelector(
                    label:
                    'Actual Arrival',
                    date:
                    selectedDate,
                    time:
                    selectedTime,
                    onDatePressed:
                        () async {
                      final now =
                      DateTime.now();

                      var firstDate =
                          visa.effectiveDate;

                      var lastDate =
                      visa.expiryDate
                          .isBefore(
                        now,
                      )
                          ? visa
                          .expiryDate
                          : now;

                      if (firstDate
                          .isAfter(
                        lastDate,
                      )) {
                        return;
                      }

                      var initialDate =
                          selectedDate;

                      if (initialDate
                          .isBefore(
                        firstDate,
                      )) {
                        initialDate =
                            firstDate;
                      }

                      if (initialDate
                          .isAfter(
                        lastDate,
                      )) {
                        initialDate =
                            lastDate;
                      }

                      final selected =
                      await showDatePicker(
                        context:
                        modalContext,
                        initialDate:
                        initialDate,
                        firstDate:
                        firstDate,
                        lastDate:
                        lastDate,
                      );

                      if (!modalContext.mounted) {
                        return;
                      }

                      if (selected !=
                          null) {
                        setModalState(
                              () {
                            selectedDate =
                                selected;
                          },
                        );
                      }
                    },
                    onTimePressed:
                        () async {
                      final selected =
                      await showTimePicker(
                        context:
                        modalContext,
                        initialTime:
                        selectedTime,
                      );

                      if (!modalContext.mounted) {
                        return;
                      }

                      if (selected !=
                          null) {
                        final candidate =
                        DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selected.hour,
                          selected.minute,
                        );

                        if (candidate.isAfter(
                          DateTime.now(),
                        )) {
                          await _showFormErrorDialog(
                            modalContext,
                            'Actual arrival time cannot be in the future.',
                          );
                          return;
                        }

                        if (!modalContext.mounted) {
                          return;
                        }

                        setModalState(
                              () {
                            selectedTime =
                                selected;
                          },
                        );
                      }
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _methodDropdown(
                    value:
                    method,
                    label:
                    'Actual Entry Method',
                    onChanged:
                        (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setModalState(
                            () {
                          method =
                              value;
                        },
                      );

                      checkDifference();
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  _textField(
                    controller:
                    pointController,
                    label:
                    'Actual Entry Point',
                    hint:
                    'e.g. KLIA / Johor Bahru CIQ / Port Klang',
                    icon:
                    Icons
                        .location_on_outlined,
                    onChanged:
                        (_) {
                      checkDifference();
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  _textField(
                    controller:
                    referenceController,
                    label:
                    'Transport Reference',
                    hint:
                    'e.g. MH123 / vehicle / vessel reference',
                    icon:
                    Icons
                        .confirmation_number_outlined,
                  ),

                  if (requiresReason) ...[
                    const SizedBox(
                      height: 14,
                    ),
                    _textField(
                      controller:
                      reasonController,
                      label:
                      'Reason for Change',
                      hint:
                      'Explain why the actual travel method or point changed',
                      icon:
                      Icons.edit_note_rounded,
                      maxLines: 3,
                    ),
                  ],

                  const SizedBox(
                    height: 22,
                  ),

                  _submitButton(
                    label:
                    'Confirm Arrival',
                    icon:
                    Icons.check_rounded,
                    onPressed:
                        () async {
                      final entryAt =
                      DateTime(
                        selectedDate
                            .year,
                        selectedDate
                            .month,
                        selectedDate
                            .day,
                        selectedTime
                            .hour,
                        selectedTime
                            .minute,
                      );

                      try {
                        if (!mounted ||
                            !modalContext.mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          true;
                        });

                        setModalState(() {});

                        await _travelService
                            .reportArrival(
                          submissionId:
                          visa.submissionId,
                          actualEntryAt:
                          entryAt,
                          entryMethod:
                          method,
                          entryPoint:
                          pointController
                              .text,
                          entryReference:
                          referenceController
                              .text,
                          plannedEntryMethod:
                          plannedMethod,
                          plannedEntryPoint:
                          plannedPoint,
                          entryChangeReason:
                          reasonController
                              .text,
                        );

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          false;
                        });

                        if (modalContext.mounted) {
                          Navigator.pop(
                            modalContext,
                          );
                        }

                        if (!mounted) {
                          return;
                        }

                        await _loadTravelContext();

                        if (!mounted) {
                          return;
                        }

                        _showSuccess(
                          'Arrival reported successfully.',
                        );
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          false;
                        });

                        if (!modalContext.mounted) {
                          return;
                        }

                        setModalState(() {});

                        await _showFormErrorDialog(
                          modalContext,
                          _cleanError(
                            e,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
// Departure Form

  Future<void> _showDepartureForm(
      VisaTravelVisa visa,
      VisaTravelRecord record,
      ) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final plannedTravel = _travelContext?.plannedTravel;
    final String? plannedMethod = plannedTravel?.inferredMethod;
    final String? plannedPoint = null;
    final String? plannedReference = plannedTravel?.transportReference;

    String method = plannedMethod ?? 'AIR';

    final pointController = TextEditingController();
    final referenceController = TextEditingController(
      text: plannedReference ?? '',
    );
    final reasonController = TextEditingController();

    bool requiresReason = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
              modalContext,
              setModalState,
              ) {
            void checkDifference() {
              final changed =
              _travelService
                  .hasSignificantTravelChange(
                plannedMethod:
                plannedMethod,
                actualMethod:
                method,
                plannedPoint:
                plannedPoint,
                actualPoint:
                pointController.text,
              );

              setModalState(() {
                requiresReason =
                    changed;
              });
            }

            return _formSheet(
              title:
              'Report Actual Departure',
              icon:
              Icons
                  .flight_takeoff_rounded,
              child: Column(
                children: [
                  _plannedDateBox(
                    label:
                    'Planned Departure',
                    date: visa
                        .plannedDepartureDate,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  _dateTimeSelector(
                    label:
                    'Actual Departure',
                    date:
                    selectedDate,
                    time:
                    selectedTime,
                    onDatePressed:
                        () async {
                      final now =
                      DateTime.now();

                      final firstDate =
                      DateTime(
                        record
                            .actualEntryAt
                            .year,
                        record
                            .actualEntryAt
                            .month,
                        record
                            .actualEntryAt
                            .day,
                      );

                      final selected =
                      await showDatePicker(
                        context:
                        modalContext,
                        initialDate:
                        selectedDate,
                        firstDate:
                        firstDate,
                        lastDate:
                        now,
                      );

                      if (!modalContext.mounted) {
                        return;
                      }

                      if (selected !=
                          null) {
                        setModalState(
                              () {
                            selectedDate =
                                selected;
                          },
                        );
                      }
                    },
                    onTimePressed:
                        () async {
                      final selected =
                      await showTimePicker(
                        context:
                        modalContext,
                        initialTime:
                        selectedTime,
                      );

                      if (!modalContext.mounted) {
                        return;
                      }

                      if (selected !=
                          null) {
                        final candidate =
                        DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selected.hour,
                          selected.minute,
                        );

                        if (candidate.isBefore(
                          record.actualEntryAt,
                        )) {
                          await _showFormErrorDialog(
                            modalContext,
                            'Departure cannot be earlier than arrival.',
                          );
                          return;
                        }

                        if (candidate.isAfter(
                          DateTime.now(),
                        )) {
                          await _showFormErrorDialog(
                            modalContext,
                            'Actual departure time cannot be in the future.',
                          );
                          return;
                        }

                        if (!modalContext.mounted) {
                          return;
                        }

                        setModalState(
                              () {
                            selectedTime =
                                selected;
                          },
                        );
                      }
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _methodDropdown(
                    value:
                    method,
                    label:
                    'Actual Departure Method',
                    onChanged:
                        (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setModalState(
                            () {
                          method =
                              value;
                        },
                      );

                      checkDifference();
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  _textField(
                    controller:
                    pointController,
                    label:
                    'Actual Departure Point',
                    hint:
                    'e.g. KLIA / Johor Bahru CIQ / Port Klang',
                    icon:
                    Icons
                        .location_on_outlined,
                    onChanged:
                        (_) {
                      checkDifference();
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  _textField(
                    controller:
                    referenceController,
                    label:
                    'Transport Reference',
                    hint:
                    'Flight / vehicle / vessel reference',
                    icon:
                    Icons
                        .confirmation_number_outlined,
                  ),

                  if (requiresReason) ...[
                    const SizedBox(
                      height: 14,
                    ),
                    _textField(
                      controller:
                      reasonController,
                      label:
                      'Reason for Change',
                      hint:
                      'Explain why the actual travel method or point changed',
                      icon:
                      Icons.edit_note_rounded,
                      maxLines: 3,
                    ),
                  ],

                  const SizedBox(
                    height: 22,
                  ),

                  _submitButton(
                    label:
                    'Confirm Departure',
                    icon:
                    Icons.check_rounded,
                    onPressed:
                        () async {
                      final departureAt =
                      DateTime(
                        selectedDate
                            .year,
                        selectedDate
                            .month,
                        selectedDate
                            .day,
                        selectedTime
                            .hour,
                        selectedTime
                            .minute,
                      );

                      try {
                        if (!mounted ||
                            !modalContext.mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          true;
                        });

                        setModalState(() {});

                        await _travelService
                            .reportDeparture(
                          submissionId:
                          visa.submissionId,
                          actualDepartureAt:
                          departureAt,
                          departureMethod:
                          method,
                          departurePoint:
                          pointController
                              .text,
                          departureReference:
                          referenceController
                              .text,
                          plannedDepartureMethod:
                          plannedMethod,
                          plannedDeparturePoint:
                          plannedPoint,
                          departureChangeReason:
                          reasonController
                              .text,
                        );

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          false;
                        });

                        if (modalContext.mounted) {
                          Navigator.pop(
                            modalContext,
                          );
                        }

                        if (!mounted) {
                          return;
                        }

                        await _loadTravelContext();

                        if (!mounted) {
                          return;
                        }

                        _showSuccess(
                          'Departure reported successfully.',
                        );
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _isSubmitting =
                          false;
                        });

                        if (!modalContext.mounted) {
                          return;
                        }

                        setModalState(() {});

                        await _showFormErrorDialog(
                          modalContext,
                          _cleanError(
                            e,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
// Planned Date Ui

  Widget _plannedDateBox({
    required String label,
    required DateTime? date,
  }) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFF8FAFC,
        ),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons
                .event_outlined,
            size: 19,
            color:
            Color(
              0xFF64748B,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  label,
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF64748B,
                    ),
                    fontSize:
                    10,
                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  date == null
                      ? 'Not available'
                      : _formatDate(
                    date,
                  ),
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Common Ui

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border:
        Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black
                .withValues(alpha: 0.025),
            blurRadius:
            10,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.all(9),
          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFEFF6FF,
            ),
            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),
          child:
          Icon(
            icon,
            size:
            20,
            color:
            const Color(
              0xFF1E3A8A,
            ),
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Text(
          title,
          style:
          const TextStyle(
            fontSize:
            15,
            fontWeight:
            FontWeight.w800,
            color:
            Color(
              0xFF0F172A,
            ),
          ),
        ),
      ],
    );
  }

  Widget _informationRow(
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
            125,
            child:
            Text(
              label,
              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),
                fontSize:
                11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child:
            Text(
              value,
              style:
              const TextStyle(
                color:
                Color(
                  0xFF0F172A,
                ),
                fontSize:
                12,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remainingDaysCard(
      int remaining,
      VisaTravelState state,
      ) {
    final isWarning =
        state ==
            VisaTravelState
                .expiringSoon;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color:
        isWarning
            ? const Color(
          0xFFFFFBEB,
        )
            : const Color(
          0xFFF0FDF4,
        ),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          isWarning
              ? const Color(
            0xFFFDE68A,
          )
              : const Color(
            0xFFBBF7D0,
          ),
        ),
      ),
      child:
      Column(
        children: [
          Text(
            '$remaining',
            style:
            TextStyle(
              fontSize:
              30,
              fontWeight:
              FontWeight.w900,
              color:
              isWarning
                  ? const Color(
                0xFFD97706,
              )
                  : const Color(
                0xFF15803D,
              ),
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          const Text(
            'days remaining',
            style:
            TextStyle(
              color:
              Color(
                0xFF64748B,
              ),
              fontSize:
              11,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBox(
      String message,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFFEF2F2,
        ),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          const Color(
            0xFFFECACA,
          ),
        ),
      ),
      child:
      Row(
        children: [
          const Icon(
            Icons
                .warning_amber_rounded,
            color:
            Color(
              0xFFDC2626,
            ),
            size:
            20,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child:
            Text(
              message,
              style:
              const TextStyle(
                color:
                Color(
                  0xFF991B1B,
                ),
                fontSize:
                11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodDropdown({
    required String value,
    required String label,
    required ValueChanged<String?>
    onChanged,
  }) {
    return DropdownButtonFormField<
        String>(
      initialValue: value,
      decoration:
      _inputDecoration(
        label,
        Icons.route_rounded,
      ),
      items:
      const [
        DropdownMenuItem(
          value:
          'AIR',
          child:
          Text('Air'),
        ),
        DropdownMenuItem(
          value:
          'LAND',
          child:
          Text('Land'),
        ),
        DropdownMenuItem(
          value:
          'SEA',
          child:
          Text('Sea'),
        ),
      ],
      onChanged:
      onChanged,
    );
  }

  Widget _textField({
    required TextEditingController
    controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller:
      controller,
      maxLines:
      maxLines,
      onChanged:
      onChanged,
      decoration:
      _inputDecoration(
        label,
        icon,
      ).copyWith(
        hintText:
        hint,
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label,
      IconData icon,
      ) {
    return InputDecoration(
      labelText:
      label,
      prefixIcon:
      Icon(
        icon,
        size:
        20,
      ),
      filled:
      true,
      fillColor:
      const Color(0xFFF8FAFC),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide:
        const BorderSide(
          color:
          Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _dateTimeSelector({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback
    onDatePressed,
    required VoidCallback
    onTimePressed,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
          const TextStyle(
            color:
            Color(
              0xFF0F172A,
            ),
            fontSize:
            12,
            fontWeight:
            FontWeight.w700,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Row(
          children: [
            Expanded(
              child:
              OutlinedButton.icon(
                onPressed:
                onDatePressed,
                icon:
                const Icon(
                  Icons
                      .calendar_today_rounded,
                  size:
                  17,
                ),
                label:
                Text(
                  _formatDate(
                    date,
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:
              OutlinedButton.icon(
                onPressed:
                onTimePressed,
                icon:
                const Icon(
                  Icons
                      .access_time_rounded,
                  size:
                  18,
                ),
                label:
                Text(
                  time.format(
                    context,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _submitButton({
    required String label,
    required IconData icon,
    required VoidCallback
    onPressed,
  }) {
    return SizedBox(
      width:
      double.infinity,
      height:
      50,
      child:
      ElevatedButton.icon(
        onPressed:
        _isSubmitting
            ? null
            : onPressed,
        icon:
        _isSubmitting
            ? const SizedBox(
          width:
          18,
          height:
          18,
          child:
          CircularProgressIndicator(
            strokeWidth:
            2,
            color:
            Colors.white,
          ),
        )
            : Icon(
          icon,
        ),
        label:
        Text(
          _isSubmitting
              ? 'Submitting...'
              : label,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
        style:
        ElevatedButton.styleFrom(
          backgroundColor:
          const Color(
            0xFF1E3A8A,
          ),
          foregroundColor:
          Colors.white,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _formSheet({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      constraints:
      BoxConstraints(
        maxHeight:
        MediaQuery.of(context)
            .size
            .height *
            0.90,
      ),
      decoration:
      const BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top:
          Radius.circular(
            24,
          ),
        ),
      ),
      child:
      SingleChildScrollView(
        padding:
        EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context)
              .viewInsets
              .bottom +
              24,
        ),
        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Center(
              child:
              Container(
                width:
                40,
                height:
                4,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFCBD5E1,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets
                      .all(
                    9,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFEFF6FF,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                  ),
                  child:
                  Icon(
                    icon,
                    color:
                    const Color(
                      0xFF1E3A8A,
                    ),
                    size:
                    21,
                  ),
                ),

                const SizedBox(
                  width:
                  12,
                ),

                Text(
                  title,
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              22,
            ),

            child,
          ],
        ),
      ),
    );
  }
// State Badge

  Widget _buildStateBadge(
      VisaTravelState state,
      ) {
    String label;

    switch (state) {
      case VisaTravelState
          .notEntered:
        label =
        'NOT ENTERED';
        break;

      case VisaTravelState.active:
        label =
        'ACTIVE';
        break;

      case VisaTravelState
          .expiringSoon:
        label =
        'EXPIRING SOON';
        break;

      case VisaTravelState
          .departureNotReported:
        label =
        'REPORT DEPARTURE';
        break;

      case VisaTravelState.departed:
        label =
        'DEPARTED';
        break;

      case VisaTravelState.used:
        label =
        'USED';
        break;

      case VisaTravelState.expired:
        label =
        'EXPIRED';
        break;

      case VisaTravelState.noVisa:
        label =
        'NO VISA';
        break;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,
        vertical:
        5,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white
            .withValues(alpha: 0.14),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child:
      Text(
        label,
        style:
        const TextStyle(
          color:
          Colors.white,
          fontSize:
          8,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
// Empty / Error

  Widget _buildNoVisaCard() {
    return _sectionCard(
      child:
      const Column(
        children: [
          Icon(
            Icons
                .assignment_outlined,
            size:
            44,
            color:
            Color(
              0xFF94A3B8,
            ),
          ),
          SizedBox(
            height:
            14,
          ),
          Text(
            'No Approved Visa',
            style:
            TextStyle(
              fontSize:
              16,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          SizedBox(
            height:
            6,
          ),
          Text(
            'Travel declaration becomes available after your visa has been approved.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color:
              Color(
                0xFF64748B,
              ),
              fontSize:
              12,
              height:
              1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
      String message,
      ) {
    return _sectionCard(
      child:
      Column(
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            size:
            40,
            color:
            Color(
              0xFFDC2626,
            ),
          ),
          const SizedBox(
            height:
            12,
          ),
          Text(
            message,
            textAlign:
            TextAlign.center,
          ),
        ],
      ),
    );
  }
// Messages

  Future<void> _showFormErrorDialog(
      BuildContext dialogContext,
      String message,
      ) async {
    await showDialog<void>(
      context:
      dialogContext,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
          const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color:
                Color(
                  0xFFDC2626,
                ),
              ),
              SizedBox(
                width:
                10,
              ),
              Text(
                'Unable to Submit',
              ),
            ],
          ),
          content:
          Text(
            message,
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccess(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
          backgroundColor:
          const Color(
            0xFF15803D,
          ),
        ),
      );
  }

// Helpers

  String _formatDate(
      DateTime date,
      ) {
    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$day/$month/${date.year}';
  }

  String _formatDateTime(
      DateTime date,
      ) {
    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final hour =
    date.hour
        .toString()
        .padLeft(
      2,
      '0',
    );

    final minute =
    date.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$day/$month/${date.year} · $hour:$minute';
  }

  String _cleanError(
      Object error,
      ) {
    var text =
    error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      text =
          text.substring(
            'Exception: '.length,
          );
    }

    final separator =
    text.indexOf(
      ': ',
    );

    if (separator != -1 &&
        separator < 40) {
      final possibleCode =
      text.substring(
        0,
        separator,
      );

      if (possibleCode ==
          possibleCode.toUpperCase()) {
        text =
            text.substring(
              separator + 2,
            );
      }
    }

    return text;
  }
}
