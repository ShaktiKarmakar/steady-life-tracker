/// Meal type for grouping entries in the diary view.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealType fromString(String s) => switch (s) {
    'breakfast' => breakfast,
    'lunch' => lunch,
    'dinner' => dinner,
    _ => snack,
  };

  String get label => switch (this) {
    breakfast => 'Breakfast',
    lunch => 'Lunch',
    dinner => 'Dinner',
    snack => 'Snack',
  };
}

/// AI confidence in the estimate quality.
enum ConfidenceLevel {
  high,
  medium,
  low;

  static ConfidenceLevel fromString(String s) => switch (s) {
    'high' => high,
    'medium' => medium,
    _ => low,
  };

  String get label => switch (this) {
    high => 'Accurate estimate',
    medium => 'Approximate',
    low => 'Rough estimate',
  };

  String get dots => switch (this) {
    high => '●●●',
    medium => '●●○',
    low => '●○○',
  };
}

/// User-configurable daily nutrition goals.
class NutritionGoals {
  const NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  factory NutritionGoals.defaults() =>
      const NutritionGoals(calories: 2000, protein: 120, carbs: 200, fat: 65);

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
        calories: (json['calories'] as num?)?.toInt() ?? 2000,
        protein: (json['protein'] as num?)?.toInt() ?? 120,
        carbs: (json['carbs'] as num?)?.toInt() ?? 200,
        fat: (json['fat'] as num?)?.toInt() ?? 65,
      );

  NutritionGoals copyWith({
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  }) =>
      NutritionGoals(
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
      );
}

/// A single identified food item within a meal.
class FoodItem {
  const FoodItem({
    required this.name,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.confidence,
    required this.cookingMethod,
    required this.portionReference,
  });

  final String name;
  final int estimatedWeightG;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final ConfidenceLevel confidence;
  final String cookingMethod;
  final String portionReference;

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_weight_g': estimatedWeightG,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'confidence': confidence.name,
        'cooking_method': cookingMethod,
        'portion_reference': portionReference,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Unknown item',
        estimatedWeightG: (json['estimated_weight_g'] as num?)?.toInt() ?? 0,
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        confidence: ConfidenceLevel.fromString(json['confidence'] as String? ?? 'low'),
        cookingMethod: json['cooking_method'] as String? ?? 'unknown',
        portionReference: json['portion_reference'] as String? ?? '',
      );

  /// Scale this item by a weight multiplier. Linear approximation — acceptable
  /// for raw ingredients, documented limitation for fried/battered foods.
  FoodItem withWeight(int newWeightG) {
    if (estimatedWeightG <= 0 || newWeightG <= 0) return this;
    final scale = newWeightG / estimatedWeightG;
    return FoodItem(
      name: name,
      estimatedWeightG: newWeightG,
      calories: (calories * scale).round(),
      proteinG: proteinG * scale,
      carbsG: carbsG * scale,
      fatG: fatG * scale,
      confidence: ConfidenceLevel.high,
      cookingMethod: cookingMethod,
      portionReference: 'user-adjusted',
    );
  }

  FoodItem copyWith({
    String? name,
    int? estimatedWeightG,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    ConfidenceLevel? confidence,
    String? cookingMethod,
    String? portionReference,
  }) =>
      FoodItem(
        name: name ?? this.name,
        estimatedWeightG: estimatedWeightG ?? this.estimatedWeightG,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        confidence: confidence ?? this.confidence,
        cookingMethod: cookingMethod ?? this.cookingMethod,
        portionReference: portionReference ?? this.portionReference,
      );
}

/// A logged meal entry, replacing the legacy flat CalorieEntry.
class FoodEntry {
  FoodEntry({
    required this.id,
    required this.mealType,
    this.photoPath,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.overallConfidence,
    this.confidenceNote,
    required this.items,
    required this.timestamp,
    this.isManuallyEntered = false,
  });

