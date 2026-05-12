import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/person.dart';

class WatchSyncService {
  static const MethodChannel _channel = MethodChannel('nastroi_watch_sync');

  static Future<void> syncPeople(List<Person> people) async {
    final payload = people.map((person) {
      final activePerson = person.applyLifeCycleForDate(DateTime.now());

      return {
        'id': activePerson.id,
        'name': activePerson.name,
        'mood': activePerson.mood.name,
        'gender': activePerson.gender.name,
        'avatarVariant': activePerson.avatarVariant,
        'activeStage': activePerson.activeCycleStageForDate(DateTime.now())?.title,
        'helpfulActions': activePerson.helpfulActions,
        'avoidActions': activePerson.avoidActions,
      };
    }).toList();

    await _channel.invokeMethod(
      'syncPeople',
      jsonEncode(payload),
    );
  }
}