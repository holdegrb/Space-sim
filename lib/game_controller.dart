import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_state.dart';
import 'game/offline.dart';
import 'game/upgrades.dart';
import 'services/breakdown_alerts.dart';

const _saveKey = 'save';
const _lastSeenKey = 'last_seen_ms';

/// Owns the [GameState], runs it in real time while the app is in the foreground,
/// saves it, and applies offline progress when the player comes back.
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController(
    this._prefs,
    this.state, {
    DateTime Function()? now,
    this.alerts = const NoBreakdownAlerts(),
  }) : _now = now ?? DateTime.now;

  static Future<GameController> load({
    DateTime Function()? now,
    BreakdownAlerts alerts = const NoBreakdownAlerts(),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final c = GameController(prefs, _readSave(prefs), now: now, alerts: alerts);
    final lastSeen = prefs.getInt(_lastSeenKey);
    if (lastSeen != null) {
      c._applyOffline(DateTime.fromMillisecondsSinceEpoch(lastSeen));
    }
    return c;
  }

  static GameState _readSave(SharedPreferences prefs) {
    final raw = prefs.getString(_saveKey);
    if (raw == null) return GameState();
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // A corrupt save shouldn't brick the game.
      return GameState();
    }
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final BreakdownAlerts alerts;
  GameState state;

  /// Shown once by the UI, then cleared with [dismissReport].
  OfflineReport? pendingReport;

  Timer? _timer;
  final _stopwatch = Stopwatch();
  double _sinceSave = 0;

  /// Starts real-time play. Call once the UI is up.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    alerts.cancel();
    _resume();
  }

  void _resume() {
    _timer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _frame());
  }

  void _frame() {
    // A long stall (debugger, a frozen frame) is capped rather than simulated at
    // once; real absences go through the lifecycle and offline progress instead.
    final dt = min(1.0, _stopwatch.elapsedMicroseconds / 1e6);
    _stopwatch
      ..reset()
      ..start();
    state.tick(dt);
    _sinceSave += dt;
    if (_sinceSave >= 15) save();
    notifyListeners();
  }

  void _pauseRealtime() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    save();
    // While the app is away the ship keeps fighting until its integrity runs out;
    // tell the player when that happens so they come back and repair it.
    if (!state.disabled) alerts.scheduleAt(_now().add(state.timeToBreakdown));
  }

  void _applyOffline(DateTime lastSeen) {
    final away = _now().difference(lastSeen);
    final report = simulateOffline(state, away);
    if (away >= offlineReportThreshold) pendingReport = report;
    save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_timer != null) return;
        final lastSeen = _prefs.getInt(_lastSeenKey);
        if (lastSeen != null) {
          _applyOffline(DateTime.fromMillisecondsSinceEpoch(lastSeen));
        }
        alerts.cancel();
        _resume();
        notifyListeners();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_timer != null) _pauseRealtime();
      case AppLifecycleState.inactive:
        // Notification shade, split-screen focus: keep playing.
        break;
    }
  }

  void save() {
    _sinceSave = 0;
    _prefs.setString(_saveKey, jsonEncode(state.toJson()));
    _prefs.setInt(_lastSeenKey, _now().millisecondsSinceEpoch);
  }

  bool buy(Upgrade u) {
    final ok = state.buy(u);
    if (ok) {
      save();
      notifyListeners();
    }
    return ok;
  }

  void repair() {
    state.repair();
    save();
    notifyListeners();
  }

  /// Jumps to a new galaxy; returns the Dark Matter gained (0 = not allowed yet).
  int prestige() {
    final gain = state.prestige();
    if (gain > 0) {
      save();
      notifyListeners();
    }
    return gain;
  }

  void challengeBoss() {
    state.challengeBoss();
    notifyListeners();
  }

  void dismissReport() {
    pendingReport = null;
    notifyListeners();
  }

  /// Wipes all progress.
  void reset() {
    state = GameState();
    alerts.cancel();
    pendingReport = null;
    save();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Gives the widget tree the controller and rebuilds dependents on every frame.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope({
    super.key,
    required GameController controller,
    required super.child,
  }) : super(notifier: controller);

  static GameController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;
}
