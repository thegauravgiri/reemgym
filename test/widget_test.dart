import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemgym/app.dart';
import 'package:reemgym/models.dart';
import 'package:reemgym/nutrition_calc.dart';
import 'package:reemgym/services/data_repo.dart';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reemgym/services/food_analyzer.dart';
import 'package:reemgym/services/key_store.dart';

/// Loads the app's real fonts so layouts in tests match the device.
Future<void> loadAppFonts() async {
  for (final (family, weights) in [
    ('Outfit', [400, 500, 600, 700, 800]),
    ('Manrope', [400, 500, 600, 700]),
  ]) {
    final loader = FontLoader(family);
    for (final w in weights) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/$family-$w.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('plan maths', () {
    test('BMR follows Mifflin–St Jeor', () {
      expect(
        bmr(sex: Sex.male, weightKg: 70, heightCm: 175, age: 30),
        closeTo(1648.75, 0.01),
      );
      expect(
        bmr(sex: Sex.female, weightKg: 60, heightCm: 165, age: 30),
        closeTo(1320.25, 0.01),
      );
    });

    test('losing weight sets a deficit and macros add up to the target', () {
      Profile plan(Goal goal) => buildPlan(
        name: 'A',
        sex: Sex.male,
        birthYear: DateTime.now().year - 30,
        heightCm: 175,
        weightKg: 70,
        targetWeightKg: 65,
        activity: ActivityLevel.light,
        goal: goal,
        weeklyRateKg: 0.5,
      );
      final lose = plan(Goal.lose);
      final keep = plan(Goal.maintain);
      expect(keep.calorieTarget, closeTo(2267, 6));
      expect(keep.calorieTarget - lose.calorieTarget, closeTo(550, 11));
      final macroKcal =
          lose.proteinTarget * 4 + lose.carbsTarget * 4 + lose.fatTarget * 9;
      expect(macroKcal, closeTo(lose.calorieTarget, 25));
    });

    test('a very low result is raised to the safe minimum', () {
      final plan = buildPlan(
        name: 'A',
        sex: Sex.female,
        birthYear: DateTime.now().year - 60,
        heightCm: 150,
        weightKg: 45,
        targetWeightKg: 40,
        activity: ActivityLevel.sedentary,
        goal: Goal.lose,
        weeklyRateKg: 0.75,
      );
      expect(plan.calorieTarget, 1200);
    });

    test('exercise and step calories', () {
      expect(exerciseCalories(met: 8, weightKg: 70, minutes: 30), 280);
      expect(stepCalories(10000, 70), 350);
    });
  });

  group('food model', () {
    test('quantity scales an item and the entry totals', () {
      const rice = FoodItem(
        name: 'Rice',
        calories: 200,
        protein: 4,
        carbs: 44,
        quantity: 1.5,
      );
      const egg = FoodItem(name: 'Egg', calories: 78, protein: 6, fat: 5);
      final entry = FoodEntry(
        id: '1',
        dayKey: '2026-11-15',
        meal: MealType.lunch,
        title: 'Lunch',
        items: const [rice, egg],
        source: 'manual',
        createdAt: DateTime(2026, 11, 15, 13),
      );
      expect(entry.calories, 378);
      expect(entry.protein, 12);
      final copy = FoodEntry.fromMap('1', entry.toMap());
      expect(copy.calories, entry.calories);
      expect(copy.meal, MealType.lunch);
      expect(copy.items.first.quantity, 1.5);
    });

    test('analysis JSON is parsed, tolerating missing fields', () {
      final result = parseAnalysis(
        '{"title":"Momo","notes":"Steamed",'
        '"items":[{"name":"Chicken momo","portion":"8 pieces",'
        '"calories":320,"protein":18,"carbs":36,"fat":11}]}',
      );
      expect(result.title, 'Momo');
      expect(result.items.single.calories, 320);
      expect(result.items.single.fiber, 0);
    });
  });

  group('own Gemini key', () {
    const reply =
        '{"title":"Momo","notes":"","items":[{"name":"Momo",'
        '"portion":"8 pieces","calories":320,"protein":18,"carbs":36,"fat":11}]}';

    test('sends the photo with the key and reads the reply', () async {
      late http.Request seen;
      final analyzer = OwnKeyFoodAnalyzer(
        'my-key',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': reply},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final result = await analyzer.analyzeImage(
        Uint8List.fromList([1, 2, 3]),
        'image/jpeg',
      );
      expect(result.items.single.calories, 320);
      expect(result.ownKey, isTrue);
      expect(seen.headers['x-goog-api-key'], 'my-key');
      expect(seen.url.path, contains(geminiModel));
      final body = jsonDecode(seen.body) as Map;
      expect(
        body['contents'][0]['parts'][0]['inline_data']['data'],
        base64Encode([1, 2, 3]),
      );
    });

    test('a rejected key gives a clear message', () async {
      final analyzer = OwnKeyFoodAnalyzer(
        'bad',
        client: MockClient((_) async => http.Response('{}', 400)),
      );
      expect(
        () => analyzer.analyzeText('rice'),
        throwsA(
          isA<AnalysisFailure>().having(
            (e) => e.message,
            'message',
            contains('rejected your Gemini key'),
          ),
        ),
      );
    });

    test('the shared service is used until a key is saved', () async {
      final keys = MemoryKeyStore();
      final router = RoutingFoodAnalyzer(keys, DemoFoodAnalyzer());
      final shared = await router.analyzeText('rice');
      expect(shared.model, 'sample');
      expect(keys.hasKey.value, isFalse);
      await keys.write('k');
      expect(keys.hasKey.value, isTrue);
      await keys.clear();
      expect(await keys.read(), isNull);
    });
  });

  test('history groups entries per day', () async {
    final repo = MemoryRepo();
    final today = dayKeyOf(DateTime.now());
    await repo.saveFood(
      'u',
      FoodEntry(
        id: 'f',
        dayKey: today,
        meal: MealType.dinner,
        title: 'Dinner',
        items: const [FoodItem(name: 'Dal', calories: 180, protein: 11)],
        source: 'manual',
        createdAt: DateTime.now(),
      ),
    );
    await repo.updateDay('u', today, steps: 4200, weightKg: 69.5);
    await repo.updateDay('u', today, waterMl: 500);
    final days = await repo.history('u', today);
    expect(days.single.eaten, 180);
    expect(days.single.steps, 4200);
    expect(days.single.waterMl, 500);
    expect(days.single.weightKg, 69.5);
  });

  testWidgets('sign up, onboard, then log a meal manually', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ReemGymApp(services: Services.preview()));
    await tester.pumpAndSettle();

    // Sign in.
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Onboarding: name, then accept the defaults on every step.
    expect(find.text('What should we call you?'), findsOneWidget);
    // The name comes from the Google account.
    expect(find.widgetWithText(TextField, 'Reem'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Reem, your plan is ready'), findsOneWidget);
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    // Dashboard.
    expect(find.textContaining(', Reem'), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);

    // Log a meal by hand.
    await tester.tap(find.byTooltip('Log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add item'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Food name'),
      'Boiled egg',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Calories (kcal)'),
      '78',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Protein (g)'),
      '6',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();

    expect(find.text('78'), findsOneWidget); // "Eaten" on the summary card
    await tester.scrollUntilVisible(
      find.text('Boiled egg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Boiled egg'), findsOneWidget);
    expect(find.text('78 kcal'), findsWidgets);
  });
}
