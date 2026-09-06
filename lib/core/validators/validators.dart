class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) {
      return 'Include at least one special character';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Generic international passport number validator.
  ///
  /// Passport formats differ by issuing country (length and allowed
  /// characters both vary), so a single regex cannot perfectly
  /// validate every country's scheme. This enforces the common ICAO
  /// baseline used by this application: 6-20 uppercase
  /// alphanumeric characters, no spaces or symbols. It intentionally
  /// does NOT attempt per-country checksum validation - if you need
  /// that level of certainty, pair this with a document-verification
  /// provider (e.g. Onfido, Jumio) that OCRs and validates the MRZ
  /// (machine-readable zone) on the photo itself.
  static String? passportNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Passport number is required';
    }
    final v = value.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z0-9]{6,20}$');
    if (!regex.hasMatch(v)) {
      return 'Passport number must be 6-20 letters/numbers, no spaces or symbols';
    }
    return null;
  }

  /// Malaysian IC (MyKad) validator: format YYMMDD-PB-###G
  /// - YYMMDD must be a real calendar date
  /// - PB is the birthplace/state code (not validated against the
  ///   exact official code list here - add one if you need it)
  /// - last 4 digits: 3-digit serial + 1-digit gender indicator
  ///   (odd = male, even = female) - not independently checkable,
  ///   so only the digit-count and date are validated.
  static String? malaysianIC(String? value) {
    if (value == null || value.trim().isEmpty) return 'IC number is required';
    final digitsOnly = value.replaceAll('-', '').trim();
    if (!RegExp(r'^\d{12}$').hasMatch(digitsOnly)) {
      return 'IC must be 12 digits (format: YYMMDD-PB-###G)';
    }
    final yy = int.parse(digitsOnly.substring(0, 2));
    final mm = int.parse(digitsOnly.substring(2, 4));
    final dd = int.parse(digitsOnly.substring(4, 6));
    if (mm < 1 || mm > 12) return 'IC contains an invalid birth month';
    final year = yy <= _currentTwoDigitYear() ? 2000 + yy : 1900 + yy;
    final daysInMonth = DateTime(year, mm + 1, 0).day;
    if (dd < 1 || dd > daysInMonth) return 'IC contains an invalid birth date';
    return null;
  }

  static int _currentTwoDigitYear() => DateTime.now().year % 100;

  static String? myKadGender(String? identityNumber, String? gender) {
    final error = malaysianIC(identityNumber);
    if (error != null) return error;
    if (gender != 'male' && gender != 'female') {
      return 'Select the gender shown on your MyKad';
    }
    final digits = identityNumber!.replaceAll('-', '').trim();
    final expected = int.parse(digits[11]).isOdd ? 'male' : 'female';
    return gender == expected
        ? null
        : 'Gender does not match the MyKad number. Check the number and document gender.';
  }
}
