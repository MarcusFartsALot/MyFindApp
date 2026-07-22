import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/validators/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/passport_image_capture.dart';

/// One page, two tabs: Tourist (email + passport + password + front/back
/// passport photos, goes to pending review) and Local Citizen
/// (email + Malaysian IC + password, auto-approved).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tourist'),
            Tab(text: 'Local Citizen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TouristRegisterForm(),
          _CitizenRegisterForm(),
        ],
      ),
    );
  }
}

class _TouristRegisterForm extends StatefulWidget {
  const _TouristRegisterForm();

  @override
  State<_TouristRegisterForm> createState() => _TouristRegisterFormState();
}

class _TouristRegisterFormState extends State<_TouristRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  File? _frontImage;
  File? _backImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passportCtrl.dispose();
    _nationalityCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frontImage == null || _backImage == null) {
      _showError('Please capture both the front and back of your passport.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.registerTourist(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        passportNo: _passportCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim(),
        passportFrontImage: _frontImage!,
        passportBackImage: _backImage!,
      );
      if (!mounted) return;
      _showSuccessAndReturnToLogin();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  void _showSuccessAndReturnToLogin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registration submitted'),
        content: const Text(
          'Your account was created and your documents were submitted for '
          'verification. You can log in once an officer approves your '
          'application.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _fullNameCtrl,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
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
            controller: _nationalityCtrl,
            decoration: const InputDecoration(labelText: 'Nationality'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nationality is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passportCtrl,
            decoration: const InputDecoration(
              labelText: 'Passport number',
              helperText: '5-9 letters/numbers, as printed on your passport',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: Validators.passportNumber,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordCtrl,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
          ),
          const SizedBox(height: 20),
          PassportImageCapture(
            label: 'Passport photo page (front)',
            onImageSelected: (f) => setState(() => _frontImage = f),
          ),
          const SizedBox(height: 16),
          PassportImageCapture(
            label: 'Passport back page',
            onImageSelected: (f) => setState(() => _backImage = f),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Application'),
          ),
        ],
      ),
    );
  }
}

class _CitizenRegisterForm extends StatefulWidget {
  const _CitizenRegisterForm();

  @override
  State<_CitizenRegisterForm> createState() => _CitizenRegisterFormState();
}

class _CitizenRegisterFormState extends State<_CitizenRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _icCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _authService.registerCitizen(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        icNumber: _icCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade600),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _fullNameCtrl,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
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
            controller: _icCtrl,
            decoration: const InputDecoration(
              labelText: 'IC number',
              helperText: 'Format: YYMMDD-PB-###G, e.g. 900101-14-5566',
            ),
            validator: Validators.malaysianIC,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordCtrl,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
