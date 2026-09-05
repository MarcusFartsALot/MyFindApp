/// Reads only explicit labels or the name immediately beneath a MyKad number.
/// Raw OCR and the recognized identity number are never put into form fields.
class MyKadDetails {
  const MyKadDetails({this.name, this.nationality, this.gender});
  final String? name, nationality, gender;
}

class MyKadDetailsParser {
  static MyKadDetails parse(String text) {
    final lines = text
        .toUpperCase()
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    bool plausibleName(String value) =>
        RegExp(r"^[A-Z][A-Z '.@/-]{2,99}$").hasMatch(value) &&
        !RegExp(
          r'\b(MALAYSIA|MYKAD|PENGENALAN|WARGANEGARA|LELAKI|PEREMPUAN|ISLAM|JALAN|TAMAN|ALAMAT|PASSPORT|KAD|ADDRESS)\b',
        ).hasMatch(value);
    String? name;
    for (var i = 0; i < lines.length; i++) {
      final label = RegExp(
        r'^(?:NAMA(?: PENUH)?|NAME)\s*[:.]?\s*(.*)$',
      ).firstMatch(lines[i]);
      if (label != null) {
        final candidate = label[1]!.isNotEmpty
            ? label[1]!
            : (i + 1 < lines.length ? lines[i + 1] : '');
        if (plausibleName(candidate)) {
          name = candidate;
          break;
        }
      }
    }
    if (name == null) {
      for (var i = 0; i + 1 < lines.length; i++) {
        if (RegExp(r'^\d{6}[- ]?\d{2}[- ]?\d{4}$').hasMatch(lines[i]) &&
            plausibleName(lines[i + 1])) {
          name = lines[i + 1];
          break;
        }
      }
    }
    return MyKadDetails(
      name: name,
      nationality: lines.any((line) => line == 'WARGANEGARA')
          ? 'Malaysian'
          : null,
      gender: lines.contains('LELAKI')
          ? 'male'
          : lines.contains('PEREMPUAN')
          ? 'female'
          : null,
    );
  }
}
