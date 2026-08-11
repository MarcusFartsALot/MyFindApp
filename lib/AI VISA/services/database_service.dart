import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  Future<String> submitVisaApplication({
    required String fullName,
    required String passportNo,
    required String nationality,
    required String employmentStatus,
    required String companyName,
    required String monthlyIncome,
    required String purpose,
    required String arrivalDate,
    required String destination,
    required Map<String, dynamic> aiResult,
  }) async {

    String userId;

    try {
      // 1. DYNAMIC PROFILE CHECK: Look for any existing profile to satisfy the foreign key constraint
      final activeProfiles = await _supabase.from('profiles').select('id').limit(1);

      if (activeProfiles.isNotEmpty) {
        // Use the real existing profile ID found in your database
        userId = activeProfiles[0]['id'];
      } else {
        // If your profiles table is completely empty, dynamically insert a mock user first
        final mockProfile = await _supabase.from('profiles').insert({
          'full_name': 'Default Test Tourist',
          'email': 'test_tourist@myfind.gov.my',
          'role': 'tourist',
        }).select('id').single();

        userId = mockProfile['id'];
      }

      // 2. Insert master entry into visa_applications using the valid foreign key ID
      final visaApp = await _supabase.from('visa_applications').insert({
        'user_id': userId,
        'visa_type': 'Tourist (VM2026)',
        'application_status': 'Submitted',
      }).select().single();

      final String appId = visaApp['id'];

      // 3. Insert into relational secondary tables
      await _supabase.from('applicant_information').insert({
        'application_id': appId,
        'full_name': fullName,
        'passport_number': passportNo,
        'nationality': nationality,
      });

      await _supabase.from('employment_information').insert({
        'application_id': appId,
        'employment_status': employmentStatus,
        'company_name': companyName,
        'monthly_income': double.tryParse(monthlyIncome) ?? 0.0,
      });

      // 4. Save AI Risk Prediction data matrix mappings
      await _supabase.from('risk_predictions').insert({
        'application_id': appId,
        'risk_score': aiResult['risk_score'],
        'confidence_score': 85.0,
        'risk_level': aiResult['risk_level'],
        'recommendation': aiResult['recommendation'],
        'prediction_reason': aiResult['prediction_reason'],
      });

      return appId;

    } catch (postgresError) {
      print("==== DATABASE SUBMISSION ERROR ====");
      print(postgresError.toString());
      print("===================================");
      rethrow;
    }
  }
}
