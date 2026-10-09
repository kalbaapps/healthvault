import 'package:healthvault/reminders.dart';

/// Records what the app asks of the phone's notification system.
class FakeReminders implements ReminderScheduler {
  bool permission = true;
  int permissionRequests = 0;
  final scheduled = <({int id, DateTime when, String title, String body})>[];
  final cancelled = <int>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, when: when, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}
