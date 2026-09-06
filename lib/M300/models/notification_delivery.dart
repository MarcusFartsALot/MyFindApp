/// Tracks alerts offered during this dashboard session. Read alerts and personal
/// activities do not produce popups, including on reconnect/catch-up snapshots.
class NotificationDelivery {
  final Set<String> _offered = {};

  List<Map<String, dynamic>> takeUnreadAlerts(
    List<Map<String, dynamic>> records,
  ) {
    return records.where((item) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty || item['is_read'] != false || item['type'] != 'Alert') {
        return false;
      }
      return _offered.add(id);
    }).toList();
  }

  void clear() => _offered.clear();
}
