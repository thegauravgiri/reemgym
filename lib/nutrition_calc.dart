import 'dart:math';

import 'models.dart';

/// Basal metabolic rate (Mifflin–St Jeor), kcal/day.
double bmr({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) => 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

/// Builds a profile with calorie, macro, water and step targets derived from
/// the body details the user gave during onboarding.
Profile buildPlan({
  required String name,
  required Sex sex,
  required int birthYear,
  required double heightCm,
  required double weightKg,
  required double targetWeightKg,
  required ActivityLevel activity,
  required Goal goal,
  required double weeklyRateKg,
  bool stepTracking = false,
}) {
  final age = DateTime.now().year - birthYear;
  final tdee =
      bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) *
      activity.multiplier;
  // 1 kg of body weight is roughly 7700 kcal.
  final dailyDelta = weeklyRateKg * 7700 / 7;
  final floor = sex == Sex.male ? 1500.0 : 1200.0;
  final calories = switch (goal) {
    Goal.lose => max(floor, tdee - dailyDelta),
    Goal.maintain => tdee,
    Goal.gain => tdee + dailyDelta,
  };
  final proteinPerKg = switch (goal) {
    Goal.lose => 2.0,
    Goal.maintain => 1.6,
    Goal.gain => 1.8,
  };
  final protein = weightKg * proteinPerKg;
  final fat = calories * 0.27 / 9;
  final carbs = max(0.0, (calories - protein * 4 - fat * 9) / 4);
  return Profile(
    name: name,
    sex: sex,
    birthYear: birthYear,
    heightCm: heightCm,
    weightKg: weightKg,
    targetWeightKg: targetWeightKg,
    activity: activity,
    goal: goal,
    weeklyRateKg: weeklyRateKg,
    calorieTarget: (calories / 10).round() * 10,
    proteinTarget: protein.round(),
    carbsTarget: carbs.round(),
    fatTarget: fat.round(),
    waterGoalMl: ((weightKg * 35) / 250).round() * 250,
    stepGoal: goal == Goal.lose ? 10000 : 8000,
    stepTracking: stepTracking,
  );
}

/// Calories burned by an activity: MET × body weight (kg) × hours.
double exerciseCalories({
  required double met,
  required double weightKg,
  required int minutes,
}) => met * weightKg * minutes / 60;

/// Net calories burned by walking, above what the body burns at rest.
/// About 0.5 kcal per kg per 1000 steps, e.g. 70 kg × 10,000 steps ≈ 350 kcal.
double stepCalories(int steps, double weightKg) => steps * weightKg * 0.0005;

double bmi(double weightKg, double heightCm) =>
    weightKg / pow(heightCm / 100, 2);

class Activity {
  final String name;
  final double met;
  final String emoji;
  const Activity(this.name, this.met, this.emoji);
}

/// MET values from the Compendium of Physical Activities.
const activities = <Activity>[
  Activity('Walking (brisk)', 4.3, '🚶'),
  Activity('Running (8 km/h)', 8.3, '🏃'),
  Activity('Running (10 km/h)', 9.8, '🏃'),
  Activity('Running (12 km/h)', 11.5, '🏃'),
  Activity('Cycling (leisure)', 6.8, '🚴'),
  Activity('Cycling (vigorous)', 10.0, '🚴'),
  Activity('Weight training', 5.0, '🏋️'),
  Activity('Bodyweight workout', 3.8, '🤸'),
  Activity('Push-ups, sit-ups (vigorous)', 8.0, '💪'),
  Activity('HIIT / circuit training', 8.0, '🔥'),
  Activity('Yoga', 2.5, '🧘'),
  Activity('Pilates', 3.0, '🧘'),
  Activity('Stretching', 2.3, '🙆'),
  Activity('Jump rope', 11.0, '🪢'),
  Activity('Swimming (moderate)', 6.0, '🏊'),
  Activity('Swimming (laps, fast)', 9.8, '🏊'),
  Activity('Hiking', 6.0, '🥾'),
  Activity('Stair climbing', 8.8, '🪜'),
  Activity('Dancing', 5.0, '💃'),
  Activity('Zumba / aerobics', 6.5, '💃'),
  Activity('Football (soccer)', 7.0, '⚽'),
  Activity('Futsal', 8.0, '⚽'),
  Activity('Basketball', 6.5, '🏀'),
  Activity('Badminton', 5.5, '🏸'),
  Activity('Cricket', 4.8, '🏏'),
  Activity('Tennis', 7.3, '🎾'),
  Activity('Table tennis', 4.0, '🏓'),
  Activity('Volleyball', 4.0, '🏐'),
  Activity('Boxing / kickboxing', 7.8, '🥊'),
  Activity('Rowing machine', 7.0, '🚣'),
  Activity('Elliptical trainer', 5.0, '🏃'),
  Activity('Housework / cleaning', 3.3, '🧹'),
];
