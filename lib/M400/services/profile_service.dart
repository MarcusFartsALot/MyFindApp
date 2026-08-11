import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../models/profile_model.dart';

/// Read/write helpers for the `profiles` table that go beyond plain
/// authentication - used by officers/admins reviewing tourist
/// applications.
class ProfileService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ProfileModel>> fetchPendingTourists() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('*, tourists!tourists_profile_id_fkey!inner(*)')
          .eq('role', 'tourist')
          .eq('tourists.verification_status', 'pending')
          .order('created_at');
      return (rows as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return ProfileModel.fromRecords(row, _embeddedRecord(row['tourists']));
      }).toList();
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> approveTourist(String profileId) async {
    try {
      await _client
          .from('tourists')
          .update({'verification_status': 'approved', 'rejection_reason': null})
          .eq('profile_id', profileId);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> rejectTourist(String profileId, {required String reason}) async {
    try {
      await _client
          .from('tourists')
          .update({
            'verification_status': 'rejected',
            'rejection_reason': reason,
          })
          .eq('profile_id', profileId);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Map<String, dynamic>? _embeddedRecord(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }
}
