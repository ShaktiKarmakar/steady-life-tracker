import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../shared/models/food_models.dart';
import 'gemma_service.dart';

/// Service for analyzing food photos and descriptions using on-device Gemma.
class FoodVisionService {
  FoodVisionService({required GemmaService gemma}) : _gemma = gemma;

  final GemmaService _gemma;

  static const String _systemPrompt =
      'You are a food recognition AI. Analyze the photo carefully and identify each visible food item. '
      'Reply with ONLY a JSON object. Format:'
      '\n{"items":[{"name":"exact food name","grams":200,"calories":300,"protein":20,"carbs":40,"fat":10}],'
      '\n"total_calories":300}'
      '\nBe specific with food names (e.g. "grilled chicken breast" not "food"). '
      'If you truly cannot see the image, return {"items":[],"total_calories":0}. '
      'Never guess generic values. Return ONLY JSON, no other text.';

  static const String _photoPrompt =
      'Analyze this food photo carefully. List each visible food item with estimated calories, protein, carbs, and fat. Return ONLY JSON.';

  static const String _textPrompt =
      'The user ate this. Estimate calories and macros. Return ONLY JSON.';

  Future<(FoodAnalysisResult? result, String rawResponse)> analyzePhoto({
    required Uint8List imageBytes,
  }) async {
    // Try up to 2 times if response looks generic
    for (var attempt = 0; attempt < 2; attempt++) {
      final prompt = attempt == 0
          ? _photoPrompt
          : 'Look carefully at this food photo. Identify the exact food items visible. Be specific with names and realistic with portions. Return ONLY JSON.';
      
      final response = await _gemma.askWithImage(
        imageBytes: imageBytes,
        prompt: prompt,
        systemContext: _systemPrompt,
      );

      debugPrint('[FoodVision] Attempt ${attempt + 1} raw response:\n$response');

      final result = _tryParse(response);
      if (result != null && !_looksGeneric(result.items)) {
        return (result, response);
      }
      if (result != null && attempt == 0) {
        debugPrint('[FoodVision] Generic response detected, retrying...');
      }
    }
    
    // Final attempt
    final response = await _gemma.askWithImage(
      imageBytes: imageBytes,
      prompt: _photoPrompt,
      systemContext: _systemPrompt,
    );
    final result = _tryParse(response);
    return (result, response);
  }

  Future<(FoodAnalysisResult? result, String rawResponse)> analyzeDescription(
    String description,
  ) async {
    final prompt = 'The user ate: $description. $_textPrompt';
    final response = await _gemma.ask(prompt, systemContext: _systemPrompt);

    debugPrint('[FoodVision] Raw model response:\n$response');

    final result = _tryParse(response);
    return (result, response);
  }

  FoodAnalysisResult? _tryParse(String raw) {
    var text = raw.trim();

    if (text.startsWith('```')) {
      final firstNl = text.indexOf('\n');
      if (firstNl != -1) text = text.substring(firstNl + 1);
      if (text.endsWith('```')) text = text.substring(0, text.length - 3);
      text = text.trim();
    }

    final fromText = _parseBlock(text);
    if (fromText != null) return fromText;

    final candidates = <String>[];
    var start = -1;
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (text[i] == '}') {
        depth--;
        if (depth == 0 && start != -1) {
          candidates.add(text.substring(start, i + 1));
          start = -1;
        }
      }
    }

    candidates.sort((a, b) => b.length.compareTo(a.length));
    for (final c in candidates) {
      final r = _parseBlock(c);
      if (r != null) return r;
    }

