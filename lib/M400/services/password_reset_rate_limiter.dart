import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordResetLimitState {
  const PasswordResetLimitState({
    required this.canRequest,
    required this.remainingRequests,
    required this.retryAfter,
  });

  final bool canRequest;
  final int remainingRequests;
  final Duration retryAfter;
}

/// Device-side usability limit for the forgot-password screen.
///
/// Supabase still enforces its own project-wide email limits. This local rule
/// provides an immediate explanation and prevents accidental repeated taps.
class PasswordResetRateLimiter {
  static const int maximumRequestsPerDay = 3;
  static const Duration requestWindow = Duration(days: 1);
  static const Duration resendCooldown = Duration(seconds: 60);
  static const String _preferencePrefix = 'm400_password_reset_';

  Future<PasswordResetLimitState> check(String email) async {
    final now = DateTime.now().toUtc();
    final attempts = await _loadActiveAttempts(email, now);
    return evaluate(attempts: attempts, now: now);
  }

  Future<PasswordResetLimitState> recordSuccessfulRequest(String email) async {
    final now = DateTime.now().toUtc();
    final attempts = await _loadActiveAttempts(email, now)
      ..add(now);
    await _saveAttempts(email, attempts);
    return evaluate(attempts: attempts, now: now);
  }

  static PasswordResetLimitState evaluate({
    required List<DateTime> attempts,
    required DateTime now,
  }) {
    final current = now.toUtc();
    final active =
        attempts
            .map((attempt) => attempt.toUtc())
            .where(
              (attempt) =>
                  !attempt.isAfter(current) &&
                  attempt.isAfter(current.subtract(requestWindow)),
            )
            .toList()
          ..sort();
    final remaining = (maximumRequestsPerDay - active.length).clamp(
      0,
      maximumRequestsPerDay,
    );

    if (active.length >= maximumRequestsPerDay) {
      return PasswordResetLimitState(
        canRequest: false,
        remainingRequests: 0,
        retryAfter: _positiveDuration(
          active.first.add(requestWindow).difference(current),
        ),
      );
    }

    if (active.isNotEmpty) {
      final cooldownRemaining = active.last
          .add(resendCooldown)
          .difference(current);
      if (cooldownRemaining > Duration.zero) {
        return PasswordResetLimitState(
          canRequest: false,
          remainingRequests: remaining,
          retryAfter: cooldownRemaining,
        );
      }
    }

    return PasswordResetLimitState(
      canRequest: true,
      remainingRequests: remaining,
      retryAfter: Duration.zero,
    );
  }

  Future<List<DateTime>> _loadActiveAttempts(String email, DateTime now) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _keyFor(email);
    final stored = preferences.getStringList(key) ?? const <String>[];
    final active =
        stored
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((attempt) => attempt.toUtc())
            .where(
              (attempt) =>
                  !attempt.isAfter(now) &&
                  attempt.isAfter(now.subtract(requestWindow)),
            )
            .toList()
          ..sort();
    await preferences.setStringList(
      key,
      active.map((attempt) => attempt.toIso8601String()).toList(),
    );
    return active;
  }

  Future<void> _saveAttempts(String email, List<DateTime> attempts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _keyFor(email),
      attempts.map((attempt) => attempt.toUtc().toIso8601String()).toList(),
    );
  }

  String _keyFor(String email) {
    final normalized = email.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode(normalized));
    return '$_preferencePrefix$digest';
  }

  static Duration _positiveDuration(Duration value) =>
      value > Duration.zero ? value : Duration.zero;
}
