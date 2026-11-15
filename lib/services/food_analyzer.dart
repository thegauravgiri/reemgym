import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'key_store.dart';

class AnalysisResult {
  final String title;
  final List<FoodItem> items;

  /// Assumptions the model made, shown so the user knows what to double-check.
  final String notes;

  /// Model that produced the result, and whether the user's own key paid.
  final String model;
  final bool ownKey;

  const AnalysisResult(
    this.title,
    this.items,
    this.notes, {
    this.model = geminiModel,
    this.ownKey = false,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'notes': notes,
    'items': items.map((i) => i.toMap()).toList(),
  };
}

/// An analysis problem with a message that is safe to show to the user.
class AnalysisFailure implements Exception {
  final String message;

  /// True when the shared free allowance is used up, so the screen can offer
  /// "use your own key".
  final bool quotaExceeded;

  const AnalysisFailure(this.message, {this.quotaExceeded = false});
  @override
  String toString() => message;
}

abstract class FoodAnalyzer {
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint,
  });
  Future<AnalysisResult> analyzeText(String description);
}

/// Gemini model used for food analysis. Listed as current in the Firebase AI
/// Logic model list (Nov 2026); change it here when Google retires it.
const geminiModel = 'gemini-3.8-flash';

const _instructions = '''
You are a careful nutritionist estimating what a person ate.
Break the meal into its separate foods and drinks. For each one, estimate the
portion actually shown or described (use household measures plus grams, e.g.
"1 cup, about 160 g") and the nutrients for that whole portion.
Recognise regional dishes by their real names (for example dal bhat, momo,
chow mein, sel roti) and account for typical cooking oil, ghee and sauces.
Use visible references such as plates, cutlery and hands to judge size.
If something is unclear, pick the most likely option and say so in "notes".
If there is no food or drink at all, return an empty "items" list and explain
why in "notes". Numbers must be realistic; never return zero calories for
real food.''';

String _imagePrompt(String hint) => hint.trim().isEmpty
    ? 'Estimate the nutrition of the meal in this photo.'
    : 'Estimate the nutrition of the meal in this photo. '
          'The person adds: "${hint.trim()}"';

String _textPrompt(String description) =>
    'Estimate the nutrition of this meal: "${description.trim()}"';

bool _looksLikeQuota(Object error) {
  final text = '$error'.toLowerCase();
  return text.contains('429') ||
      text.contains('quota') ||
      text.contains('resource_exhausted') ||
      text.contains('resource has been exhausted') ||
      text.contains('rate limit');
}

AnalysisResult _finish(String? text, {required bool ownKey}) {
  if (text == null || text.isEmpty) {
    throw const AnalysisFailure(
      'The analysis came back empty. Try again or add the food manually.',
    );
  }
  final AnalysisResult result;
  try {
    result = parseAnalysis(text, ownKey: ownKey);
  } catch (_) {
    throw const AnalysisFailure(
      'The analysis could not be read. Try again or add the food manually.',
    );
  }
  if (result.items.isEmpty) {
    throw AnalysisFailure(
      result.notes.isEmpty
          ? 'No food was recognised. Try another photo or add it manually.'
          : result.notes,
    );
  }
  return result;
}

/// Parses the model's JSON reply. Kept separate so it can be unit tested.
AnalysisResult parseAnalysis(String json, {bool ownKey = false}) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final items = ((map['items'] as List?) ?? const [])
      .map((e) => FoodItem.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  return AnalysisResult(
    '${map['title'] ?? 'Meal'}',
    items,
    '${map['notes'] ?? ''}',
    ownKey: ownKey,
  );
}

/// Shared analysis through Firebase AI Logic: no key in the app, and every
/// user draws on the project's allowance.
class GeminiFoodAnalyzer implements FoodAnalyzer {
  /// The Firebase app whose project provides the shared Gemini allowance.
  final FirebaseApp app;
  GeminiFoodAnalyzer(this.app);

