import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  Future<String> submitVisaApplication({
    // 1. Applicant Info
    required String fullName, required String passportNo, required String passportIssueDate, required String passportExpiryDate,
    required String passportCountry, required String nationality, required String countryOfResidence, required String gender,
    required String dob, required String maritalStatus, required String educationLevel, required String occupation,
    required String email, required String phone, required String emergencyName, required String emergencyPhone, required String emergencyRel,

    // 2. Employment Info
    required String employmentStatus, required String companyName, required String companyAddress, required String companyPhone,
    required String jobTitle, required String yearsEmployed, required String monthlyIncome, required String annualIncome,

    // 3. Financial Info
    required String bankName, required String accountBalance, required String monthlyExpense,

    // 4. Travel Info
    required String purpose, required String arrivalDate, required String departureDate, required String visaExpiryDate,
    required String destination, required String hotelName, required String hotelAddress, required String accomType,
    required String airline, required String flightNo,

    // 5. Supporting Documents
    required String docType, required String docUrl,

    // 6. Payment & AI
    required String stripeTransactionId, required double paymentAmount, required Map<String, dynamic> aiResult,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Authentication error.');

      final profile = await _supabase.from('profiles').select('id').eq('auth_id', currentUser.id).single();
      final String userId = profile['id'];

      // 1. Master Table: visa_applications
      final visaApp = await _supabase.from('visa_applications').insert({
        'user_id': userId,
        'visa_type': 'Tourist (VM2026)',
        'application_status': 'Submitted',
        'submitted_at': DateTime.now().toIso8601String(),
      }).select().single();
      final String appId = visaApp['id'];

      int? calculatedAge;
      if (dob.isNotEmpty) {
        final parsedDate = DateTime.tryParse(dob);
        if (parsedDate != null) calculatedAge = DateTime.now().year - parsedDate.year;
      }

      // 2. applicant_information
      await _supabase.from('applicant_information').insert({
        'application_id': appId, 'full_name': fullName, 'passport_number': passportNo,
        'passport_issue_date': passportIssueDate.isNotEmpty ? passportIssueDate : null,
        'passport_expiry_date': passportExpiryDate.isNotEmpty ? passportExpiryDate : null,
        'passport_country': passportCountry, 'nationality': nationality, 'country_of_residence': countryOfResidence,
        'gender': gender, 'date_of_birth': dob.isNotEmpty ? dob : null, 'age': calculatedAge,
        'marital_status': maritalStatus, 'education_level': educationLevel, 'occupation': occupation,
        'email': email, 'phone': phone, 'emergency_contact_name': emergencyName,
        'emergency_contact_phone': emergencyPhone, 'emergency_relationship': emergencyRel,
      });

      // 3. employment_information
      await _supabase.from('employment_information').insert({
        'application_id': appId, 'employment_status': employmentStatus, 'company_name': companyName,
        'company_address': companyAddress, 'company_phone': companyPhone, 'job_title': jobTitle,
        'years_employed': int.tryParse(yearsEmployed), 'monthly_income': double.tryParse(monthlyIncome),
        'annual_income': double.tryParse(annualIncome),
      });

      // 4. financial_information
      await _supabase.from('financial_information').insert({
        'application_id': appId, 'bank_name': bankName, 'account_balance': double.tryParse(accountBalance),
        'monthly_expense': double.tryParse(monthlyExpense),
      });

      // 5. travel_information
      await _supabase.from('travel_information').insert({
        'application_id': appId, 'purpose_of_visit': purpose,
        'arrival_date': arrivalDate.isNotEmpty ? arrivalDate : null,
        'departure_date': departureDate.isNotEmpty ? departureDate : null,
        'visa_expiry_date': visaExpiryDate.isNotEmpty ? visaExpiryDate : null,
        'intended_destination': destination, 'hotel_name': hotelName, 'hotel_address': hotelAddress,
        'accommodation_type': accomType, 'airline': airline, 'flight_number': flightNo,
      });

      // 6. supporting_documents
      if (docUrl.isNotEmpty) {
        await _supabase.from('supporting_documents').insert({
          'application_id': appId, 'document_type': docType.isNotEmpty ? docType : 'Other',
          'file_url': docUrl, 'verified': false,
        });
      }

      // 7. payment_transactions
      await _supabase.from('payment_transactions').insert({
        'application_id': appId, 'stripe_transaction_id': stripeTransactionId,
        'amount': paymentAmount, 'currency': 'MYR', 'payment_status': 'Success',
      });

      // 8. risk_predictions
      await _supabase.from('risk_predictions').insert({
        'application_id': appId, 'risk_score': aiResult['risk_score'], 'confidence_score': 85.0,
        'risk_level': aiResult['risk_level'], 'recommendation': aiResult['recommendation'], 'prediction_reason': aiResult['prediction_reason'],
      });

      // 9. Automatic Activity Log for the Notification System
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Visa Application Submitted',
        'message': 'Your visa application for destination $destination has been successfully submitted and AI Calculated. Payment of MYR $paymentAmount received.',
        'type': 'Activity',
      });

      return appId;
    } catch (e) {
      rethrow;
    }
  }
}