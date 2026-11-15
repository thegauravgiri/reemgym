import 'dart:math';

enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { lose, maintain, gain }

enum MealType { breakfast, lunch, dinner, snack }

extension ActivityLevelX on ActivityLevel {
  String get label => const [
    'Mostly sitting',
    'Lightly active',
    'Moderately active',
    'Very active',
    'Athlete',
  ][index];
  String get hint => const [
    'Desk job, little exercise',
    'Light exercise 1–3 days a week',
    'Exercise 3–5 days a week',
    'Hard exercise 6–7 days a week',
    'Physical job or twice-a-day training',
  ][index];
  double get multiplier => const [1.2, 1.375, 1.55, 1.725, 1.9][index];
}

extension GoalX on Goal {
  String get label => const ['Lose weight', 'Maintain', 'Gain weight'][index];
}

extension MealTypeX on MealType {
  String get label => const ['Breakfast', 'Lunch', 'Dinner', 'Snacks'][index];
}

/// Meal a new entry most likely belongs to, based on the time of day.
MealType mealForTime(DateTime t) {
  if (t.hour < 11) return MealType.breakfast;
  if (t.hour < 16) return MealType.lunch;
  if (t.hour < 22) return MealType.dinner;
  return MealType.snack;
}

String dayKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayFromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

final _rand = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(900) + 100}';

double _d(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) =>
    v is num ? v.round() : int.tryParse('$v') ?? fallback;
T _enum<T extends Enum>(List<T> values, dynamic name, T fallback) =>
    values.where((e) => e.name == name).firstOrNull ?? fallback;

class Profile {
  final String name;
  final Sex sex;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final ActivityLevel activity;
  final Goal goal;

  /// Kilograms per week the user wants to lose or gain (ignored for maintain).
  final double weeklyRateKg;
  final int calorieTarget;
  final int proteinTarget;
  final int carbsTarget;
  final int fatTarget;
  final int waterGoalMl;
  final int stepGoal;
  final bool stepTracking;

  /// The user agreed to their meal photos and analyses being kept for
  /// research. Off unless they turn it on.
  final bool shareForResearch;

  const Profile({
    required this.name,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.activity,
    required this.goal,
    required this.weeklyRateKg,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    required this.waterGoalMl,
    required this.stepGoal,
    this.stepTracking = false,
    this.shareForResearch = false,
  });

  int get age => DateTime.now().year - birthYear;

  Profile copyWith({
    String? name,
    Sex? sex,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    ActivityLevel? activity,
    Goal? goal,
    double? weeklyRateKg,
    int? calorieTarget,
    int? proteinTarget,
    int? carbsTarget,
    int? fatTarget,
    int? waterGoalMl,
    int? stepGoal,
    bool? stepTracking,
    bool? shareForResearch,
  }) => Profile(
    name: name ?? this.name,
    sex: sex ?? this.sex,
    birthYear: birthYear ?? this.birthYear,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
    calorieTarget: calorieTarget ?? this.calorieTarget,
    proteinTarget: proteinTarget ?? this.proteinTarget,
    carbsTarget: carbsTarget ?? this.carbsTarget,
    fatTarget: fatTarget ?? this.fatTarget,
    waterGoalMl: waterGoalMl ?? this.waterGoalMl,
    stepGoal: stepGoal ?? this.stepGoal,
    stepTracking: stepTracking ?? this.stepTracking,
    shareForResearch: shareForResearch ?? this.shareForResearch,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'sex': sex.name,
    'birthYear': birthYear,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'activity': activity.name,
    'goal': goal.name,
    'weeklyRateKg': weeklyRateKg,
    'calorieTarget': calorieTarget,
    'proteinTarget': proteinTarget,
    'carbsTarget': carbsTarget,
    'fatTarget': fatTarget,
    'waterGoalMl': waterGoalMl,
    'stepGoal': stepGoal,
    'stepTracking': stepTracking,
    'shareForResearch': shareForResearch,
  };

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    name: '${m['name'] ?? ''}',
    sex: _enum(Sex.values, m['sex'], Sex.male),
    birthYear: _i(m['birthYear'], 1995),
    heightCm: _d(m['heightCm'], 170),
    weightKg: _d(m['weightKg'], 70),
    targetWeightKg: _d(m['targetWeightKg'], 70),
    activity: _enum(ActivityLevel.values, m['activity'], ActivityLevel.light),
    goal: _enum(Goal.values, m['goal'], Goal.maintain),
    weeklyRateKg: _d(m['weeklyRateKg'], 0.5),
    calorieTarget: _i(m['calorieTarget'], 2000),
    proteinTarget: _i(m['proteinTarget'], 120),
    carbsTarget: _i(m['carbsTarget'], 220),
    fatTarget: _i(m['fatTarget'], 60),
    waterGoalMl: _i(m['waterGoalMl'], 2500),
    stepGoal: _i(m['stepGoal'], 8000),
    stepTracking: m['stepTracking'] == true,
    shareForResearch: m['shareForResearch'] == true,
  );
}

/// One food inside a meal. Nutrient values describe a single [portion];
/// [quantity] multiplies them (1.5 = one and a half portions).
class FoodItem {
  final String name;
  final String portion;
  final double quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodiumMg;