  final String id;
  final MealType mealType;
  final String? photoPath;
  final int totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final ConfidenceLevel overallConfidence;
  final String? confidenceNote;
  final List<FoodItem> items;
  final DateTime timestamp;
  final bool isManuallyEntered;

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal_type': mealType.name,
        'photo_path': photoPath,
        'total_calories': totalCalories,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
        'overall_confidence': overallConfidence.name,
        'confidence_note': confidenceNote,
        'items': items.map((i) => i.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
        'is_manually_entered': isManuallyEntered,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'] as String,
        mealType: MealType.fromString(json['meal_type'] as String? ?? 'snack'),
        photoPath: json['photo_path'] as String?,
        totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
        totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0,
        totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0,
        totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0,
        overallConfidence: ConfidenceLevel.fromString(json['overall_confidence'] as String? ?? 'low'),
        confidenceNote: json['confidence_note'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => FoodItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isManuallyEntered: json['is_manually_entered'] == true,
      );

  /// Recalculate totals from items (call after editing items).
  FoodEntry recalculateTotals() {
    final cals = items.fold<int>(0, (s, i) => s + i.calories);
    final prot = items.fold<double>(0, (s, i) => s + i.proteinG);
    final carbs = items.fold<double>(0, (s, i) => s + i.carbsG);
    final fat = items.fold<double>(0, (s, i) => s + i.fatG);
    return FoodEntry(
      id: id,
      mealType: mealType,
      photoPath: photoPath,
      totalCalories: cals,
      totalProteinG: prot,
      totalCarbsG: carbs,
      totalFatG: fat,
      overallConfidence: overallConfidence,
      confidenceNote: confidenceNote,
      items: items,
      timestamp: timestamp,
      isManuallyEntered: isManuallyEntered,
    );
  }

  FoodEntry copyWith({
    String? id,
    MealType? mealType,
    String? photoPath,
    int? totalCalories,
    double? totalProteinG,
    double? totalCarbsG,
    double? totalFatG,
    ConfidenceLevel? overallConfidence,
    String? confidenceNote,
    List<FoodItem>? items,
    DateTime? timestamp,
    bool? isManuallyEntered,
  }) =>
      FoodEntry(
        id: id ?? this.id,
        mealType: mealType ?? this.mealType,
        photoPath: photoPath ?? this.photoPath,
        totalCalories: totalCalories ?? this.totalCalories,
        totalProteinG: totalProteinG ?? this.totalProteinG,
        totalCarbsG: totalCarbsG ?? this.totalCarbsG,
        totalFatG: totalFatG ?? this.totalFatG,
        overallConfidence: overallConfidence ?? this.overallConfidence,
        confidenceNote: confidenceNote ?? this.confidenceNote,
        items: items ?? this.items,
        timestamp: timestamp ?? this.timestamp,
        isManuallyEntered: isManuallyEntered ?? this.isManuallyEntered,
      );
}

/// Structured result from Gemma food vision analysis.
class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.mealName,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.overallConfidence,
    this.confidenceNote,
    required this.items,
  });

  final String mealName;
  final int totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final ConfidenceLevel overallConfidence;
  final String? confidenceNote;
  final List<FoodItem> items;

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) => FoodAnalysisResult(
        mealName: json['meal_name'] as String? ?? 'Meal',
        totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
        totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0,
        totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0,
        totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0,
        overallConfidence: ConfidenceLevel.fromString(json['overall_confidence'] as String? ?? 'low'),
        confidenceNote: json['confidence_note'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => FoodItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  /// Convert to a loggable FoodEntry. Caller must supply id, timestamp, mealType.
  FoodEntry toFoodEntry({
    required String id,
    required MealType mealType,
    String? photoPath,
    required DateTime timestamp,
    bool isManuallyEntered = false,
  }) =>
      FoodEntry(
        id: id,
        mealType: mealType,
        photoPath: photoPath,
        totalCalories: totalCalories,
        totalProteinG: totalProteinG,
        totalCarbsG: totalCarbsG,
        totalFatG: totalFatG,
        overallConfidence: overallConfidence,
        confidenceNote: confidenceNote,
        items: items,
        timestamp: timestamp,
        isManuallyEntered: isManuallyEntered,
      );
}
