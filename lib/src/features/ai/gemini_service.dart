import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final GenerativeModel _model;
  final String _apiKey;

  GeminiService(String apiKey)
    : _apiKey = apiKey,
      _model = GenerativeModel(
        model: 'gemini-3.0-pro', // Using the hackathon model
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 256, // Keep responses short for real-time feel
        ),
      );

  Future<String?> analyzeImage({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    try {
      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Gemini 3.0 Error: $e. Trying fallback...');
      try {
        final fallbackModel = GenerativeModel(
          model: 'gemini-1.5-pro',
          apiKey: _apiKey,
        );
        final content = [
          Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
        ];
        final response = await fallbackModel.generateContent(content);
        return response.text;
      } catch (e2) {
        debugPrint('Fallback Error: $e2');
        return "I'm having trouble seeing that. Can you try again?";
      }
    }
  }

  Stream<String> chatStream(List<Content> history) {
    return _model.generateContentStream(history).map((r) => r.text ?? '');
  }
}