  const FoodItem({
    required this.name,
    this.portion = '1 serving',
    this.quantity = 1,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodiumMg = 0,
  });

  double get totalCalories => calories * quantity;
  double get totalProtein => protein * quantity;
  double get totalCarbs => carbs * quantity;
  double get totalFat => fat * quantity;
  double get totalFiber => fiber * quantity;
  double get totalSugar => sugar * quantity;
  double get totalSodiumMg => sodiumMg * quantity;

  FoodItem copyWith({
    String? name,
    String? portion,
    double? quantity,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? sodiumMg,
  }) => FoodItem(
    name: name ?? this.name,
    portion: portion ?? this.portion,
    quantity: quantity ?? this.quantity,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    fiber: fiber ?? this.fiber,
    sugar: sugar ?? this.sugar,
    sodiumMg: sodiumMg ?? this.sodiumMg,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'portion': portion,
    'quantity': quantity,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'sodiumMg': sodiumMg,
  };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
    name: '${m['name'] ?? 'Food'}',
    portion: '${m['portion'] ?? '1 serving'}',
    quantity: _d(m['quantity'], 1),
    calories: _d(m['calories']),
    protein: _d(m['protein']),
    carbs: _d(m['carbs']),
    fat: _d(m['fat']),
    fiber: _d(m['fiber']),
    sugar: _d(m['sugar']),
    sodiumMg: _d(m['sodiumMg']),
  );
}

class FoodEntry {
  final String id;
  final String dayKey;
  final MealType meal;
  final String title;
  final List<FoodItem> items;

  /// 'photo', 'text' or 'manual'.
  final String source;
  final DateTime createdAt;

  const FoodEntry({
    required this.id,
    required this.dayKey,
    required this.meal,
    required this.title,
    required this.items,
    required this.source,
    required this.createdAt,
  });

  double _sum(double Function(FoodItem) f) =>
      items.fold(0, (total, i) => total + f(i));
  double get calories => _sum((i) => i.totalCalories);
  double get protein => _sum((i) => i.totalProtein);
  double get carbs => _sum((i) => i.totalCarbs);
  double get fat => _sum((i) => i.totalFat);
  double get fiber => _sum((i) => i.totalFiber);
  double get sugar => _sum((i) => i.totalSugar);
  double get sodiumMg => _sum((i) => i.totalSodiumMg);

  FoodEntry copyWith({
    String? id,
    String? dayKey,
    MealType? meal,
    String? title,
    List<FoodItem>? items,
    String? source,
    DateTime? createdAt,
  }) => FoodEntry(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    meal: meal ?? this.meal,
    title: title ?? this.title,
    items: items ?? this.items,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'dayKey': dayKey,
    'meal': meal.name,
    'title': title,
    'items': items.map((i) => i.toMap()).toList(),
    'source': source,
    'createdAt': createdAt.millisecondsSinceEpoch,
    // Denormalised totals, handy when inspecting data in the console.
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory FoodEntry.fromMap(String id, Map<String, dynamic> m) => FoodEntry(
    id: id,
    dayKey: '${m['dayKey']}',
    meal: _enum(MealType.values, m['meal'], MealType.snack),
    title: '${m['title'] ?? 'Meal'}',
    items: ((m['items'] as List?) ?? const [])
        .map((e) => FoodItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    source: '${m['source'] ?? 'manual'}',
    createdAt: DateTime.fromMillisecondsSinceEpoch(_i(m['createdAt'])),
  );
}

class ExerciseEntry {
  final String id;
  final String dayKey;
  final String name;
  final int minutes;
  final double calories;
  final DateTime createdAt;

  const ExerciseEntry({
    required this.id,
    required this.dayKey,
    required this.name,
    required this.minutes,
    required this.calories,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'dayKey': dayKey,
    'name': name,
    'minutes': minutes,
    'calories': calories,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ExerciseEntry.fromMap(String id, Map<String, dynamic> m) =>
      ExerciseEntry(
        id: id,
        dayKey: '${m['dayKey']}',
        name: '${m['name'] ?? 'Exercise'}',
        minutes: _i(m['minutes']),
        calories: _d(m['calories']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(_i(m['createdAt'])),
      );
}

/// Per-day counters that are not individual log entries.
class DayStats {
  final String dayKey;
  final int steps;
  final int waterMl;
  final double? weightKg;

  const DayStats({
    required this.dayKey,
    this.steps = 0,
    this.waterMl = 0,
    this.weightKg,
  });

  factory DayStats.fromMap(String dayKey, Map<String, dynamic>? m) => DayStats(
    dayKey: dayKey,
    steps: _i(m?['steps']),
    waterMl: _i(m?['waterMl']),
    weightKg: m?['weightKg'] == null ? null : _d(m!['weightKg']),
  );
}

/// Everything known about one day, used by the Progress screen.
class DaySummary {
  final String dayKey;
  double eaten = 0;
  double protein = 0;
  double exercise = 0;
  int steps = 0;
  int waterMl = 0;
  double? weightKg;
  int foodCount = 0;

  DaySummary(this.dayKey);
}
