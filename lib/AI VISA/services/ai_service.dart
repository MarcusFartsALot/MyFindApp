import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String _aiApiKey = "AQ.Ab8RN6KzVkLBxtFqlWOHdpBAGA_vYkNj7DIYAWxsgJqROByneA";
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
              "text": "You are an official immigration risk assessment AI for Visit Malaysia 2026 (VM2026). "
                  "Rigorously evaluate the following applicant profile: "
                  "Data Completeness Score: $completenessScore%. "
                  "Applicant Nationality: $nationality. "
                  "Purpose of Visit: $purpose. "
                  "Monthly Income / Financials: $income. "
                  "STRICT RULES FOR EVALUATION: "
                  "1. If data completeness is below 90% or critical financial fields are empty/low, heavily penalize the score. "
                  "2. Calculate a precise 'risk_score' from 0 to 100 (where 0 is no risk, 100 is extreme overstay risk). "
                  "3. Determine 'risk_level' as 'Low', 'Medium', or 'High'. "
                  "4. Provide a professional, strict immigration 'reasoning' paragraph. "
                  "Return ONLY a valid JSON object with keys: 'risk_score' (number), 'risk_level' (string), 'recommendation' ('Approve'|'Manual Review'|'Reject'), 'prediction_reason' (string)."
            }]
          }]
        }),
      );

      print("============= AI ENGINE DIAGNOSTICS =============");
      print("HTTP Status Code: ${response.statusCode}");
      print("Raw Server Response: ${response.body}");
      print("==================================================");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidateText = data['candidates'][0]['content']['parts'][0]['text'];

        // Clean up markdown formatting if Gemini includes ```json ... ```
        final cleanedJsonText = candidateText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final Map<String, dynamic> parsedAiResult = jsonDecode(cleanedJsonText);

        return {
          'risk_score': parsedAiResult['risk_score'] ?? (100.0 - completenessScore),
          'risk_level': parsedAiResult['risk_level'] ?? 'Medium',
          'recommendation': parsedAiResult['recommendation'] ?? 'Manual Review',
          'prediction_reason': parsedAiResult['prediction_reason'] ?? 'Evaluated based on profile parameters.',
        };
      } else {
        throw Exception('AI Engine rejected request with code ${response.statusCode}.');
      }
    } catch (e) {
      print("Network/Parsing Exception caught in AiService: $e");
      // Fallback strict algorithmic calculation if network parsing fails
      double fallbackRisk = (100.0 - completenessScore).clamp(0, 100);
      return {
        'risk_score': fallbackRisk,
        'risk_level': fallbackRisk > 50 ? 'High' : 'Low',
        'recommendation': fallbackRisk > 50 ? 'Reject' : 'Approve',
        'prediction_reason': 'Fallback evaluation applied due to strict parsing rules.',
      };
    }
  }
}