  late final GenerativeModel
  _model = FirebaseAI.googleAI(app: app).generativeModel(
    model: geminiModel,
    systemInstruction: Content.system(_instructions),
    generationConfig: GenerationConfig(
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(
            description: 'Short name for the whole meal, e.g. "Dal bhat set"',
          ),
          'notes': Schema.string(
            description: 'One or two sentences on assumptions and uncertainty.',
          ),
          'items': Schema.array(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'portion': Schema.string(
                  description: 'Estimated portion, e.g. "1 cup, about 160 g"',
                ),
                'calories': Schema.number(description: 'kcal for the portion'),
                'protein': Schema.number(description: 'grams'),
                'carbs': Schema.number(description: 'grams'),
                'fat': Schema.number(description: 'grams'),
                'fiber': Schema.number(description: 'grams'),
                'sugar': Schema.number(description: 'grams'),
                'sodiumMg': Schema.number(description: 'milligrams'),
              },
            ),
          ),
        },
      ),
    ),
  );

  @override
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint = '',
  }) => _run(
    Content.multi([
      InlineDataPart(mimeType, bytes),
      TextPart(_imagePrompt(hint)),
    ]),
  );

  @override
  Future<AnalysisResult> analyzeText(String description) =>
      _run(Content.text(_textPrompt(description)));

  Future<AnalysisResult> _run(Content content) async {
    final String? text;
    try {
      text = (await _model.generateContent([content])).text;
    } catch (e) {
      if (_looksLikeQuota(e)) {
        throw const AnalysisFailure(
          'The free shared allowance for food analysis is used up for now. '
          'Add your own free Gemini key to keep scanning, or enter the food '
          'manually.',
          quotaExceeded: true,
        );
      }
      throw AnalysisFailure(
        'Could not reach the food analysis service. Check your connection '
        'and try again.\n($e)',
      );
    }
    return _finish(text, ownKey: false);
  }
}

const _restSchema = {
  'type': 'OBJECT',
  'properties': {
    'title': {'type': 'STRING'},
    'notes': {'type': 'STRING'},
    'items': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'name': {'type': 'STRING'},
          'portion': {'type': 'STRING'},
          'calories': {'type': 'NUMBER'},
          'protein': {'type': 'NUMBER'},
          'carbs': {'type': 'NUMBER'},
          'fat': {'type': 'NUMBER'},
          'fiber': {'type': 'NUMBER'},
          'sugar': {'type': 'NUMBER'},
          'sodiumMg': {'type': 'NUMBER'},
        },
        'required': ['name', 'portion', 'calories', 'protein', 'carbs', 'fat'],
      },
    },
  },
  'required': ['title', 'notes', 'items'],
};

const _geminiHost = 'generativelanguage.googleapis.com';

/// Analysis with the user's own Gemini API key, sent straight to Google.
class OwnKeyFoodAnalyzer implements FoodAnalyzer {
  final String apiKey;
  final http.Client _client;
  OwnKeyFoodAnalyzer(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  /// Returns null when [apiKey] works, otherwise a message for the user.
  static Future<String?> check(String apiKey, {http.Client? client}) async {
    try {
      final response = await (client ?? http.Client())
          .get(
            Uri.https(_geminiHost, '/v1beta/models/$geminiModel'),
            headers: {'x-goog-api-key': apiKey},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return null;
      if (response.statusCode == 400 || response.statusCode == 403) {
        return 'Google did not accept this key. Check that you copied all '
            'of it.';
      }
      return 'Could not check the key (error ${response.statusCode}).';
    } catch (_) {
      return 'Could not reach Google to check the key. Check your connection.';
    }
  }

  @override
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint = '',
  }) => _run([
    {
      'inline_data': {'mime_type': mimeType, 'data': base64Encode(bytes)},
    },
    {'text': _imagePrompt(hint)},
  ]);

  @override
  Future<AnalysisResult> analyzeText(String description) => _run([
    {'text': _textPrompt(description)},
  ]);

