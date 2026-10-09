import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the phone notification for a check-up. Replaceable in tests.
abstract class ReminderScheduler {
  /// Asks for notification permission if needed. True if reminders can show.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

/// The scheduler the app uses. Tests swap in a fake.
ReminderScheduler reminders = LocalNotificationsScheduler();

/// A stable notification id for a saved report.
int reminderIdFor(String reportId) => reportId.hashCode & 0x7fffffff;

/// Reminders go off in the morning of the check-up day.
DateTime reminderTime(DateTime day) =>
    DateTime(day.year, day.month, day.day, 9);

class LocalNotificationsScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Reminder permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    try {
      await _init();
      // A moment in the past cannot be scheduled.
      if (!when.isAfter(DateTime.now())) {
        await _plugin.cancel(id: id);
        return;
      }
      await _plugin.zonedSchedule(
        id: id,
        // A fixed instant, so it does not depend on the time zone database.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'checkups',
            'Check-up reminders',
            channelDescription: 'Reminds you when a medical check-up is due',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        // Approximate timing needs no special permission and is plenty for a
        // reminder that is days or months away.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _init();
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Could not cancel reminder: $e');
    }
  }
}
