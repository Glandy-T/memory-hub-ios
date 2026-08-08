import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/memory_data.dart';

abstract class MemoryNotificationService extends ChangeNotifier {
  bool get dailyEnabled;
  int get dailyHour;
  int get strongIntervalMinutes;

  Future<bool> setDailyCheck({required bool enabled, required int hour});
  Future<void> setStrongInterval(int minutes);
  Future<bool> syncTask(MemoryTask task);
  Future<void> cancelTask(String taskId);
}

class DisabledNotificationService extends MemoryNotificationService {
  @override
  bool get dailyEnabled => false;
  @override
  int get dailyHour => 8;
  @override
  int get strongIntervalMinutes => 15;

  @override
  Future<bool> setDailyCheck({
    required bool enabled,
    required int hour,
  }) async => !enabled;
  @override
  Future<void> setStrongInterval(int minutes) async {}
  @override
  Future<bool> syncTask(MemoryTask task) async =>
      task.notificationMode == TaskNotificationMode.none;
  @override
  Future<void> cancelTask(String taskId) async {}
}

class LocalMemoryNotificationService extends MemoryNotificationService {
  LocalMemoryNotificationService._(this._preferences);

  static const _dailyEnabledKey = 'memoryHub.dailyCheckEnabled';
  static const _dailyHourKey = 'memoryHub.dailyCheckHour';
  static const _strongIntervalKey = 'memoryHub.strongReminderInterval';
  static const _dailyNotificationId = 700001;
  static const _taskNotificationBase = 800000;

  final SharedPreferences _preferences;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  bool get dailyEnabled => _preferences.getBool(_dailyEnabledKey) ?? false;
  @override
  int get dailyHour => _preferences.getInt(_dailyHourKey) ?? 8;
  @override
  int get strongIntervalMinutes =>
      _preferences.getInt(_strongIntervalKey) ?? 15;

  static Future<LocalMemoryNotificationService> create() async {
    final service = LocalMemoryNotificationService._(
      await SharedPreferences.getInstance(),
    );
    await service._initialize();
    return service;
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (dailyEnabled) await _scheduleDailyCheck(dailyHour);
  }

  Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> setDailyCheck({required bool enabled, required int hour}) async {
    if (enabled && !await _requestPermission()) return false;
    await _preferences.setBool(_dailyEnabledKey, enabled);
    await _preferences.setInt(_dailyHourKey, hour);
    await _plugin.cancel(id: _dailyNotificationId);
    if (enabled) await _scheduleDailyCheck(hour);
    notifyListeners();
    return true;
  }

  Future<void> _scheduleDailyCheck(int hour) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyNotificationId,
      title: '看看今天还有什么',
      body: '打开 Memory Hub，轻轻确认一下事项和提醒。',
      scheduledDate: next,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily-check',
    );
  }

  @override
  Future<void> setStrongInterval(int minutes) async {
    await _preferences.setInt(_strongIntervalKey, minutes);
    notifyListeners();
  }

  @override
  Future<bool> syncTask(MemoryTask task) async {
    await cancelTask(task.id);
    if (task.status != MemoryTaskStatus.active ||
        task.notificationMode == TaskNotificationMode.none ||
        task.minutesFromMidnight == null) {
      return true;
    }
    final scheduled = tz.TZDateTime(
      tz.local,
      task.date.year,
      task.date.month,
      task.date.day,
      task.minutesFromMidnight! ~/ 60,
      task.minutesFromMidnight! % 60,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return true;
    if (!await _requestPermission()) return false;
    final count = task.notificationMode == TaskNotificationMode.strong ? 6 : 1;
    for (var index = 0; index < count; index++) {
      await _plugin.zonedSchedule(
        id: _taskNotificationId(task.id, index),
        title: task.title,
        body: index == 0 ? '你设置的事项时间到了。' : '这条强提醒仍未处理。',
        scheduledDate: scheduled.add(
          Duration(minutes: strongIntervalMinutes * index),
        ),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    }
    return true;
  }

  @override
  Future<void> cancelTask(String taskId) async {
    for (var index = 0; index < 6; index++) {
      await _plugin.cancel(id: _taskNotificationId(taskId, index));
    }
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'memory_hub_reminders',
      'Memory Hub 提醒',
      channelDescription: '每日检查和用户主动设置的事项提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  int _taskNotificationId(String taskId, int index) {
    var hash = 2166136261;
    for (final unit in taskId.codeUnits) {
      hash = (hash ^ unit) * 16777619 & 0x7fffffff;
    }
    return _taskNotificationBase + (hash % 100000) * 6 + index;
  }
}
