import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/exceptions/app_exceptions.dart';
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
          .select()
          .eq('role', 'tourist')
          .eq('verification_status', 'pending')
          .order('created_at');
      return (rows as List).map((r) => ProfileModel.fromJson(r)).toList();
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> approveTourist(String profileId) async {
    try {
      await _client.from('profiles').update({
        'verification_status': 'approved',
      }).eq('id', profileId);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }

  Future<void> rejectTourist(String profileId, {required String reason}) async {
    try {
      await _client.from('profiles').update({
        'verification_status': 'rejected',
        'rejection_reason': reason,
      }).eq('id', profileId);
    } catch (e) {
      throw ExceptionMapper.map(e);
    }
  }
}
