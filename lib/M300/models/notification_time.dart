/// Notification writers use UTC. Legacy database values omit the UTC suffix.
abstract final class NotificationTime {
  static DateTime? parse(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final hasZone = RegExp(
      r'(Z|[+-]\d{2}(?::?\d{2})?)$',
      caseSensitive: false,
    ).hasMatch(text);
    // Do not reinterpret explicit offsets or accept a date-only value as a time.
    if (!text.contains(':')) return null;
    return DateTime.tryParse(hasZone ? text : '${text}Z');
  }

  static String format(String? value) {
    final date = parse(value)?.toLocal();
    if (date == null) return 'Time unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute ${date.hour < 12 ? 'AM' : 'PM'} · local time';
  }
}
