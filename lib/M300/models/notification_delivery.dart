import 'package:shared_preferences/shared_preferences.dart';

/// Popup delivery is separate from read status and survives sign-in/app restarts.
class NotificationDelivery {
  final Set<String> _offered = {};
  final Set<String> _shown = {};
  SharedPreferences? _preferences;
  String? _storageKey;
  int _initializationRevision = 0;

  Future<void> initialize(String userId) async {
    final revision = ++_initializationRevision;
    final key = 'm300.shown-alerts.$userId';
    _storageKey = key;
    _preferences = null;
    _offered.clear();
    _shown.clear();
    final preferences = await SharedPreferences.getInstance();
    if (_initializationRevision != revision) return;
    _preferences = preferences;
    _shown.addAll(preferences.getStringList(key) ?? const <String>[]);
  }

  Future<void> markShown(String id) async {
    _shown.add(id);
    final key = _storageKey;
    final preferences = _preferences;
    if (key != null && preferences != null) {
      await preferences.setStringList(key, _shown.toList());
    }
  }

  List<Map<String, dynamic>> takeUnreadAlerts(
    List<Map<String, dynamic>> records,
  ) {
    return records.where((item) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty ||
          _shown.contains(id) ||
          item['is_read'] != false ||
          item['type'] != 'Alert') {
        return false;
      }
      return _offered.add(id);
    }).toList();
  }
}
