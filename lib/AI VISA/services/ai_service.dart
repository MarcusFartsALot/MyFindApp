import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  final String _aiApiKey = "AQ.Ab8RN6KzVkLBxtFqlWOHdpBAGA_vYkNj7DIYAWxsgJqROByneA";
  final String _aiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent";

  /// Evaluates the entire structured application dataset for security, financial sanity, and semantic consistency
  Future<Map<String, dynamic>> evaluateApplication({
    required Map<String, dynamic> fullApplicationData,
  }) async {
    try {
      final String jsonPayload = jsonEncode(fullApplicationData);

      final String systemPrompt = '''
You are an expert Senior Immigration Security Officer and Threat Intelligence AI Engine for Visit Malaysia 2026 (VM2026).
Your responsibility is to thoroughly analyze the full submitted visa application for security threats, malicious intent, financial viability, and logical inconsistencies.

DO NOT simply award a high approval rate because fields are filled out. You must critically audit the SUBSTANCE, INTENT, AND SANITY of every answer.

SUBMITTED APPLICATION DATA (JSON):
$jsonPayload

EVALUATION RUBRIC & MANDATORY AUDIT DIRECTIVES:

1. SECURITY THREAT & MALICIOUS INTENT SCREENING (HIGHEST PRIORITY):
   - Audit all free-text inputs (Purpose of Visit, Occupation, Company Name, Hotel Name, Emergency Details, etc.).
   - Search for illegal intent, hostile/violent statements (e.g., "to kill people", "drugs", "illegal work", "overstay"), criminal threats, or nonsensical gibberish (e.g., "asdfghj", "123456").
   - RED FLAG RULE: If ANY illegal, violent, or hostile intent is detected (such as "to kill people"), IMMEDIATELY output:
     * risk_score = 100
     * risk_level = "High"
     * recommendation = "Reject"
     * prediction_reason = "CRITICAL SECURITY THREAT DETECTED: Illegal or hostile intent stated in submitted information."

2. FINANCIAL FEASIBILITY & LOGICAL SANITY:
   - Cross-examine Monthly Income, Annual Income, Account Balance, and Monthly Expenses (All provided in MYR).
   - Evaluate whether the liquid account balance is realistic and sufficient to support the specified destination, hotel, flight, and travel duration.
   - Detect contradictions (e.g., zero account balance with high expenses, or inflated claims).

3. EMPLOYMENT & TIES TO HOME COUNTRY:
   - Unemployed applicants with insufficient liquid funds represent a high overstay risk. Scrutinize their stated occupation and employment status.

4. LOGISTICAL CONSISTENCY:
   - Verify that dates, purpose of visit, accommodation, and flight details form a coherent, legitimate itinerary. Pay special attention to destinations (e.g., specific Kuala Lumpur zones if provided).

OUTPUT REQUIREMENTS:
Return ONLY a valid, raw JSON object (with NO markdown, code blocks, or preamble) formatted as follows:
{
  "risk_score": <number from 0 to 100, where 0 = no risk/highest success probability, and 100 = extreme risk/threat>,
  "risk_level": "<Low | Medium | High>",
  "recommendation": "<Approve | Manual Review | Reject>",
  "prediction_reason": "<Clear, professional immigration summary explaining exact findings, detected red flags, financial logic, or safety reasons.>"
}
''';

      final response = await http.post(
        Uri.parse('$_aiEndpoint?key=$_aiApiKey'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _aiApiKey,
        },
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": systemPrompt
            }]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String candidateText = data['candidates'][0]['content']['parts'][0]['text'];

        final cleanedJsonText = candidateText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final Map<String, dynamic> parsedAiResult = jsonDecode(cleanedJsonText);

        return {
          'risk_score': (parsedAiResult['risk_score'] as num?)?.toDouble() ?? 50.0,
          'risk_level': parsedAiResult['risk_level'] ?? 'Medium',
          'recommendation': parsedAiResult['recommendation'] ?? 'Manual Review',
          'prediction_reason': parsedAiResult['prediction_reason'] ?? 'Evaluated based on submitted profile parameters.',
        };
      } else {
        throw Exception('AI Engine returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("AiService Evaluation Exception: $e");
      return {
        'risk_score': 50.0,
        'risk_level': 'Medium',
        'recommendation': 'Manual Review',
        'prediction_reason': 'Automated assessment fallback triggered due to data evaluation formatting.',
      };
    }
  }
}