import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Single source of validation rules for submitting and editing incidents.
abstract final class ReportValidation {
  static String? text(String? value, {int min = 0, required int max}) {
    final length = (value ?? '').trim().characters.length;
    if (length < min) return 'Enter at least $min characters.';
    if ((value ?? '').characters.length > max) {
      return 'Use no more than $max characters.';
    }
    return null;
  }

  static String? phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return text(value, max: 24) != null ||
            !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(value.trim()) ||
            digits.length < 7 ||
            digits.length > 15
        ? 'Enter a valid phone number with 7–15 digits.'
        : null;
  }

  static String? postcode(String value, String country) {
    final code = value.trim();
    if (country.trim().toLowerCase() == 'malaysia') {
      return RegExp(r'^\d{5}$').hasMatch(code)
          ? null
          : 'Enter a 5-digit Malaysian postcode.';
    }
    return code.isEmpty || RegExp(r'^[a-zA-Z0-9 -]{2,12}$').hasMatch(code)
        ? null
        : 'Enter a valid postcode (2–12 letters, digits, spaces or hyphens).';
  }

  static bool validPin(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static String? evidence(PlatformFile file) {
    if (![
      'jpg',
      'jpeg',
      'png',
      'mp4',
      'mov',
    ].contains(file.extension?.toLowerCase())) {
      return 'Choose a JPG, PNG, MP4 or MOV file.';
    }
    if (file.size <= 0 || file.size >= 10 * 1024 * 1024) {
      return 'Choose a nonempty file smaller than 10 MB.';
    }
    if (file.path == null && file.bytes == null) {
      return 'This file is unavailable. Please select it again.';
    }
    return null;
  }
}
