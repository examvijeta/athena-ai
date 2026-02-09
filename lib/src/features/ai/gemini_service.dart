import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final GenerativeModel _model;
  final String _apiKey;

  static const String APP_VERSION = "v1.3.0-StrictGemini3";

  GeminiService(String apiKey)
    : _apiKey = apiKey,
      _model = GenerativeModel(
        model: 'gemini-3-flash-preview', // Strictly for Gemini 3 Hackathon
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 256,
        ),
      );

  Future<String?> analyzeImage({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    if (imageBytes.isEmpty) return "Camera error: No image data.";

    // Strictly Gemini 3 models as requested
    final modelsToTry = ['gemini-3-flash-preview', 'gemini-3-pro-preview'];

    String lastError = "";

    for (var modelName in modelsToTry) {
      try {
        debugPrint('[$APP_VERSION] Trying strict Gemini 3 model: $modelName');
        final currentModel = GenerativeModel(model: modelName, apiKey: _apiKey);

        final response = await currentModel.generateContent([
          Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
        ]);

        if (response.text != null) return response.text;
      } catch (e) {
        lastError = "[$modelName] ${e.toString().split('\n').first}";
        debugPrint('Error with $modelName: $e');

        if (e.toString().contains('API_KEY_INVALID')) {
          return "Error: Invalid API Key.";
        }
      }
    }

    return "All Gemini 3 models failed. (App $APP_VERSION). Last error: $lastError\n\nNote: Ensure your API Key has Gemini 3 access in AI Studio.";
  }

  Stream<String> chatStream(List<Content> history) {
    return _model.generateContentStream(history).map((r) => r.text ?? '');
  }
}
