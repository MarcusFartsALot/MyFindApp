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
    String? country = lineValue(
      r'ISSUING COUNTRY|COUNTRY OF ISSUE|ISSUING STATE|CODE OF ISSUING STATE|COUNTRY CODE|CODE DU PAYS|KOD NEGARA',
    );
    DateTime? expiry;
    for (var i = 0; i + 1 < lines.length; i++) {
      final first = lines[i].replaceAll(RegExp(r'\s'), '');
      final second = lines[i + 1].replaceAll(RegExp(r'\s'), '');
      // OCR often omits trailing filler '<' characters. The required fields
      // still have fixed positions; never insert missing internal characters.
      if (first.length > 44 ||
          second.length < 28 ||
          second.length > 44 ||
          !RegExp(r'^P[A-Z<][A-Z<]{3}[A-Z<]+<<[A-Z<]+$').hasMatch(first)) {
        continue;
      }
      if (!RegExp(
        r'^[A-Z0-9<]{9}[0-9<][A-Z<]{3}[0-9]{6}[0-9<][FM<][0-9]{6}[0-9][A-Z0-9<]*$',
      ).hasMatch(second)) {
        continue;
      }
      final rawNumber = second.substring(0, 9);
      if (_checksum(rawNumber, second[9])) {
        number = rawNumber.replaceAll('<', '');
        name = first.substring(5).replaceAll(RegExp(r'<+'), ' ').trim();
      }
      final issuingCode = first.substring(2, 5);
      if (RegExp(r'^[A-Z]{3}$').hasMatch(issuingCode)) country ??= issuingCode;
      final nationalityCode = second.substring(10, 13);
      if (RegExp(r'^[A-Z]{3}$').hasMatch(nationalityCode)) {
        nationality ??= nationalityCode;
      }
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
    DateTime? labelledDate(String labels) {
      final heading = RegExp('(?:$labels)');
      final otherHeading = RegExp(
        r'\b(DATE|BIRTH|EXPIRY|ISSUE|TARIKH|PASSPORT|NAME|NATIONALITY|COUNTRY|SEX|PLACE|AUTHORITY|LAHIR|KELAHIRAN|NAMA|KEWARGANEGARAAN)\b',
      );
      for (var i = 0; i < lines.length; i++) {
        final matches = heading.allMatches(lines[i]);
        if (matches.isEmpty) continue;
        // Use the last repeated/bilingual caption, then at most the next line.
        final tail = lines[i].substring(matches.last.end);
        final followingHeading = otherHeading.firstMatch(tail);
        final value = followingHeading == null
            ? tail
            : tail.substring(0, followingHeading.start);
        final inline = _printedDate(value);
        if (inline != null) return inline;
        if (i + 1 < lines.length && !otherHeading.hasMatch(lines[i + 1])) {
          final nextLine = _printedDate(lines[i + 1]);
          if (nextLine != null) return nextLine;
        }
      }
      return null;
    }

    return PassportDetails(
      number: number,
      name: name,
      nationality: nationality,
      issuingCountry: country,
      issueDate: labelledDate(
        r'DATE\s+OF\s+ISSU(?:E|ANCE)|ISSU(?:E|ANCE)\s+DATE|TARIKH\s+(?:DIKELUARKAN|KELUARAN)|DATE\s+DE\s+D[ÉE]LIVRANCE',
      ),
      expiryDate:
          expiry ??
          labelledDate(
            r'DATE\s+OF\s+(?:EXPIRY|EXPIRATION)|(?:EXPIRY|EXPIRATION)\s+DATE|TARIKH\s+TAMAT|VALID\s+UNTIL|DATE\s+D.EXPIRATION',
          ),
    );
  }

  /// Autofill only the three requested fields; never replace manual corrections.
  /// Retakes replace/clear previous OCR values so stale passport data cannot linger.
  static PassportDetails mergeAutofill({
    required PassportDetails current,
    required PassportDetails scanned,
    PassportDetails previous = const PassportDetails(),
  }) {
    T? choose<T>(T? value, T? oldScan, T? nextScan) =>
        value == null || value == oldScan ? nextScan : value;
    return PassportDetails(
      number: current.number,
      name: current.name,
      nationality: current.nationality,
      issueDate: choose(
        current.issueDate,
        previous.issueDate,
        scanned.issueDate,
      ),
      expiryDate: choose(
        current.expiryDate,
        previous.expiryDate,
        scanned.expiryDate,
      ),
      issuingCountry: choose(
        current.issuingCountry,
        previous.issuingCountry,
        scanned.issuingCountry,
      ),
    );
  }

  static DateTime? _printedDate(String text) {
    final numeric = RegExp(
      r'\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4}|\d{1,2}\s+\d{1,2}\s+\d{4})\b',
    ).firstMatch(text);
    if (numeric != null) {
      final parts = numeric[0]!.split(RegExp(r'[-/.\s]+'));
      final values = parts.map(int.parse).toList();
      return parts[0].length == 4
          ? _date(values[0], values[1], values[2])
          : _date(values[2], values[1], values[0]);
    }
    final named = RegExp(
      r'\b(\d{1,2})[\s.-]+([A-ZÉÛ]+)\.?(?:\s*/\s*[A-ZÉÛ]+\.?)?[\s.-]+(\d{4}|\d{2})\b',
    ).firstMatch(text);
    if (named == null) return null;
    const months = {
      'JAN': 1,
      'JANUARY': 1,
      'JANUARI': 1,
      'FEB': 2,
      'FEBRUARY': 2,
      'FEBRUARI': 2,
      'FEV': 2,
      'FÉV': 2,
      'MAR': 3,
      'MARCH': 3,
      'MAC': 3,
      'APR': 4,
      'APRIL': 4,
      'AVR': 4,
      'MAY': 5,
      'MEI': 5,
      'MAI': 5,
      'JUN': 6,
      'JUNE': 6,
      'JUIN': 6,
      'JUL': 7,
      'JULY': 7,
      'JULAI': 7,
      'JUIL': 7,
      'AUG': 8,
      'AUGUST': 8,
      'OGOS': 8,
      'AOUT': 8,
      'AOÛT': 8,
      'SEP': 9,
      'SEPT': 9,
      'SEPTEMBER': 9,
      'OCT': 10,
      'OCTOBER': 10,
      'OKT': 10,
      'OKTOBER': 10,
      'NOV': 11,
      'NOVEMBER': 11,
      'DEC': 12,
      'DECEMBER': 12,
      'DÉC': 12,
      'DIS': 12,
      'DISEMBER': 12,
    };
    final month = months[named[2]];
    return month == null
        ? null
        : _date(_printedYear(named[3]!), month, int.parse(named[1]!));
  }

  static int _printedYear(String year) {
    final value = int.parse(year);
    if (year.length == 4) return value;
    // Interpret explicitly printed two-digit years in the nearest century.
    // This does not infer an issue date from birth/expiry dates.
    final now = DateTime.now().year;
    var candidate = (now ~/ 100) * 100 + value;
    if (candidate > now + 50) candidate -= 100;
    if (candidate < now - 50) candidate += 100;
    return candidate;
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
