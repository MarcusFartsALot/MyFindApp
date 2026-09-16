import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_find/M400/services/recovery_safe_session_storage.dart';
import 'package:my_find/M400/services/auth_service.dart';
import 'package:my_find/M400/screens/router/session_gate.dart';
import 'package:my_find/M400/screens/auth/about_screen.dart';
import 'package:my_find/M400/screens/auth/reset_password_screen.dart';
import 'package:my_find/M400/screens/auth/login_screen.dart';

class MemoryPkceStore extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class MemorySessionStore extends LocalStorage {
  String? saved;
  final writes = <String>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => saved != null;
  @override
  Future<String?> accessToken() async => saved;
  @override
  Future<void> persistSession(String value) async {
    saved = value;
    writes.add(value);
  }

  @override
  Future<void> removePersistedSession() async {
    saved = null;
  }
}

Session sampleSession(String id, {int revision = 0}) {
  String part(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final user = User(
    id: '00000000-0000-4000-8000-000000000001',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'test@example.test',
  );
  final token =
      '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'session_id': id, 'sub': user.id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'revision': revision})}.dGVzdA';
  return Session(
    accessToken: token,
    tokenType: 'bearer',
    user: user,
    refreshToken: 'test-refresh-$id',
    expiresIn: 3600,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemorySessionStore disk;
  late RecoverySafeSessionStorage storage;
  late SupabaseClient client;
  late AuthService auth;
  var profileRequests = 0;
  var offlineLogout = false;
  var failUpdate = false;
  var approved = true;
  final normal = sampleSession('password-session');
  final recovery = sampleSession('recovery-session');

  setUp(() async {
    disk = MemorySessionStore();
    storage = RecoverySafeSessionStorage(backingStore: disk);
    await storage.initialize();
    profileRequests = 0;
    offlineLogout = false;
    failUpdate = false;
    approved = true;
    client = SupabaseClient(
      'https://project.example.test',
      'test-anon-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        Object body;
        var status = 200;
        if (request.url.path == '/auth/v1/token') {
          expect(request.url.queryParameters['grant_type'], 'password');
          body = normal.toJson();
        } else if (request.url.path == '/auth/v1/user') {
          if (failUpdate) {
            throw const SocketException('Offline');
          }
          body = recovery.user.toJson();
        } else if (request.url.path == '/auth/v1/logout') {
          if (offlineLogout) {
            throw const SocketException('Offline');
          }
          body = {};
          status = 204;
        } else if (request.url.path == '/rest/v1/profiles') {
          profileRequests++;
          body = {
            'id': 'profile-1',
            'auth_id': normal.user.id,
            'full_name': 'Test Member',
            'email': 'test@example.test',
            'role': 'citizen',
          };
        } else if (request.url.path == '/rest/v1/citizens') {
          body = {'verification_status': approved ? 'approved' : 'pending'};
        } else {
          throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          status == 204 ? '' : jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    auth = AuthService(client: client, sessionStorage: storage);
  });
  tearDown(() => client.dispose());

  test(
    'real Flutter SDK recovery persistence cannot survive process recreation',
    () async {
      Future<void> initializeSdk(RecoverySafeSessionStorage localStore) async {
        await Supabase.initialize(
          url: 'https://project.example.test',
          publishableKey: 'test-anon-key',
          authOptions: FlutterAuthClientOptions(
            localStorage: localStore,
            pkceAsyncStorage: MemoryPkceStore(),
            autoRefreshToken: false,
            detectSessionInUri: false,
          ),
          httpClient: MockClient((request) async {
            expect(request.url.path, '/auth/v1/verify');
            return http.Response(
              jsonEncode(recovery.toJson()),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
      }

      await initializeSdk(storage);
      try {
        await Supabase.instance.client.auth.verifyOTP(
          tokenHash: 'test-only-hash',
          type: OtpType.recovery,
        );
        await Future<void>.delayed(Duration.zero);
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
        expect(disk.writes, isEmpty);
        // Dispose, not signOut: simulate losing all in-memory state on app kill.
        await Supabase.instance.dispose();
        await initializeSdk(RecoverySafeSessionStorage(backingStore: disk));
        expect(Supabase.instance.client.auth.currentSession, isNull);
      } finally {
        await Supabase.instance.dispose();
      }
    },
  );

  test('force-close after recovery never restores a login', () async {
    // Exactly the SDK storage callback for the recovery event; no screen exit
    // or lifecycle callback is needed before constructing a new process store.
    await storage.persistSession(jsonEncode(recovery.toJson()));
    final restarted = RecoverySafeSessionStorage(backingStore: disk);
    await restarted.initialize();
    expect(await restarted.hasAccessToken(), isFalse);
    expect(restarted.isTrusted(recovery), isFalse);
    expect(disk.writes, isEmpty);
  });

  test(
    'normal login and refresh restore, but later recovery does not',
    () async {
      await auth.signIn(email: 'test@example.test', password: 'ExamplePass1!');
      expect(auth.hasTrustedSession, isTrue);
      await storage.persistSession(
        jsonEncode(sampleSession('password-session', revision: 1).toJson()),
      );
      final normalRestart = RecoverySafeSessionStorage(backingStore: disk);
      await normalRestart.initialize();
      expect(normalRestart.isTrusted(normal), isTrue);
      await storage.persistSession(jsonEncode(recovery.toJson()));
      // Refresh/userUpdated from this recovery session still cannot admit it.
      await storage.persistSession(
        jsonEncode(sampleSession('recovery-session', revision: 2).toJson()),
      );
      final recoveryRestart = RecoverySafeSessionStorage(backingStore: disk);
      await recoveryRestart.initialize();
      expect(await recoveryRestart.accessToken(), isNull);
      expect(storage.isTrusted(normal), isFalse);
    },
  );

  test(
    'legacy persisted session is cleared rather than silently trusted',
    () async {
      disk.saved = jsonEncode(recovery.toJson());
      final restarted = RecoverySafeSessionStorage(backingStore: disk);
      await restarted.initialize();
      expect(disk.saved, isNull);
      expect(await restarted.hasAccessToken(), isFalse);
    },
  );

  test(
    'overlapping login writes and recovery clearing cannot resurrect tokens',
    () async {
      final loginWrite = storage.admitPasswordLogin(normal);
      final recoveryWrite = storage.persistSession(
        jsonEncode(recovery.toJson()),
      );
      await Future.wait([loginWrite, recoveryWrite]);
      expect(disk.saved, isNull);
      expect(await storage.hasAccessToken(), isFalse);
      expect(
        disk.writes.any((value) => value.contains(recovery.refreshToken!)),
        isFalse,
      );
    },
  );

  test(
    'pending account password login is not admitted for restoration',
    () async {
      approved = false;
      await auth.signIn(email: 'test@example.test', password: 'ExamplePass1!');
      expect(auth.hasTrustedSession, isFalse);
      expect(await storage.hasAccessToken(), isFalse);
    },
  );

  test('failed reset keeps only a temporary retry session', () async {
    await client.auth.setInitialSession(jsonEncode(recovery.toJson()));
    failUpdate = true;
    await expectLater(
      auth.completePasswordRecovery('NewExample1!'),
      throwsException,
    );
    expect(auth.currentSession, isNotNull);
    expect(auth.hasTrustedSession, isFalse);
    expect(await storage.hasAccessToken(), isFalse);
  });

  testWidgets(
    'recovery session cannot fetch profile or open dashboard on startup',
    (tester) async {
      await client.auth.setInitialSession(jsonEncode(recovery.toJson()));
      await tester.pumpWidget(
        MaterialApp(home: SessionGate(authService: auth)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(profileRequests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password reset clears session before showing the success dialog',
    (tester) async {
      await client.auth.setInitialSession(jsonEncode(recovery.toJson()));
      await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(authService: auth)),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'NewExample1!');
      await tester.enterText(find.byType(TextFormField).at(1), 'NewExample1!');
      await tester.ensureVisible(find.text('Update password'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Update password'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      // The submit spinner is deliberately still active behind the dialog.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Password changed successfully.'), findsOneWidget);
      expect(auth.currentSession, isNull);
      expect(await storage.hasAccessToken(), isFalse);
      // Leaving the dialog unacknowledged and force-closing is now safe too.
      final restarted = RecoverySafeSessionStorage(backingStore: disk);
      await restarted.initialize();
      expect(await restarted.hasAccessToken(), isFalse);
      await tester.runAsync(() async {
        await tester.tap(find.text('Return to Login'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system Back cancels recovery even when server logout is offline',
    (tester) async {
      await client.auth.setInitialSession(jsonEncode(recovery.toJson()));
      offlineLogout = true;
      await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(authService: auth)),
      );
      await tester.runAsync(() async {
        await tester.binding.handlePopRoute();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(auth.currentSession, isNull);
      expect(await storage.hasAccessToken(), isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
