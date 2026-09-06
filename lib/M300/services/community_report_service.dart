import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../models/incident_report_model.dart';

class CommunityReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Maximum file size threshold (10 MB)
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// Bucket name matching your Supabase Storage
  static const String bucketName = 'incident-evidence';

  /// Submits a new incident report to Supabase
  Future<IncidentReportModel> submit({
    required String creatorProfileId,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String category,
    required String urgencyLevel,
    required String location,
    required String address,
    required DateTime incidentDate,
    required String incidentTime,
    required String description,
    double? latitude,
    double? longitude,
    required List<String> mediaPaths,
  }) async {
    try {
      // 1. Fetch citizen's IC number from the 'citizens' table
      final citizenResponse = await _supabase
          .from('citizens')
          .select('ic_number')
          .eq('profile_id', creatorProfileId)
          .maybeSingle();

      final rawIcNumber = citizenResponse?['ic_number'] as String?;

      if (rawIcNumber == null || rawIcNumber.trim().isEmpty) {
        throw AppException(
          'Citizen verification record (IC) not found for this user.',
        );
      }

      // 2. Hash IC Number using SHA-256
      final bytes = utf8.encode(rawIcNumber.trim());
      final icHash = sha256.convert(bytes).toString();

      // 3. Generate unique Ticket ID
      final ticketId =
          'REP-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

      // 4. Construct payload matching PostgreSQL schema constraints exactly
      final reportData = {
        'ticket_id': ticketId,
        'creator_profile_id': creatorProfileId,
        'creator_ic_hash': icHash,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'email': email,
        'category': category,
        'urgency_level': urgencyLevel,
        'location': location,
        'address': address,
        'incident_date': incidentDate.toIso8601String().split('T').first,
        'incident_time': incidentTime,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'media_paths': mediaPaths,
        'status': 'Pending Review', // Matches DB check constraint exactly
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('incident_reports')
          .insert(reportData)
          .select()
          .single();

      return IncidentReportModel.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to submit incident report: $e');
    }
  }

  /// Creates an in-app notification entry for a user
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'Activity',
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to create notification: $e');
    }
  }

  /// Fetches all incident reports submitted by a specific user email
  Future<List<Map<String, dynamic>>> getUserReports(String email) async {
    try {
      final response = await _supabase
          .from('incident_reports')
          .select()
          .eq('email', email)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw AppException('Failed to fetch user reports: $e');
    }
  }

  /// Fetches a single incident report by its unique Ticket ID
  Future<Map<String, dynamic>?> getReportByTicket(String ticketId) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      if (email == null) {
        throw AppException('Please sign in to view this ticket.');
      }
      final response = await _supabase
          .from('incident_reports')
          .select()
          .eq('ticket_id', ticketId)
          .eq('email', email)
          .maybeSingle();

      return response;
    } catch (e) {
      throw AppException('Failed to fetch report by ticket ID: $e');
    }
  }

  /// Helper method to map file extensions to official MIME types
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads evidence files into either 'Image/' or 'Video/' subfolders
  Future<List<String>> uploadEvidence(List<PlatformFile> files) async {
    final List<String> uploadedPaths = [];

    for (final file in files) {
      final extension = file.name.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);

      // Determine accurate standard MIME type
      final mimeType = _getMimeType(extension);

      // Determine subfolder and build timestamped file path
      final folder = isVideo ? 'Video' : 'Image';
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedFileName = file.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final storagePath = '$folder/${timeStamp}_$sanitizedFileName';

      try {
        if (kIsWeb) {
          if (file.bytes == null) continue;
          await _supabase.storage
              .from(bucketName)
              .uploadBinary(
                storagePath,
                file.bytes!,
                fileOptions: FileOptions(contentType: mimeType),
              );
        } else {
          if (file.path == null) continue;
          await _supabase.storage
              .from(bucketName)
              .upload(
                storagePath,
                File(file.path!),
                fileOptions: FileOptions(contentType: mimeType),
              );
        }

        uploadedPaths.add(storagePath);
      } catch (e) {
        throw AppException('Failed to upload file "${file.name}": $e');
      }
    }

    return uploadedPaths;
  }

  /// Updates an existing pending incident report in Supabase
  Future<void> updatePending({
    required String reportId,
    required String description,
    required String location,
    required String address,
    double? latitude,
    double? longitude,
    required List<String> mediaPaths,
  }) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      if (email == null) {
        throw AppException('Please sign in before updating a report.');
      }
      final updatedReports = await _supabase
          .from('incident_reports')
          .update({
            'description': description,
            'location': location,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'media_paths': mediaPaths,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId)
          .eq('email', email)
          .eq('status', 'Pending Review')
          .select('id');

      if (updatedReports.isEmpty) {
        throw AppException(
          'This report can no longer be edited because it is not Pending Review.',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Failed to update incident report: $e');
    }
  }
}
