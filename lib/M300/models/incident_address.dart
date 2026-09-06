import 'package:geocoding/geocoding.dart';

/// Editable address components; the existing database still stores one address.
class IncidentAddress {
  final String line1, line2, city, postcode, state, country;
  const IncidentAddress({
    this.line1 = '',
    this.line2 = '',
    this.city = '',
    this.postcode = '',
    this.state = '',
    this.country = '',
  });

  factory IncidentAddress.fromPlacemark(Placemark place) {
    final city = (place.locality ?? '').trim();
    final postcode = (place.postalCode ?? '').trim();
    final state = (place.administrativeArea ?? '').trim();
    final country = (place.country ?? '').trim();
    final district = (place.subLocality ?? '').trim();
    // Some providers return a complete formatted address in `street`.
    // Remove locality components there before displaying individual fields.
    final excluded = [
      city,
      postcode,
      state,
      country,
      district,
      '$postcode $city',
      '$city $postcode',
    ].where((v) => v.isNotEmpty).map((v) => v.toLowerCase()).toSet();
    final street = (place.street ?? '')
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && !excluded.contains(v.toLowerCase()));
    return IncidentAddress(
      line1: joinUnique(street),
      line2: district,
      city: city,
      postcode: postcode,
      state: state,
      country: country,
    );
  }

  /// Recover locality fields from previously saved comma-separated addresses.
  /// Unrecognised layouts stay intact rather than guessing or dropping text.
  factory IncidentAddress.fromFormatted(String value) {
    final parts = joinUnique([
      value,
    ]).split(', ').where((p) => p.isNotEmpty).toList();
    final postalCity = RegExp(r'^(\d{5})\s+(.+)$');
    final index = parts.indexWhere((p) => postalCity.hasMatch(p));
    if (index < 0) return IncidentAddress(line1: value.trim());
    final match = postalCity.firstMatch(parts[index])!;
    final before = parts.take(index).toList();
    final redundant = {
      ...before.map((p) => p.toLowerCase()),
      match.group(1)!.toLowerCase(),
      match.group(2)!.toLowerCase(),
    };
    final after = parts
        .skip(index + 1)
        .where((p) => !redundant.contains(p.toLowerCase()))
        .toList();
    // The saved form orders its last components as postcode+city, state, country.
    // Keep unexpected trailing components in the address instead of discarding them.
    if (after.length > 2) return IncidentAddress(line1: value.trim());
    return IncidentAddress(
      line1: before.length > 2
          ? before.take(before.length - 1).join(', ')
          : before.join(', '),
      line2: before.length > 2 ? before.last : '',
      postcode: match.group(1)!,
      city: match.group(2)!,
      state: after.length == 2 ? after.first : '',
      country: after.isNotEmpty ? after.last : '',
    );
  }

  static String joinUnique(Iterable<String> values) {
    final seen = <String>{};
    return values
        .expand((v) => v.split(','))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && seen.add(v.toLowerCase()))
        .join(', ');
  }

  String get formatted => joinUnique([
    line1,
    line2,
    [postcode.trim(), city.trim()].where((v) => v.isNotEmpty).join(' '),
    state,
    country,
  ]);
}
