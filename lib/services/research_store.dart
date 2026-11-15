import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'food_analyzer.dart';

/// One analysed meal, kept for research: what was sent, what the model
/// answered, and what the user corrected it to before logging.
class ResearchSample {
  final FoodEntry logged;
  final AnalysisResult analysis;
  final Uint8List? image;
  final String mimeType;
  final String? description;

  const ResearchSample({
    required this.logged,
    required this.analysis,
    this.image,
    this.mimeType = 'image/jpeg',
    this.description,
  });
}

/// Saves research samples. Only called for users who agreed to share.
abstract class ResearchStore {
  Future<void> save(String uid, ResearchSample sample);
}

class NoResearchStore implements ResearchStore {
  @override
  Future<void> save(String uid, ResearchSample sample) async {}
}

/// Photo goes to Cloud Storage at `users/{uid}/meals/{entryId}`; the record
/// goes to Firestore at `users/{uid}/analyses/{entryId}`. Query every user's
/// records with a collection-group query on `analyses`.
class FirebaseResearchStore implements ResearchStore {
  @override
  Future<void> save(String uid, ResearchSample sample) async {
    try {
      final id = sample.logged.id;
      String? imagePath;
      if (sample.image != null) {
        final ext = sample.mimeType.contains('png') ? 'png' : 'jpg';
        imagePath = 'users/$uid/meals/$id.$ext';
        await FirebaseStorage.instance
            .ref(imagePath)
            .putData(
              sample.image!,
              SettableMetadata(contentType: sample.mimeType),
            );
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('analyses')
          .doc(id)
          .set({
            'uid': uid,
            'entryId': id,
            'createdAt': FieldValue.serverTimestamp(),
            'input': sample.image != null ? 'photo' : 'text',
            'imagePath': imagePath,
            'description': sample.description,
            'model': sample.analysis.model,
            'ownKey': sample.analysis.ownKey,
            'ai': sample.analysis.toMap(),
            'logged': {
              'title': sample.logged.title,
              'meal': sample.logged.meal.name,
              'items': sample.logged.items.map((i) => i.toMap()).toList(),
              'calories': sample.logged.calories,
              'protein': sample.logged.protein,
              'carbs': sample.logged.carbs,
              'fat': sample.logged.fat,
            },
          });
    } catch (e) {
      // Never let research capture get in the way of logging a meal.
      debugPrint('Saving research sample failed: $e');
    }
  }
}
