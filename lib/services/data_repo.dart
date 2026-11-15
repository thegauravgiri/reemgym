import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

abstract class DataRepo {
  Stream<Profile?> watchProfile(String uid);
  Future<void> saveProfile(String uid, Profile profile);

  Stream<List<FoodEntry>> watchFood(String uid, String dayKey);
  Future<void> saveFood(String uid, FoodEntry entry);
  Future<void> deleteFood(String uid, String id);

  /// Most recently logged meals, newest first, one per distinct title.
  Future<List<FoodEntry>> recentFood(String uid);

  Stream<List<ExerciseEntry>> watchExercise(String uid, String dayKey);
  Future<void> saveExercise(String uid, ExerciseEntry entry);
  Future<void> deleteExercise(String uid, String id);

  Stream<DayStats> watchDay(String uid, String dayKey);
  Future<void> updateDay(
    String uid,
    String dayKey, {
    int? steps,
    int? waterMl,
    double? weightKg,
  });

  /// One summary per day from [fromDayKey] to today, oldest first.
  Future<List<DaySummary>> history(String uid, String fromDayKey);
}

List<FoodEntry> _distinctByTitle(Iterable<FoodEntry> newestFirst) {
  final seen = <String>{};
  return [
    for (final e in newestFirst)
      if (seen.add(e.title.trim().toLowerCase())) e,
  ];
}

List<DaySummary> _summarise(
  String fromDayKey,
  Iterable<FoodEntry> food,
  Iterable<ExerciseEntry> exercise,
  Iterable<DayStats> days,
) {
  final out = <String, DaySummary>{};
  final today = DateTime.now();
  for (
    var d = dayFromKey(fromDayKey);
    !d.isAfter(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final key = dayKeyOf(d);
    out[key] = DaySummary(key);
  }
  for (final f in food) {
    final s = out[f.dayKey];
    if (s == null) continue;
    s.eaten += f.calories;
    s.protein += f.protein;
    s.foodCount++;
  }
  for (final e in exercise) {
    out[e.dayKey]?.exercise += e.calories;
  }
  for (final d in days) {
    final s = out[d.dayKey];
    if (s == null) continue;
    s.steps = d.steps;
    s.waterMl = d.waterMl;
    s.weightKg = d.weightKg;
  }
  return out.values.toList();
}

/// Firestore layout: `users/{uid}` holds the profile; `food`, `exercise` and
/// `days` are sub-collections, so one security rule covers a user's data.
class FirestoreRepo implements DataRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _food(String uid) =>
      _user(uid).collection('food');
  CollectionReference<Map<String, dynamic>> _exercise(String uid) =>
      _user(uid).collection('exercise');
  CollectionReference<Map<String, dynamic>> _days(String uid) =>
      _user(uid).collection('days');

  @override
  Stream<Profile?> watchProfile(String uid) => _user(uid).snapshots().map((s) {
    final data = s.data();
    return data == null || data['name'] == null ? null : Profile.fromMap(data);
  });

  @override
  Future<void> saveProfile(String uid, Profile profile) =>
      _user(uid).set(profile.toMap(), SetOptions(merge: true));

  @override
  Stream<List<FoodEntry>> watchFood(String uid, String dayKey) => _food(uid)
      .where('dayKey', isEqualTo: dayKey)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => FoodEntry.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Future<void> saveFood(String uid, FoodEntry entry) =>
      _food(uid).doc(entry.id).set(entry.toMap());

  @override
  Future<void> deleteFood(String uid, String id) => _food(uid).doc(id).delete();

  @override
  Future<List<FoodEntry>> recentFood(String uid) async {
    final s = await _food(
      uid,
    ).orderBy('createdAt', descending: true).limit(60).get();
    return _distinctByTitle(
      s.docs.map((d) => FoodEntry.fromMap(d.id, d.data())),
    );
  }

  @override
  Stream<List<ExerciseEntry>> watchExercise(String uid, String dayKey) =>
      _exercise(uid)
          .where('dayKey', isEqualTo: dayKey)
          .snapshots()
          .map(
            (s) =>
                s.docs
                    .map((d) => ExerciseEntry.fromMap(d.id, d.data()))
                    .toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          );

  @override
  Future<void> saveExercise(String uid, ExerciseEntry entry) =>
      _exercise(uid).doc(entry.id).set(entry.toMap());

  @override
  Future<void> deleteExercise(String uid, String id) =>
      _exercise(uid).doc(id).delete();

  @override
  Stream<DayStats> watchDay(String uid, String dayKey) => _days(
    uid,
  ).doc(dayKey).snapshots().map((s) => DayStats.fromMap(dayKey, s.data()));

  @override
  Future<void> updateDay(
    String uid,
    String dayKey, {
    int? steps,
    int? waterMl,
    double? weightKg,
  }) => _days(uid).doc(dayKey).set({
    'dayKey': dayKey,
    'steps': ?steps,
    'waterMl': ?waterMl,
    'weightKg': ?weightKg,
  }, SetOptions(merge: true));

  @override
  Future<List<DaySummary>> history(String uid, String fromDayKey) async {
    final results = await Future.wait([
      _food(uid).where('dayKey', isGreaterThanOrEqualTo: fromDayKey).get(),
      _exercise(uid).where('dayKey', isGreaterThanOrEqualTo: fromDayKey).get(),
      _days(uid).where('dayKey', isGreaterThanOrEqualTo: fromDayKey).get(),
    ]);
    return _summarise(
      fromDayKey,
      results[0].docs.map((d) => FoodEntry.fromMap(d.id, d.data())),
      results[1].docs.map((d) => ExerciseEntry.fromMap(d.id, d.data())),
      results[2].docs.map((d) => DayStats.fromMap(d.id, d.data())),
    );
  }
}

