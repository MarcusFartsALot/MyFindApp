import 'dart:async';

import 'package:flutter/material.dart';

import 'package:my_find/core/validators/validators.dart';
import 'package:my_find/M400/services/document_ocr_service.dart';
import 'package:my_find/M400/services/passport_details_parser.dart';
import 'package:my_find/M400/services/identity_number_service.dart';
import 'package:my_find/M400/services/registration_service.dart';
import 'package:my_find/M400/widgets/auth_ui.dart';
import 'package:my_find/M400/widgets/identity_document_capture.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationService = RegistrationService();
  final _identityService = IdentityNumberService();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _identityNumberCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _passportIssuingCountryCtrl = TextEditingController();
  final _passportIssueCtrl = TextEditingController();
  final _passportExpiryCtrl = TextEditingController();
  final _countryOfResidenceCtrl = TextEditingController();

  String _requestedRole = 'citizen';
  RecognizedDocument? _document;
  RecognizedDocument? _backDocument;
  DateTime? _passportIssueDate;
  DateTime? _passportExpiryDate;
  PassportDetails _lastPassportScan = const PassportDetails();
  String? _passportScanFeedback;
  Timer? _identityCheckTimer;
  int _identityCheckVersion = 0;
  bool _checkingIdentity = false;
  String? _identityCheckMessage;
  bool _identityCheckFailed = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _identityCheckTimer?.cancel();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _identityNumberCtrl.dispose();
    _nationalityCtrl.dispose();
    _passportIssuingCountryCtrl.dispose();
    _passportIssueCtrl.dispose();
    _passportExpiryCtrl.dispose();
    _countryOfResidenceCtrl.dispose();
    super.dispose();
  }

  void _changeRole(String role) {
    if (_requestedRole == role) return;
    _identityCheckTimer?.cancel();
    _identityCheckVersion++;
    setState(() {
      _requestedRole = role;
      _document = null;
      _backDocument = null;
      _passportIssueDate = null;
      _passportExpiryDate = null;
      _lastPassportScan = const PassportDetails();
      _passportScanFeedback = null;
      _checkingIdentity = false;
      _identityCheckMessage = null;
      _identityCheckFailed = false;
      _passportIssueCtrl.clear();
      _passportExpiryCtrl.clear();
      _passportIssuingCountryCtrl.clear();
      _countryOfResidenceCtrl.clear();
      _identityNumberCtrl.clear();
    });
  }

  void _onIdentityNumberChanged(String value) {
    _identityCheckTimer?.cancel();
    final version = ++_identityCheckVersion;
    final role = _requestedRole;
    final validation = role == 'citizen'
        ? Validators.malaysianIC(value)
        : Validators.passportNumber(value);
    setState(() {
      _checkingIdentity = validation == null;
      _identityCheckMessage = null;
      _identityCheckFailed = false;
    });
    if (validation != null) return;
    _identityCheckTimer = Timer(const Duration(milliseconds: 650), () async {
      String message = 'This number is available for registration.';
      var failed = false;
      try {
        await _identityService.ensureAvailable(role: role, number: value);
      } catch (error) {
        message = error.toString();
        failed = true;
      }
      if (!mounted || version != _identityCheckVersion) return;
      setState(() {
        _checkingIdentity = false;
        _identityCheckMessage = message;
        _identityCheckFailed = failed;
      });
    });
  }

  void _onPassportTextExtracted(String? text) {
    if (_requestedRole != 'tourist') return;

    final scanned = text == null
        ? const PassportDetails()
        : PassportDetailsParser.parse(text);
    final country = _passportIssuingCountryCtrl.text.trim();
    final details = PassportDetailsParser.mergeAutofill(
      current: PassportDetails(
        issueDate: _passportIssueDate,
        expiryDate: _passportExpiryDate,
        issuingCountry: country.isEmpty ? null : country,
      ),
      scanned: scanned,
      previous: _lastPassportScan,
    );
    setState(() {
      _lastPassportScan = scanned;
      final readCount = [
        scanned.issueDate,
        scanned.expiryDate,
        scanned.issuingCountry,
      ].where((value) => value != null).length;
      _passportScanFeedback = text == null
          ? null
          : readCount == 0
          ? 'No passport dates or issuing country could be read. Retake the full details page in good light, or enter the details below.'
          : 'Read $readCount of 3 passport details. Review the fields below and enter anything missing. Your manual corrections are kept.';
      _passportIssueDate = details.issueDate;
      _passportExpiryDate = details.expiryDate;
      _passportIssueCtrl.text = details.issueDate == null
          ? ''
          : _formatDate(details.issueDate!);
      _passportExpiryCtrl.text = details.expiryDate == null
          ? ''
          : _formatDate(details.expiryDate!);
      _passportIssuingCountryCtrl.text = details.issuingCountry ?? '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_document == null) {
      _showError(
        _requestedRole == 'citizen'
            ? 'Please take a clear MyKad photo and complete text extraction.'
            : 'Please take a clear passport photo and complete text extraction.',
      );
      return;
    }
    if (_requestedRole == 'citizen' && _backDocument == null) {
      _showError('Please add a photo of the back of your MyKad.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _registrationService.submitApplication(
        fullName: _fullNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
        requestedRole: _requestedRole,
        identityNumber: _identityNumberCtrl.text,
        nationality: _nationalityCtrl.text,
        documentImage: _document!.image,
        documentBackImage: _backDocument?.image,
        documentBackExtractedText: _backDocument?.extractedText,
        extractedText: _document!.extractedText,
        passportIssueDate: _passportIssueDate,
        passportExpiryDate: _passportExpiryDate,
        passportIssuingCountry: _passportIssuingCountryCtrl.text,
        countryOfResidence: _countryOfResidenceCtrl.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registration submitted'),
          content: const Text(
            'Your registration was submitted successfully.\n\n'
            'Please wait for administrator approval. If approved, sign in '
            'with your email and IC or passport number as the temporary '
            'password. You can change it later in Settings.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _choosePassportExpiryDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day + 1);
    final last = DateTime(now.year + 20, 12, 31);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _clampDate(
        _passportExpiryDate ?? DateTime(now.year + 1),
        first,
        last,
      ),
      firstDate: first,
      lastDate: last,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _passportExpiryDate = chosen;
      _passportExpiryCtrl.text =
          '${chosen.year.toString().padLeft(4, '0')}-'
          '${chosen.month.toString().padLeft(2, '0')}-'
          '${chosen.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _choosePassportIssueDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 20);
    final last = DateTime(now.year, now.month, now.day);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _clampDate(
        _passportIssueDate ?? DateTime(now.year - 1),
        first,
        last,
      ),
      firstDate: first,
      lastDate: last,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _passportIssueDate = chosen;
      _passportIssueCtrl.text = _formatDate(chosen);
    });
  }

  DateTime _clampDate(DateTime date, DateTime first, DateTime last) =>
      date.isBefore(first)
      ? first
      : date.isAfter(last)
      ? last
      : date;

  String? _validateIssueDate(String? _) {
    final issue = _passportIssueDate;
    if (issue == null) return null;
    final now = DateTime.now();
    if (issue.isAfter(DateTime(now.year, now.month, now.day))) {
      return 'Passport issue date cannot be in the future';
    }
    if (_passportExpiryDate != null && issue.isAfter(_passportExpiryDate!)) {
      return 'Issue date must be before expiry date';
    }
    return null;
  }

  String? _validateExpiryDate(String? _) {
    if (_passportExpiryDate == null) return 'Passport expiry date is required';
    if (!_passportExpiryDate!.isAfter(DateTime.now())) {
      return 'Enter a valid future passport expiry date';
    }
    return null;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isCitizen = _requestedRole == 'citizen';
    return Scaffold(
      backgroundColor: M400AuthColors.background,
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(
            color: M400AuthColors.heading,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: M400AuthColors.surface,
        elevation: 1,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: M400AuthColors.heading),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create your MyFind account',
                      style: TextStyle(
                        color: M400AuthColors.heading,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Enter your details and identity document. An administrator will review your registration before you can sign in.',
                      style: TextStyle(
                        color: M400AuthColors.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    M400AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const M400SectionTitle(
                            icon: Icons.people_alt_outlined,
                            title: 'Account type',
                            subtitle:
                                'Choose the type that matches your document.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleChoice(
                                  label: 'Citizen',
                                  icon: Icons.badge_outlined,
                                  selected: isCitizen,
                                  onTap: () => _changeRole('citizen'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleChoice(
                                  label: 'Tourist',
                                  icon: Icons.flight_outlined,
                                  selected: !isCitizen,
                                  onTap: () => _changeRole('tourist'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    M400AuthCard(
                      child: Column(
                        children: [
                          const M400SectionTitle(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal details',
                            subtitle:
                                'Use the same details shown on your document.',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _fullNameCtrl,
                            decoration: m400InputDecoration(
                              label: 'Full name',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                ? 'Enter your full name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: m400InputDecoration(
                              label: 'Email address',
                              hint: 'name@example.com',
                              prefixIcon: Icons.email_outlined,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneCtrl,
                            decoration: m400InputDecoration(
                              label: 'Phone number',
                              prefixIcon: Icons.phone_outlined,
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Phone number is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nationalityCtrl,
                            decoration: m400InputDecoration(
                              label: 'Nationality',
                              prefixIcon: Icons.public_rounded,
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Nationality is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    M400AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          M400SectionTitle(
                            icon: Icons.verified_user_outlined,
                            title: 'Identity verification',
                            subtitle: isCitizen
                                ? 'Enter your MyKad number and add clear photos of both sides.'
                                : 'Photograph the passport details page to fill readable dates and issuing country. Enter its passport number to verify the photo.',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _identityNumberCtrl,
                            decoration: m400InputDecoration(
                              label: isCitizen
                                  ? 'MyKad number'
                                  : 'Passport number',
                              helper: isCitizen
                                  ? '12 digits, for example 900101-14-5566'
                                  : '6-20 letters or numbers',
                              prefixIcon: isCitizen
                                  ? Icons.badge_outlined
                                  : Icons.menu_book_outlined,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onChanged: _onIdentityNumberChanged,
                            validator: isCitizen
                                ? Validators.malaysianIC
                                : Validators.passportNumber,
                          ),
                          if (_checkingIdentity ||
                              _identityCheckMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _checkingIdentity
                                    ? 'Checking this number in the system...'
                                    : _identityCheckMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _identityCheckFailed
                                      ? M400AuthColors.error
                                      : M400AuthColors.muted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                          IdentityDocumentCapture(
                            key: ValueKey('${_requestedRole}_front'),
                            requestedRole: _requestedRole,
                            expectedIdentityNumber: _identityNumberCtrl.text,
                            labelOverride: isCitizen
                                ? 'MyKad front'
                                : 'Passport front',
                            onDocumentChanged: (document) =>
                                _document = document,
                            onTextExtracted: isCitizen
                                ? null
                                : _onPassportTextExtracted,
                          ),
                          if (isCitizen) ...[
                            const SizedBox(height: 24),
                            const Divider(color: M400AuthColors.border),
                            const SizedBox(height: 20),
                            IdentityDocumentCapture(
                              key: const ValueKey('citizen_back'),
                              requestedRole: _requestedRole,
                              labelOverride: 'MyKad back',
                              expectedIdentityNumber: _identityNumberCtrl.text,
                              side: IdentityDocumentSide.back,
                              onDocumentChanged: (document) {
                                _backDocument = document;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isCitizen) ...[
                      const SizedBox(height: 16),
                      M400AuthCard(
                        child: Column(
                          children: [
                            M400SectionTitle(
                              icon: Icons.flight_takeoff_outlined,
                              title: 'Passport details',
                              subtitle:
                                  _passportScanFeedback ??
                                  'Capture the passport details page to fill readable dates and issuing country. You can also enter these yourself. The country may appear as a three-letter passport code.',
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passportIssuingCountryCtrl,
                              decoration: m400InputDecoration(
                                label: 'Passport issuing country',
                                prefixIcon: Icons.flag_outlined,
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Passport issuing country is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passportIssueCtrl,
                              readOnly: true,
                              onTap: _choosePassportIssueDate,
                              validator: _validateIssueDate,
                              decoration: m400InputDecoration(
                                label: 'Passport issue date (optional)',
                                hint: 'YYYY-MM-DD',
                                prefixIcon: Icons.calendar_month_outlined,
                                suffixIcon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: M400AuthColors.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passportExpiryCtrl,
                              readOnly: true,
                              onTap: _choosePassportExpiryDate,
                              validator: _validateExpiryDate,
                              decoration: m400InputDecoration(
                                label: 'Passport expiry date',
                                hint: 'YYYY-MM-DD',
                                prefixIcon: Icons.event_available_outlined,
                                suffixIcon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: M400AuthColors.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _countryOfResidenceCtrl,
                              decoration: m400InputDecoration(
                                label: 'Country of residence (optional)',
                                prefixIcon: Icons.home_work_outlined,
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    M400PrimaryButton(
                      label: 'Register',
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'By registering, you confirm that the information and documents are accurate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: M400AuthColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? M400AuthColors.primarySoft : M400AuthColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? M400AuthColors.primary : M400AuthColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? M400AuthColors.primary : M400AuthColors.muted,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? M400AuthColors.primary
                      : M400AuthColors.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
