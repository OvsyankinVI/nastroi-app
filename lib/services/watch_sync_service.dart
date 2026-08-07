import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/person.dart';

class WatchSyncService {
  static const MethodChannel _channel = MethodChannel('nastroi_watch_sync');

  static Future<void> updatePeople(List<Person> people) async {
    final friends = people
        .where(
          (p) =>
              p.id != 'me' &&
              p.sourceType != SourceType.friendRequestIncoming &&
              p.sourceType != SourceType.friendRequestPending,
        )
        .toList();

    final data = friends.map((person) {
      final activeStage = _activeStage(person);

      return {
        'id': person.publicId,
        'name': person.name,
        'mood': person.mood.name,
        'gender': person.gender.name,
        'avatarVariant': person.avatarVariant,
        'activeStage': activeStage?.title.isNotEmpty == true
            ? activeStage!.title
            : activeStage?.mood.name,
        'helpfulActions': activeStage?.helpfulActions ?? person.helpfulActions,
        'avoidActions': activeStage?.avoidActions ?? person.avoidActions,
      };
    }).toList();

    try {
      await _channel.invokeMethod('syncPeople', jsonEncode(data));

      if (kDebugMode) debugPrint('Watch sync completed: ${data.length} people');
    } catch (error) {
      if (kDebugMode) debugPrint('Watch sync error: $error');
    }
  }

  static CycleStage? _activeStage(Person person) {
    if (!person.lifeCycleEnabled || person.cycleStages.isEmpty) {
      return null;
    }

    final totalDays = person.cycleStages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationDays,
    );

    if (totalDays <= 0) return null;

    final startDate = person.cycleStartDateIso != null
        ? DateTime.tryParse(person.cycleStartDateIso!)
        : null;

    final start = _dateOnly(startDate ?? DateTime.now());
    final today = _dateOnly(DateTime.now());

    final diff = today.difference(start).inDays;
    final safeDiff = diff < 0 ? 0 : diff;
    final activeDay = (safeDiff % totalDays) + 1;

    int passed = 0;

    for (final stage in person.cycleStages) {
      passed += stage.durationDays;

      if (activeDay <= passed) {
        return stage;
      }
    }

    return null;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
