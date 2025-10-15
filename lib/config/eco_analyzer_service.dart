import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:eco_lpu/config/eco_keys.dart';
import 'eco_waste_detection.dart';

class AnalyzerService {
  GenerativeModel? _model;
  final String _apiKey = ApiKeys.geminiKey;

  String zbudujSzczegolowePolecenieAnalizy() {
    return """
    You are an expert waste classification assistant with advanced contextual understanding. Your task is to analyze the image, identify all major items, and determine if they are waste based on their condition and context.

    *** RULES FOR HIGHER ACCURACY ***
    1.  **CONTEXT IS KEY:** Do not automatically classify items as waste. Analyze the item's context. A tool on a workbench is not waste. A banana peel in a compost bin is waste. A clean plate on a table is not waste. A broken plate in a trash can is waste. Provide common-sense classifications.
    2.  **GROUP AND COUNT:** If you identify multiple similar items (e.g., a stack of papers, several bottles, a pile of screws), you MUST group them into a single JSON object. In this object, you MUST also provide a reasonable estimate for the number of items in the `quantity` field. For single, individual items, the `quantity` MUST be 1.

    VERY IMPORTANT: Format your entire response as a single, clean JSON object. This object must contain a single key: 'detections', which is an array of JSON objects. For each distinct item or group of items you identify, create a separate object in the array with the following keys:

    1. 'name': (String) A short, descriptive name for the item or group (e.g., 'Stack of Office Paper', 'Plastic Water Bottles', 'Assorted Metal Screws').
    2. 'quantity': (Number) An estimated count of the items in the group. This MUST be 1 for single items. Be reasonable (e.g., a stack of paper might be 20, a handful of screws might be 15).
    3. 'is_waste': (boolean) Your determination of whether the item is waste, based on context. This must be `true` or `false`.
    4. 'category': (String) If 'is_waste' is true, this MUST be one of: PLASTIC, GLASS, ORGANIC, PAPER, ELECTRONIC, or METAL. If 'is_waste' is false, this MUST be 'NOT WASTE'.
    5. 'confidence': (Number) A value between 0.0 and 1.0 representing your confidence in the 'is_waste' determination and 'category' classification.
    6. 'reasoning': (String) A brief explanation for your classification, mentioning context and quantity if relevant.
    7. 'disposal_tip': (String) If the item is waste, provide a helpful disposal tip. If 'is_waste' is false, this must be an empty string.
    8. 'recycling_tip': (String) If the item is waste, provide a useful recycling tip. If 'is_waste' is false, this must be an empty string.

    If the image is empty or contains nothing identifiable, the 'detections' array should be empty. Do not output anything other than the JSON object.
    """;
  }

  String zbudujPolecenieReklasyfikacji(WasteDetection item) {
    return """
    You are an expert waste classification assistant. An item was previously identified as 'NOT WASTE' with the name '${item.name}' and the following reasoning: '${item.reasoning}'.

    Your task is to re-evaluate this item. Assume the user has determined it IS waste after all.

    Provide a classification for this item AS IF IT WERE WASTE. Determine its most likely waste category and provide helpful tips.

    VERY IMPORTANT: Format your entire response as a single, clean JSON object containing a single key: 'detections', which is an array with exactly ONE JSON object inside. This object must have the following keys:

    1. 'name': (String) Use the original name of the item: '${item.name}'.
    2. 'is_waste': (boolean) This MUST be `true`.
    3. 'category': (String) This MUST be one of: PLASTIC, GLASS, ORGANIC, PAPER, ELECTRONIC, or METAL. Choose the most likely category for an item described by the reasoning provided.
    4. 'confidence': (Number) A value between 0.0 and 1.0 representing your confidence in the new 'category' classification.
    5. 'reasoning': (String) A brief explanation for your NEW classification, acknowledging the re-classification.
    6. 'disposal_tip': (String) Provide a helpful disposal tip. This must NOT be an empty string.
    7. 'recycling_tip': (String) Provide a useful recycling tip. This must NOT be an empty string.

    Do not output anything other than the single JSON object.
    """;
  }
  
  bool get isModelReady => _model != null;

