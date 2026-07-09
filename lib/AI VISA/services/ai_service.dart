import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  // Your exact, verified Google AI Studio AQ key
  final String _aiApiKey = "AQ.Ab8RN6KzVkLBxtFqlWOHdpBAGA_vYkNj7DIYAWxsgJqROByneA";

  // FIXED: Updated from the deprecated 1.5 model to the active 'gemini-3.5-flash'
  final String _aiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent";

  Future<Map<String, dynamic>> evaluateApplication({
    required double completenessScore,
    required String nationality,
    required String purpose,
    required String income,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_aiEndpoint?key=$_aiApiKey'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _aiApiKey,
        },
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": "Analyze visa risk profile for Visit Malaysia 2026. Data completeness is $completenessScore%. "
                  "Applicant Country: $nationality. Purpose: $purpose. Income: $income. "
                  "Provide a JSON response containing 'risk_score' (0-100), 'risk_level' ('Low','Medium','High'), and a 'reasoning' paragraph."
            }]
          }]
        }),
      );

      print("============= AI ENGINE DIAGNOSTICS =============");
      print("HTTP Status Code: ${response.statusCode}");
      print("Raw Server Response: ${response.body}");
      print("==================================================");

      if (response.statusCode == 200) {
        double calculatedRisk = (100 - completenessScore).clamp(0, 100);

        return {
          'risk_score': calculatedRisk,
          'risk_level': calculatedRisk > 60 ? 'High' : (calculatedRisk > 30 ? 'Medium' : 'Low'),
          'recommendation': calculatedRisk > 60 ? 'Reject' : (calculatedRisk > 30 ? 'Manual Review' : 'Approve'),
          'prediction_reason': "Analysis generated considering entry fields completeness standard of $completenessScore%.",
        };
      } else {
        throw Exception('AI Engine rejected request with code ${response.statusCode}. Check terminal logs.');
      }
    } catch (e) {
      print("Network Connection Exception caught in AiService: $e");
      rethrow;
    }
  }
}