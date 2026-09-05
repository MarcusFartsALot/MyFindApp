/// Conservative, local OCR parsing. Missing or uncertain values stay empty.
class PassportDetails {
  const PassportDetails({
    this.number,
    this.name,
    this.nationality,
    this.issuingCountry,
    this.issueDate,
    this.expiryDate,
  });
  final String? number, name, nationality, issuingCountry;
  final DateTime? issueDate, expiryDate;
}

class PassportDetailsParser {
  static PassportDetails parse(String text) {
    final lines = text
        .toUpperCase()
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    String? labelled(String label, String pattern) {
      return RegExp(
        '(?:$label)\\s*[:.]?\\s*($pattern)',
        caseSensitive: false,
      ).firstMatch(text)?.group(1)?.trim();
    }

    String? number = labelled(
      r'PASSPORT\s*(?:NO\.?|NUMBER)|NO\.?\s*PASPORT',
      r'[A-Z0-9]{6,20}\b',
    );
    String? lineValue(String labels) {
      for (var i = 0; i < lines.length; i++) {
        final match = RegExp(
          '^(?:$labels)\\s*[:.]?\\s*(.*)\$',
        ).firstMatch(lines[i]);
        if (match == null) continue;
        final value = match[1]!.trim().isNotEmpty
            ? match[1]!.trim()
            : (i + 1 < lines.length ? lines[i + 1] : '');
        if (RegExp(r"^[A-Z][A-Z '.-]{2,99}$").hasMatch(value) &&
            !RegExp(
              r'\b(PASSPORT|NATIONALITY|DATE|SEX|NAME|NUMBER|COUNTRY|PLACE)\b',
            ).hasMatch(value)) {
          return value;
        }
      }
      return null;
    }

    String? name = lineValue(r'FULL NAME|NAME|NAMA');
    String? nationality = lineValue(r'NATIONALITY|KEWARGANEGARAAN');
    String? country = lineValue(r'ISSUING COUNTRY|COUNTRY OF ISSUE');
    DateTime? expiry;
    for (var i = 0; i + 1 < lines.length; i++) {
      final first = lines[i].replaceAll(' ', '');
      final second = lines[i + 1].replaceAll(' ', '');
      if (!first.startsWith('P<') ||
          first.length != 44 ||
          second.length != 44) {
        continue;
      }
      if (!RegExp(r'^[A-Z<]{44}$').hasMatch(first) ||
          !RegExp(r'^[A-Z0-9<]{44}$').hasMatch(second)) {
        continue;
      }
      final rawNumber = second.substring(0, 9);
      if (!_checksum(rawNumber, second[9])) continue;
      number = rawNumber.replaceAll('<', '');
      name = first.substring(5).replaceAll(RegExp(r'<+'), ' ').trim();
      country = first.substring(2, 5).replaceAll('<', '');
      nationality = second.substring(10, 13).replaceAll('<', '');
      final rawExpiry = second.substring(21, 27);
      if (_checksum(rawExpiry, second[27])) {
        final yy = int.tryParse(rawExpiry.substring(0, 2));
        final mm = int.tryParse(rawExpiry.substring(2, 4));
        final dd = int.tryParse(rawExpiry.substring(4, 6));
        if (yy != null && mm != null && dd != null) {
          expiry = _date(2000 + yy, mm, dd);
        }
      }
      break;
    }
    DateTime? labelledDate(String label) {
      final raw = labelled(
        label,
        r'\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4}',
      );
      if (raw == null) return null;
      final parts = raw.split(RegExp(r'[-/]'));
      final values = parts.map(int.parse).toList();
      return parts[0].length == 4
          ? _date(values[0], values[1], values[2])
          : _date(values[2], values[1], values[0]);
    }

    return PassportDetails(
      number: number,
      name: name,
      nationality: nationality,
      issuingCountry: country,
      issueDate: labelledDate(r'DATE\s+OF\s+ISSUE'),
      expiryDate: expiry ?? labelledDate(r'DATE\s+OF\s+EXPIRY|EXPIRY\s+DATE'),
    );
  }

  static DateTime? _date(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static bool _checksum(String value, String check) {
    if (!RegExp(r'^\d$').hasMatch(check)) return false;
    var sum = 0;
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      final digit = value[i] == '<'
          ? 0
          : code >= 65
          ? code - 55
          : code - 48;
      sum += digit * [7, 3, 1][i % 3];
    }
    return sum % 10 == int.parse(check);
  }
}
