import 'package:flutter/material.dart';

import 'package:my_find/core/validators/validators.dart';
import 'package:my_find/M400/services/registration_service.dart';
import 'package:my_find/M400/widgets/identity_document_capture.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationService = RegistrationService();
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
  bool _isSubmitting = false;

  @override
  void dispose() {
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
    setState(() {
      _requestedRole = role;
      _document = null;
      _backDocument = null;
      _passportIssueDate = null;
      _passportExpiryDate = null;
      _passportIssueCtrl.clear();
      _passportExpiryCtrl.clear();
      _passportIssuingCountryCtrl.clear();
      _countryOfResidenceCtrl.clear();
      _identityNumberCtrl.clear();
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
          title: const Text('Application Submitted'),
          content: const Text(
            'Registration application submitted successfully.\n\n'
            'Please wait for administrator approval. If approved, sign in '
            'with your email and IC or passport number as the temporary '
            'password. You will then create a new password.',
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
    final chosen = await showDatePicker(
      context: context,
      initialDate: _passportExpiryDate ?? DateTime(now.year + 1),
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (chosen == null) return;
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
    final chosen = await showDatePicker(
      context: context,
      initialDate: _passportIssueDate ?? DateTime(now.year - 1),
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (chosen == null) return;
    setState(() {
      _passportIssueDate = chosen;
      _passportIssueCtrl.text = _formatDate(chosen);
    });
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isCitizen = _requestedRole == 'citizen';
    return Scaffold(
      appBar: AppBar(title: const Text('Registration Application')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Apply as', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'citizen',
                  label: Text('Citizen'),
                  icon: Icon(Icons.badge_outlined),
                ),
                ButtonSegment(
                  value: 'tourist',
                  label: Text('Tourist'),
                  icon: Icon(Icons.flight_outlined),
                ),
              ],
              selected: {_requestedRole},
              onSelectionChanged: (selection) => _changeRole(selection.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter your full name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Phone number is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nationalityCtrl,
              decoration: const InputDecoration(labelText: 'Nationality'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nationality is required'
                  : null,
            ),
            if (!isCitizen) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passportIssuingCountryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Passport issuing country',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Passport issuing country is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passportIssueCtrl,
                readOnly: true,
                onTap: _choosePassportIssueDate,
                decoration: const InputDecoration(
                  labelText: 'Passport issue date (optional)',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passportExpiryCtrl,
                readOnly: true,
                onTap: _choosePassportExpiryDate,
                decoration: const InputDecoration(
                  labelText: 'Passport expiry date',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                validator: (_) => _passportExpiryDate == null
                    ? 'Passport expiry date is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryOfResidenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Country of residence (optional)',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _identityNumberCtrl,
              decoration: InputDecoration(
                labelText: isCitizen ? 'MyKad number' : 'Passport number',
                helperText: isCitizen
                    ? '12 digits, for example 900101-14-5566'
                    : '6-20 letters or numbers',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: isCitizen
                  ? Validators.malaysianIC
                  : Validators.passportNumber,
            ),
            const SizedBox(height: 20),
            IdentityDocumentCapture(
              key: ValueKey('${_requestedRole}_front'),
              requestedRole: _requestedRole,
              labelOverride: isCitizen ? 'MyKad front' : 'Passport front',
              onDocumentChanged: (document) {
                _document = document;
              },
            ),
            if (isCitizen) ...[
              const SizedBox(height: 20),
              IdentityDocumentCapture(
                key: const ValueKey('citizen_back'),
                requestedRole: _requestedRole,
                labelOverride: 'MyKad back',
                requiresOcr: false,
                onDocumentChanged: (document) {
                  _backDocument = document;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }
}
