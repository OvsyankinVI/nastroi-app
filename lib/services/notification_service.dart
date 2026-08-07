import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/person.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const int _notificationHour = 9;
  static const int _notificationMinute = 0;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Moscow'));

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(iOS: iosSettings);

    await _plugin.initialize(settings: settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static Future<void> initialize() async {
    await init();
  }

  static Future<void> showChatNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'CHAT_MESSAGE',
        ),
      ),
    );
  }

  static Future<void> rescheduleCycleNotifications(List<Person> people) async {
    await _plugin.cancelAll();

    for (final person in people) {
      await scheduleCycleNotification(person);
    }
  }

  static Future<void> scheduleCycleNotification(Person person) async {
    if (!person.lifeCycleEnabled || person.cycleStages.isEmpty) {
      return;
    }

    final startDateIso = person.cycleStartDateIso;
    if (startDateIso == null) {
      return;
    }

    final startDate = DateTime.tryParse(startDateIso);
    if (startDate == null) {
      return;
    }

    final nextStage = _nextStageChange(person, startDate);
    if (nextStage == null) {
      return;
    }

    final notificationDate = DateTime(
      nextStage.date.year,
      nextStage.date.month,
      nextStage.date.day,
      _notificationHour,
      _notificationMinute,
    );

    await _plugin.zonedSchedule(
      id: _notificationId(person.publicId),
      title: 'У ${person.name} новый этап',
      body: nextStage.stageTitle,
      scheduledDate: tz.TZDateTime.from(notificationDate, tz.local),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static _NextStageChange? _nextStageChange(Person person, DateTime startDate) {
    final stages = person.cycleStages;
    if (stages.isEmpty) {
      return null;
    }

    final totalDays = stages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationDays,
    );

    if (totalDays <= 0) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final diff = today.difference(start).inDays;
    final safeDiff = diff < 0 ? 0 : diff;
    final currentDayIndex = safeDiff % totalDays;

    int passed = 0;

    for (final stage in stages) {
      passed += stage.durationDays;

      if (currentDayIndex < passed) {
        final daysUntilNextStage = passed - currentDayIndex;

        final nextDayNumber =
            ((currentDayIndex + daysUntilNextStage) % totalDays) + 1;

        final nextStage = _stageForDay(stages, nextDayNumber);

        return _NextStageChange(
          date: today.add(Duration(days: daysUntilNextStage)),
          stageTitle: nextStage.title.isNotEmpty
              ? nextStage.title
              : _moodLabel(nextStage.mood),
        );
      }
    }

    return null;
  }

  static CycleStage _stageForDay(List<CycleStage> stages, int dayNumber) {
    int passed = 0;

    for (final stage in stages) {
      passed += stage.durationDays;

      if (dayNumber <= passed) {
        return stage;
      }
    }

    return stages.last;
  }

  static String _moodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Радостно';
      case MoodType.calm:
        return 'Спокойно';
      case MoodType.sad:
        return 'Грустно';
      case MoodType.irritated:
        return 'Раздражён';
      case MoodType.tired:
        return 'Устал';
      case MoodType.needsCare:
        return 'Нужна забота';
    }
  }

  static int _notificationId(String value) {
    return value.hashCode.abs() % math.pow(2, 31).toInt();
  }
}

class _NextStageChange {
  final DateTime date;
  final String stageTitle;

  const _NextStageChange({required this.date, required this.stageTitle});
}
