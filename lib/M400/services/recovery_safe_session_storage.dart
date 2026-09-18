import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persist only sessions admitted by a completed password login. Recovery
/// links, token refreshes and user updates cannot admit a session themselves.
/// This is a routing/persistence policy, not a replacement for server RLS.
class RecoverySafeSessionStorage extends LocalStorage {
  RecoverySafeSessionStorage({required LocalStorage backingStore})
    : _backingStore = backingStore;
  final LocalStorage _backingStore;
  String? _trustedId;
  String? _savedSession;
  Future<void> _writes = Future<void>.value();

  static String? sessionId(Session? session) =>
      session == null ? null : _tokenSessionId(session.accessToken);
  static String? _tokenSessionId(String token) {
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final id = claims['session_id'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  static String? _serializedId(String serialized) {
    try {
      return _tokenSessionId(jsonDecode(serialized)['access_token'] as String);
    } catch (_) {
      return null;
    }
  }

  bool isTrusted(Session? session) =>
      _trustedId != null && sessionId(session) == _trustedId;

  Future<void> _enqueue(Future<void> Function() operation) {
    final write = _writes.then((_) => operation());
    // A failed write must not prevent a later logout/clear operation.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  @override
  Future<void> initialize() async {
    await _backingStore.initialize();
    final raw = await _backingStore.accessToken();
    if (raw == null) return;
    try {
      final envelope = jsonDecode(raw);
      final serialized = envelope['session'];
      final id = envelope['password_login_session_id'];
      if (envelope['m400_version'] == 1 &&
          serialized is String &&
          id is String &&
          id.isNotEmpty &&
          _serializedId(serialized) == id) {
        _trustedId = id;
        _savedSession = serialized;
        return;
      }
    } catch (_) {
      // Legacy raw sessions cannot prove a password login. Do not restore a
      // recovery session that was saved by an older app version.
    }
    await removePersistedSession();
  }

  @override
  Future<bool> hasAccessToken() async => _savedSession != null;
  @override
  Future<String?> accessToken() async => _savedSession;

  /// Call only after signInWithPassword and profile approval checks succeed.
  Future<void> admitPasswordLogin(Session session) async {
    final id = sessionId(session);
    if (id == null) throw StateError('Login session identifier is missing.');
    _trustedId = id;
    try {
      await persistSession(jsonEncode(session.toJson()));
    } catch (_) {
      await removePersistedSession();
      rethrow;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    final id = _serializedId(persistSessionString);
    if (id == null || id != _trustedId) {
      // The SDK saves every non-null auth event, including passwordRecovery.
      // Never write an unapproved token, even briefly before an event handler.
      return removePersistedSession();
    }
    _savedSession = persistSessionString;
    final envelope = jsonEncode({
      'm400_version': 1,
      'password_login_session_id': id,
      'session': persistSessionString,
    });
    return _enqueue(() => _backingStore.persistSession(envelope));
  }

  @override
  Future<void> removePersistedSession() {
    _trustedId = null;
    _savedSession = null;
    return _enqueue(_backingStore.removePersistedSession);
  }
}