    return null;
  }

  FoodAnalysisResult? _parseBlock(String block) {
    try {
      final decoded = jsonDecode(block) as Map<String, dynamic>;
      return _fromLooseJson(decoded);
    } catch (_) {
      return null;
    }
  }

  FoodAnalysisResult? _fromLooseJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] ?? json['food_items'] ?? json['foods'];
    final items = <FoodItem>[];

    // 1) Array of food items
    if (itemsRaw is List && itemsRaw.isNotEmpty) {
      for (final raw in itemsRaw) {
        if (raw is! Map) continue;
        try {
          final name = (raw['name'] ?? raw['food'] ?? raw['item'] ?? 'Unknown').toString();
          final grams = _toInt(raw['grams'] ?? raw['weight'] ?? 0);
          final cal = _toInt(raw['calories'] ?? raw['cal'] ?? raw['kcal'] ?? 0);
          final prot = _toDouble(raw['protein'] ?? raw['protein_g'] ?? 0);
          final carbs = _toDouble(raw['carbs'] ?? raw['carbs_g'] ?? raw['carbohydrates'] ?? 0);
          final fat = _toDouble(raw['fat'] ?? raw['fat_g'] ?? 0);
          final conf = _toString(raw['confidence'] ?? 'medium');

          items.add(FoodItem(
            name: name,
            estimatedWeightG: grams,
            calories: cal,
            proteinG: prot,
            carbsG: carbs,
            fatG: fat,
            confidence: _parseConfidence(conf),
            cookingMethod: _toString(raw['cooking_method'] ?? 'unknown'),
            portionReference: _toString(raw['portion_reference'] ?? 'estimated'),
          ));
        } catch (_) {}
      }
    }

    // 2) Flat object — the model returned totals directly in the root
    if (items.isEmpty && (json['calories'] != null || json['total_calories'] != null)) {
      final cal = _toInt(json['calories'] ?? json['total_calories'] ?? 0);
      final prot = _toDouble(json['protein_g'] ?? json['protein'] ?? json['total_protein_g'] ?? 0);
      final carbs = _toDouble(json['carbs_g'] ?? json['carbs'] ?? json['total_carbs_g'] ?? 0);
      final fat = _toDouble(json['fat_g'] ?? json['fat'] ?? json['total_fat_g'] ?? 0);

      items.add(FoodItem(
        name: _toString(json['name'] ?? json['food'] ?? 'Meal'),
        estimatedWeightG: _toInt(json['grams'] ?? json['weight'] ?? 0),
        calories: cal,
        proteinG: prot,
        carbsG: carbs,
        fatG: fat,
        confidence: _parseConfidence('low'), // Flat responses often mean the model didn't analyze properly
        cookingMethod: 'unknown',
        portionReference: 'estimated',
      ));
    }

    if (items.isEmpty) return null;

    // Detect suspiciously generic/hallucinated responses
    var confidence = _parseConfidence(_toString(json['overall_confidence'] ?? 'medium'));
    if (_looksGeneric(items)) {
      confidence = ConfidenceLevel.low;
    }

    return FoodAnalysisResult(
      mealName: _toString(json['meal_name'] ?? 'Meal'),
      totalCalories: _toInt(json['total_calories'] ??
          items.fold(0, (s, i) => s + i.calories)),
      totalProteinG: _toDouble(json['total_protein_g'] ?? json['total_protein'] ??
          items.fold(0.0, (s, i) => s + i.proteinG)),
      totalCarbsG: _toDouble(json['total_carbs_g'] ?? json['total_carbs'] ??
          items.fold(0.0, (s, i) => s + i.carbsG)),
      totalFatG: _toDouble(json['total_fat_g'] ?? json['total_fat'] ??
          items.fold(0.0, (s, i) => s + i.fatG)),
      overallConfidence: confidence,
      confidenceNote: json['confidence_note'] as String?,
      items: items,
    );
  }

  /// Heuristic: flag responses with suspiciously round numbers as likely hallucinations.
  static bool _looksGeneric(List<FoodItem> items) {
    if (items.length == 1) {
      final item = items.first;
      // Common hallucination pattern: exactly 420 cal, 20g protein, 40g carbs, 18g fat
      if (item.calories == 420 && item.proteinG == 20.0 && 
          item.carbsG == 40.0 && item.fatG == 18.0) return true;
      // Another pattern: all multiples of 10
      if (item.calories > 0 && item.calories % 100 == 0 &&
          item.proteinG > 0 && item.proteinG % 10 == 0 &&
          item.carbsG > 0 && item.carbsG % 10 == 0 &&
          item.fatG > 0 && item.fatG % 10 == 0) return true;
    }
    return false;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _toString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static ConfidenceLevel _parseConfidence(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.contains('high')) return ConfidenceLevel.high;
    if (lower.contains('medium') || lower.contains('med')) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}
