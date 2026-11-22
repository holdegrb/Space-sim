import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/dark_matter_shop.dart';
import 'game/game_state.dart';
import 'game/offline.dart';
import 'game/upgrades.dart';
import 'services/breakdown_alerts.dart';

const _saveKey = 'save';
const _lastSeenKey = 'last_seen_ms';
const _alertsKey = 'alerts_enabled';
const _quietHoursKey = 'alerts_quiet_hours';

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

  /// Player settings for the maintenance alert; both default on.
  bool get alertsEnabled => _prefs.getBool(_alertsKey) ?? true;
  bool get quietHours => _prefs.getBool(_quietHoursKey) ?? true;

  set alertsEnabled(bool v) {
    _prefs.setBool(_alertsKey, v);
    notifyListeners();
  }

  set quietHours(bool v) {
    _prefs.setBool(_quietHoursKey, v);
    notifyListeners();
  }

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
    if (alertsEnabled && !state.disabled) {
      alerts.scheduleAt(
        alertTimeFor(_now().add(state.timeToBreakdown), quietHours: quietHours),
      );
    }
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

  /// Services the ship; returns whether it earned a tune-up.
  bool repair() {
    final tunedUp = state.repair();
    save();
    notifyListeners();
    return tunedUp;
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

  bool buyPerk(Perk p) {
    final ok = state.buyPerk(p);
    if (ok) {
      save();
      notifyListeners();
    }
    return ok;
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