  Future<void> initializeModel() async {
    if (isModelReady) return;
    try {
      final modelName = await pobierzNajlepszaNazweModelu();
      _model = GenerativeModel(model: modelName, apiKey: _apiKey);
    } catch (e) {
      _model = null;
      debugPrint("Model initialization error: $e");
      throw Exception(przetworzWiadomoscBledu(e));
    }
  }

  Future<List<dynamic>> generujIPrzetworzZawartosc(List<Content> content) async {
    if (!isModelReady) {
      throw Exception("Model not initialized. Call initializeModel() first.");
    }
    try {
      final response = await _model!.generateContent(content);
      final rawText = response.text;

      if (rawText == null || rawText.trim().isEmpty) {
        throw Exception("Received an empty response from the model.");
      }

      final cleanedText = rawText.replaceAll(RegExp(r"```(json)?"), "").trim();
      final result = jsonDecode(cleanedText);

      return result['detections'] as List<dynamic>? ?? [];
    } on FormatException catch (e) {
      debugPrint("JSON parsing error: $e");
      throw Exception("Failed to parse the response from the model.");
    } catch (e) {
      debugPrint("Generative AI error: $e");
      throw Exception(przetworzWiadomoscBledu(e));
    }
  }

  Future<List<WasteDetection>> analyzeImageDetailed(
      Uint8List imageBytes) async {
    final content = [
      Content.multi([
        TextPart(zbudujSzczegolowePolecenieAnalizy()),
        DataPart('image/jpeg', imageBytes)
      ])
    ];
    final detectionsList = await generujIPrzetworzZawartosc(content);
    return detectionsList
        .map((item) => WasteDetection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WasteDetection> reclassifyItem(WasteDetection item) async {
    final prompt = zbudujPolecenieReklasyfikacji(item);
    final content = [Content.text(prompt)];
    final detectionsList = await generujIPrzetworzZawartosc(content);

    if (detectionsList.isEmpty) {
      throw Exception("Re-classification failed to produce a result.");
    }
    return WasteDetection.fromJson(
        detectionsList.first as Map<String, dynamic>);
  }

  String przetworzWiadomoscBledu(Object e) {
    final errorString = e.toString();
    
    RegExpMatch? match = RegExp(r'(\d{3})').firstMatch(errorString);
    if (match != null) {
      return "HTTP Error: ${match.group(1)}";
    }
    
    match = RegExp(r'[A-Z_]{10,}').firstMatch(errorString);
    if (match != null) {
      final formattedError = match.group(0)!
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .map((word) => word.isNotEmpty ? word.toUpperCase() + word.substring(1) : '')
          .join(' ');
      return formattedError;
    }
    
    if (e is FormatException) {
      return "An unexpected error occurred while processing the data.";
    }

    return "An unexpected processing error occurred.";
  }

  Future<String> pobierzNajlepszaNazweModelu() async {
    final url = Uri.https(
      "generativelanguage.googleapis.com",
      "/v1beta/models",
      {"key": _apiKey},
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception("Failed to list models: ${response.body}");
      }

      final models = jsonDecode(response.body)["models"] as List<dynamic>?;
      if (models == null || models.isEmpty) {
        throw Exception("No models returned from the API.");
      }

      final validModels = models
          .whereType<Map<String, dynamic>>()
          .where((model) =>
              (model["supportedGenerationMethods"] as List<dynamic>? ?? [])
                  .contains("generateContent"))
          .map((model) => model["name"] as String)
          .toList();

      if (validModels.isEmpty) {
        throw Exception("No models found that support generateContent.");
      }
      
      const preferredModels = ["gemini-pro-vision", "gemini-1.5-flash-latest"];
      for (final preferred in preferredModels) {
        final foundModel = validModels.firstWhere(
          (name) => name.contains(preferred),
          orElse: () => '',
        );
        if (foundModel.isNotEmpty) return foundModel;
      }
      
      return validModels.first;
    } on http.ClientException catch (e) {
      debugPrint("Network error while fetching models: $e");
      throw Exception("A network error occurred while connecting to the service.");
    } catch (e) {
      debugPrint("Error fetching models: $e");
      rethrow;
    }
  }
}