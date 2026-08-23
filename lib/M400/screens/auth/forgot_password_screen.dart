import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_find/core/validators/validators.dart';
import 'package:my_find/M400/services/auth_service.dart';
import 'package:my_find/M400/services/password_reset_rate_limiter.dart';
import 'package:my_find/M400/widgets/auth_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _rateLimiter = PasswordResetRateLimiter();
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _sent = false;
  PasswordResetLimitState? _limitState;
  DateTime? _retryAt;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() == false) return;
    final email = _emailCtrl.text.trim();
    final currentLimit = await _rateLimiter.check(email);
    if (!mounted) return;
    _applyLimit(currentLimit);
    if (!currentLimit.canRequest) {
      _showError(_localLimitMessage(currentLimit));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      final updatedLimit = await _rateLimiter.recordSuccessfulRequest(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _limitState = updatedLimit;
      });
      _applyLimit(updatedLimit);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _applyLimit(PasswordResetLimitState state) {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _limitState = state;
        _retryAt = state.retryAfter > Duration.zero
            ? DateTime.now().add(state.retryAfter)
            : null;
      });
    }
    if (state.retryAfter <= Duration.zero) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilRetry <= 0) {
        timer.cancel();
        unawaited(_refreshLimit());
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _refreshLimit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    final state = await _rateLimiter.check(email);
    if (!mounted) return;
    _applyLimit(state);
  }

  int get _secondsUntilRetry {
    final retryAt = _retryAt;
    if (retryAt == null) return 0;
    final milliseconds = retryAt.difference(DateTime.now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  String get _resendLabel {
    final seconds = _secondsUntilRetry;
    if (seconds <= 0) return 'Resend reset link';
    if (seconds >= 3600) {
      final hours = (seconds / 3600).ceil();
      return 'Available in $hours hour${hours == 1 ? '' : 's'}';
    }
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return 'Resend in ${minutesPart.toString().padLeft(2, '0')}:'
        '${secondsPart.toString().padLeft(2, '0')}';
  }

  String _localLimitMessage(PasswordResetLimitState state) {
    final seconds = state.retryAfter.inSeconds;
    if (state.remainingRequests > 0 && seconds <= 60) {
      return 'Please wait $seconds seconds before requesting another link.';
    }
    return 'You have used all 3 reset attempts in the last 24 hours. '
        'Try again in ${_formatRetryDuration(state.retryAfter)}.';
  }

  String _formatRetryDuration(Duration duration) {
    final totalMinutes = (duration.inSeconds / 60).ceil();
    if (totalMinutes < 60) {
      return '$totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hourText = '$hours hour${hours == 1 ? '' : 's'}';
    if (minutes == 0) return hourText;
    return '$hourText $minutes minute${minutes == 1 ? '' : 's'}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: M400AuthColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return M400AuthPage(
      title: _sent ? 'Check your email' : 'Forgot password?',
      subtitle: _sent
          ? 'We sent password recovery instructions to your inbox.'
          : 'Enter your account email and we will send you a secure reset link.',
      icon: _sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
      showBackButton: true,
      child: M400AuthCard(
        child: _sent ? _buildSentState() : _buildRequestForm(),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const M400SectionTitle(
            icon: Icons.email_outlined,
            title: 'Account email',
            subtitle:
                'The link will open MyFind so you can set a new password.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            decoration: m400InputDecoration(
              label: 'Email address',
              hint: 'name@example.com',
              prefixIcon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) {
              if (!_isSubmitting) _submit();
            },
            validator: Validators.email,
          ),
          const SizedBox(height: 20),
          M400PrimaryButton(
            label: 'Send reset link',
            icon: Icons.send_outlined,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 14),
          const Text(
            'For privacy, the confirmation looks the same whether or not the email is registered. Maximum 3 requests per email in a rolling 24-hour period.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: M400AuthColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: M400AuthColors.successSoft,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: M400AuthColors.success,
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _emailCtrl.text.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: M400AuthColors.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'If an account exists for this address, the email contains a link that returns to the MyFind app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: M400AuthColors.body,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        if (_limitState != null) ...[
          Text(
            '${_limitState!.remainingRequests} of '
            '${PasswordResetRateLimiter.maximumRequestsPerDay} requests '
            'remaining in the current 24-hour period on this device.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: M400AuthColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: M400AuthColors.primary,
                side: const BorderSide(color: M400AuthColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  _isSubmitting ||
                      _secondsUntilRetry > 0 ||
                      _limitState!.remainingRequests == 0
                  ? null
                  : _submit,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_resendLabel),
            ),
          ),
          const SizedBox(height: 12),
        ],
        M400PrimaryButton(
          label: 'Back to sign in',
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: M400AuthColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: () => setState(() => _sent = false),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
