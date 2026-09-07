import 'package:flutter/material.dart';

/// Holds background alerts while a dialog or bottom sheet occupies the navigator.
class NotificationPopupObserver extends NavigatorObserver {
  static final instance = NotificationPopupObserver();
  final Set<Route<dynamic>> _popups = {};
  final ValueNotifier<bool> blocked = ValueNotifier(false);

  void _publish() {
    blocked.value = _popups.isNotEmpty;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _popups.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popups.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _popups.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _popups.remove(oldRoute);
    if (newRoute is PopupRoute) _popups.add(newRoute);
    _publish();
  }
}
