import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

enum Movement { unknown, still, walking, running }

/// Counts today's steps.
///
/// Two sources are combined:
///  * Apple Health / Health Connect gives the day's total. The phone's motion
///    chip records these steps all day, including while ReemGym is closed, so
///    nothing has to keep running in the background.
///  * The live pedometer stream adds steps as they happen while the app is
///    open, and its cadence tells walking (below ~150 steps/min) from running.
class StepService {
  final ValueNotifier<int> steps = ValueNotifier(0);
  final ValueNotifier<Movement> movement = ValueNotifier(Movement.unknown);

  /// Called with the latest count so it can be saved; throttled.
  void Function(int steps)? onPersist;

  final _health = Health();
  StreamSubscription<StepCount>? _countSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  Timer? _idleTimer;
  Timer? _refreshTimer;

  int _base = 0;
  int? _liveStart;
  int _liveLatest = 0;
  int _lastPersisted = -1;
  String _day = '';
  bool _healthGranted = false;
  bool _running = false;
  final _recent = <(DateTime, int)>[];

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isRunning => _running;

  /// Asks for motion and health permissions, then starts counting.
  /// Returns false when the device or the user does not allow step counting.
  Future<bool> enable({int savedSteps = 0}) async {
    if (!supported) return false;
    var motionGranted = false;
    try {
      final permission = defaultTargetPlatform == TargetPlatform.android
          ? Permission.activityRecognition
          : Permission.sensors;
      motionGranted = (await permission.request()).isGranted;
    } catch (e) {
      debugPrint('Motion permission failed: $e');
    }
    try {
      await _health.configure();
      if (defaultTargetPlatform != TargetPlatform.android ||
          await _health.isHealthConnectAvailable()) {
        _healthGranted = await _health.requestAuthorization([
          HealthDataType.STEPS,
        ]);
      }
    } catch (e) {
      debugPrint('Health permission failed: $e');
    }
    if (!motionGranted && !_healthGranted) return false;
    await start(savedSteps: savedSteps, motionGranted: motionGranted);
    return true;
  }

  /// Starts counting without prompting; used on launch once the user has
  /// already turned step tracking on.
  Future<void> resume({int savedSteps = 0}) async {
    if (!supported || _running) return;
    var motionGranted = false;
    try {
      final permission = defaultTargetPlatform == TargetPlatform.android
          ? Permission.activityRecognition
          : Permission.sensors;
      motionGranted = await permission.isGranted;
      await _health.configure();
      _healthGranted =
          await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
    } catch (e) {
      debugPrint('Step resume failed: $e');
    }
    // HealthKit never reveals whether read access was granted, so on iOS a
    // read is attempted regardless.
    if (defaultTargetPlatform == TargetPlatform.iOS) _healthGranted = true;
    await start(savedSteps: savedSteps, motionGranted: motionGranted);
  }

  Future<void> start({int savedSteps = 0, bool motionGranted = true}) async {
    if (_running) return;
    _running = true;
    _day = _today();
    _base = savedSteps;
    steps.value = savedSteps;
    await refresh();
    if (motionGranted) {
      _countSub = Pedometer.stepCountStream.listen(
        _onCount,
        onError: (Object e) => debugPrint('Steps: $e'),
      );
      _statusSub = Pedometer.pedestrianStatusStream.listen((s) {
        if (s.status == 'stopped') movement.value = Movement.still;
      }, onError: (Object e) => debugPrint('Pedestrian status: $e'));
    }
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => refresh(),
    );
  }

  /// Re-reads the day's total from the health store (call on app resume).
  Future<void> refresh() async {
    if (!_running) return;
    _rollDayIfNeeded();
    if (_healthGranted) {
      try {
        final now = DateTime.now();
        final total = await _health.getTotalStepsInInterval(
          DateTime(now.year, now.month, now.day),
          now,
        );
        // The health store can lag a few minutes behind the live sensor, so
        // it only replaces our count once it has caught up.
        if (total != null && total >= steps.value) {
          _base = total;
          _liveStart = _liveLatest == 0 ? null : _liveLatest;
          _publish();
        }
      } catch (e) {
        debugPrint('Health read failed: $e');
      }
    }
    _persist(force: true);
  }

  void _onCount(StepCount event) {
    _rollDayIfNeeded();
    _liveLatest = event.steps;
    _liveStart ??= event.steps;
    // The sensor counter restarts from zero when the phone reboots.
    if (event.steps < _liveStart!) _liveStart = event.steps;
    _publish();

    final now = DateTime.now();
    _recent.add((now, event.steps));
    _recent.removeWhere(
      (r) => now.difference(r.$1) > const Duration(seconds: 12),
    );
    if (_recent.length >= 2) {
      final span = now.difference(_recent.first.$1).inMilliseconds;
      if (span >= 3000) {
        final cadence = (event.steps - _recent.first.$2) * 60000 / span;
        movement.value = cadence >= 150 ? Movement.running : Movement.walking;
      }
    } else if (movement.value != Movement.running) {
      movement.value = Movement.walking;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 10), () {
      movement.value = Movement.still;
      _recent.clear();
    });
    _persist();
  }

  void _publish() {
    final live = _liveStart == null ? 0 : _liveLatest - _liveStart!;
    steps.value = _base + (live < 0 ? 0 : live);
  }

  void _persist({bool force = false}) {
    final value = steps.value;
    if (value == _lastPersisted) return;
    if (!force && (value - _lastPersisted).abs() < 50) return;
    _lastPersisted = value;
    onPersist?.call(value);
  }

  void _rollDayIfNeeded() {
    final today = _today();
    if (today == _day) return;
    _day = today;
    _base = 0;
    _liveStart = _liveLatest == 0 ? null : _liveLatest;
    _lastPersisted = -1;
    steps.value = 0;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void stop() {
    _running = false;
    _countSub?.cancel();
    _statusSub?.cancel();
    _idleTimer?.cancel();
    _refreshTimer?.cancel();
    _countSub = null;
    _statusSub = null;
    _liveStart = null;
    _liveLatest = 0;
    _recent.clear();
    movement.value = Movement.unknown;
  }
}
