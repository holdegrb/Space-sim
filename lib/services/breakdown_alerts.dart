import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Quiet hours, local time: an alert due between [quietStartHour]:00 and
/// [quietEndHour]:00 waits until [quietEndHour]:00.
const quietStartHour = 23;
const quietEndHour = 8;

/// When to tell the player about a breakdown at [breakdown] (local time): then, or
/// the end of quiet hours if it falls inside them.
DateTime alertTimeFor(DateTime breakdown, {bool quietHours = true}) {
  final t = breakdown.toLocal();
  if (!quietHours) return t;
  if (t.hour >= quietStartHour) {
    return DateTime(t.year, t.month, t.day + 1, quietEndHour);
  }
  if (t.hour < quietEndHour) {
    return DateTime(t.year, t.month, t.day, quietEndHour);
  }
  return t;
}

/// Tells the player their ship's maintenance is due, so they come back to service it.
/// An interface so tests (and the controller's default) can do without the plugin.
abstract interface class BreakdownAlerts {
  /// Replaces any pending alert with one at [at].
  Future<void> scheduleAt(DateTime at);
  Future<void> cancel();
}

class NoBreakdownAlerts implements BreakdownAlerts {
  const NoBreakdownAlerts();

  @override
  Future<void> scheduleAt(DateTime at) async {}

  @override
  Future<void> cancel() async {}
}

class LocalBreakdownAlerts implements BreakdownAlerts {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ship_status',
      'Ship status',
      channelDescription: 'When your ship needs maintenance',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_ship',
    ),
  );

  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_ship'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// POST_NOTIFICATIONS on Android 13+. Needs an Activity, so call from the UI.
  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  @override
  Future<void> scheduleAt(DateTime at) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
      if (!at.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _id,
        title: 'Maintenance due',
        body:
            'Your ship is holding position. Service it to keep exploring and '
            'get a tune-up boost.',
        // An absolute instant, so UTC is exact whatever the device's zone.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details,
        // Inexact on purpose: exact alarms need SCHEDULE_EXACT_ALARM, without which
        // every call throws on Android 12+. Cost: may arrive late under Doze.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Breakdown alert failed: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('Breakdown alert cancel failed: $e');
    }
  }
}
