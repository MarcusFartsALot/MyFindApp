import 'package:flutter_test/flutter_test.dart';
import 'package:my_find/M400/services/password_reset_rate_limiter.dart';

void main() {
  group('password reset rate limiter', () {
    final now = DateTime.utc(2026, 8, 23, 12);

    test('requires 60 seconds between successful requests', () {
      final state = PasswordResetRateLimiter.evaluate(
        attempts: [now.subtract(const Duration(seconds: 10))],
        now: now,
      );

      expect(state.canRequest, isFalse);
      expect(state.remainingRequests, 2);
      expect(state.retryAfter, const Duration(seconds: 50));
    });

    test('blocks after three requests in a rolling 24-hour period', () {
      final state = PasswordResetRateLimiter.evaluate(
        attempts: [
          now.subtract(const Duration(hours: 20)),
          now.subtract(const Duration(hours: 12)),
          now.subtract(const Duration(minutes: 2)),
        ],
        now: now,
      );

      expect(state.canRequest, isFalse);
      expect(state.remainingRequests, 0);
      expect(state.retryAfter, const Duration(hours: 4));
    });

    test('allows another request when the oldest attempt passes 24 hours', () {
      final state = PasswordResetRateLimiter.evaluate(
        attempts: [
          now.subtract(const Duration(hours: 25)),
          now.subtract(const Duration(hours: 20)),
          now.subtract(const Duration(hours: 2)),
        ],
        now: now,
      );

      expect(state.canRequest, isTrue);
      expect(state.remainingRequests, 1);
    });
  });
}