/// Preview-mode storage: keeps everything in memory for the current run.
class MemoryRepo implements DataRepo {
  final _changes = StreamController<void>.broadcast();
  final _profiles = <String, Profile>{};
  final _food = <String, FoodEntry>{};
  final _exercise = <String, ExerciseEntry>{};
  final _days = <String, DayStats>{};

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<Profile?> watchProfile(String uid) => _watch(() => _profiles[uid]);

  @override
  Future<void> saveProfile(String uid, Profile profile) async {
    _profiles[uid] = profile;
    _changes.add(null);
  }

  @override
  Stream<List<FoodEntry>> watchFood(String uid, String dayKey) => _watch(
    () =>
        _food.values.where((e) => e.dayKey == dayKey).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  @override
  Future<void> saveFood(String uid, FoodEntry entry) async {
    _food[entry.id] = entry;
    _changes.add(null);
  }

  @override
  Future<void> deleteFood(String uid, String id) async {
    _food.remove(id);
    _changes.add(null);
  }

  @override
  Future<List<FoodEntry>> recentFood(String uid) async => _distinctByTitle(
    _food.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Stream<List<ExerciseEntry>> watchExercise(String uid, String dayKey) =>
      _watch(
        () =>
            _exercise.values.where((e) => e.dayKey == dayKey).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Future<void> saveExercise(String uid, ExerciseEntry entry) async {
    _exercise[entry.id] = entry;
    _changes.add(null);
  }

  @override
  Future<void> deleteExercise(String uid, String id) async {
    _exercise.remove(id);
    _changes.add(null);
  }

  @override
  Stream<DayStats> watchDay(String uid, String dayKey) =>
      _watch(() => _days[dayKey] ?? DayStats(dayKey: dayKey));

  @override
  Future<void> updateDay(
    String uid,
    String dayKey, {
    int? steps,
    int? waterMl,
    double? weightKg,
  }) async {
    final old = _days[dayKey] ?? DayStats(dayKey: dayKey);
    _days[dayKey] = DayStats(
      dayKey: dayKey,
      steps: steps ?? old.steps,
      waterMl: waterMl ?? old.waterMl,
      weightKg: weightKg ?? old.weightKg,
    );
    _changes.add(null);
  }

  @override
  Future<List<DaySummary>> history(String uid, String fromDayKey) async =>
      _summarise(fromDayKey, _food.values, _exercise.values, _days.values);
}