  Future<AnalysisResult> _run(List<Map<String, dynamic>> parts) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.https(
              _geminiHost,
              '/v1beta/models/$geminiModel:generateContent',
            ),
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': _instructions},
                ],
              },
              'contents': [
                {'role': 'user', 'parts': parts},
              ],
              'generationConfig': {
                'temperature': 0.2,
                'responseMimeType': 'application/json',
                'responseSchema': _restSchema,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const AnalysisFailure(
        'Could not reach Google. Check your connection and try again.',
      );
    }
    if (response.statusCode == 429) {
      throw const AnalysisFailure(
        'Your Gemini key has reached its limit for now. Wait a little, or '
        'enter the food manually.',
      );
    }
    if (response.statusCode == 400 || response.statusCode == 403) {
      throw const AnalysisFailure(
        'Google rejected your Gemini key. Check or replace it in Profile.',
      );
    }
    if (response.statusCode != 200) {
      throw AnalysisFailure(
        'Food analysis failed (error ${response.statusCode}). Try again.',
      );
    }
    String? text;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final parts = body['candidates'][0]['content']['parts'] as List;
      text = parts.map((p) => (p as Map)['text'] ?? '').join();
    } catch (_) {
      text = null;
    }
    return _finish(text, ownKey: true);
  }
}

/// Stands in for the shared service when there is none: every request asks
/// the user to add their own key.
class NoSharedAnalyzer implements FoodAnalyzer {
  static const _failure = AnalysisFailure(
    'Food analysis needs your own free Gemini key. Add one to start '
    'scanning, or enter the food manually.',
    quotaExceeded: true,
  );

  @override
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint = '',
  }) async => throw _failure;

  @override
  Future<AnalysisResult> analyzeText(String description) async =>
      throw _failure;
}

/// Uses the user's own key when one is saved, otherwise the shared service.
class RoutingFoodAnalyzer implements FoodAnalyzer {
  final KeyStore keys;
  final FoodAnalyzer shared;
  RoutingFoodAnalyzer(this.keys, this.shared);

  Future<FoodAnalyzer> _pick() async {
    final key = await keys.read();
    return key == null ? shared : OwnKeyFoodAnalyzer(key);
  }

  @override
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint = '',
  }) async => (await _pick()).analyzeImage(bytes, mimeType, hint: hint);

  @override
  Future<AnalysisResult> analyzeText(String description) async =>
      (await _pick()).analyzeText(description);
}

/// Preview-mode analyzer: returns a fixed sample so the flow can be tried
/// before Firebase is connected.
class DemoFoodAnalyzer implements FoodAnalyzer {
  static const _sample = AnalysisResult(
    'Dal bhat set (sample)',
    [
      FoodItem(
        name: 'Steamed rice',
        portion: '1.5 cups, about 240 g',
        calories: 310,
        protein: 6,
        carbs: 68,
        fat: 0.6,
        fiber: 1,
        sodiumMg: 5,
      ),
      FoodItem(
        name: 'Dal (lentil soup)',
        portion: '1 bowl, about 200 g',
        calories: 180,
        protein: 11,
        carbs: 26,
        fat: 4,
        fiber: 7,
        sugar: 2,
        sodiumMg: 480,
      ),
      FoodItem(
        name: 'Chicken curry',
        portion: '1 serving, about 150 g',
        calories: 260,
        protein: 24,
        carbs: 6,
        fat: 15,
        fiber: 1,
        sugar: 2,
        sodiumMg: 620,
      ),
      FoodItem(
        name: 'Saag (sautéed greens)',
        portion: '1/2 cup, about 80 g',
        calories: 60,
        protein: 3,
        carbs: 5,
        fat: 3.5,
        fiber: 3,
        sodiumMg: 210,
      ),
    ],
    'Preview mode: this is a fixed sample, not an analysis of your input. '
        'Add your own Gemini key in Profile, or connect Firebase, to analyse '
        'real meals.',
    model: 'sample',
  );

  @override
  Future<AnalysisResult> analyzeImage(
    Uint8List bytes,
    String mimeType, {
    String hint = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return _sample;
  }

  @override
  Future<AnalysisResult> analyzeText(String description) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return _sample;
  }
}
