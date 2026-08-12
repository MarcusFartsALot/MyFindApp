import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  // Your existing Google API key
  static const String _apiKey = "AQ.Ab8RN6KzVkLBxtFqlWOHdpBAGA_vYkNj7DIYAWxsgJqROByneA";
  static const String _endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent";

  // In-memory cache to store translated strings so we avoid redundant API calls
  static final Map<String, String> _translationCache = {};

  /// Translates [text] to [targetLanguage] dynamically via Google Gemini API
  static Future<String> translate(String text, String? targetLanguage) async {
    // Default to English or return original text if target language is English or empty
    if (targetLanguage == null || targetLanguage == 'English' || text.trim().isEmpty) {
      return text;
    }

    final String cacheKey = "${targetLanguage}_$text";
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": "Translate the following short UI phrase into $targetLanguage. "
                  "Return ONLY the direct translation string without any commentary, quotes, or formatting: \"$text\""
            }]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String translatedText = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();

        // Save to local cache
        _translationCache[cacheKey] = translatedText;
        return translatedText;
      } else {
        return text; // Fallback to original text if API errors
      }
    } catch (e) {
      debugPrint("Translation API Error: $e");
      return text; // Fallback to original text
    }
  }
}

/// Helper Widget that dynamically translates any String in real-time
class DynamicText extends StatelessWidget {
  final String text;
  final String? targetLanguage;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const DynamicText(
      this.text, {
        super.key,
        required this.targetLanguage,
        this.style,
        this.textAlign,
        this.overflow,
        this.maxLines,
      });

  @override
  Widget build(BuildContext context) {
    if (targetLanguage == null || targetLanguage == 'English') {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    return FutureBuilder<String>(
      future: TranslationService.translate(text, targetLanguage),
      builder: (context, snapshot) {
        final String displayText = snapshot.data ?? text;
        return Text(
          displayText,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}