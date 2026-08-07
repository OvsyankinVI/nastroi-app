import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/person.dart';

class WidgetService {
  static const String appGroupId = 'group.com.vlad.nastroi';
  static const String peopleKey = 'widget_people';

  static Future<void> updatePeople(List<Person> people) async {
    await HomeWidget.setAppGroupId(appGroupId);

    final friends = people
        .where(
          (p) =>
              p.id != 'me' &&
              p.sourceType != SourceType.friendRequestIncoming &&
              p.sourceType != SourceType.friendRequestPending,
        )
        .toList();

    final data = friends.map((person) {
      String? activeStage;

      if (person.lifeCycleEnabled &&
          person.cycleStages.isNotEmpty &&
          person.cycleStartDateIso != null) {
        activeStage = _getActiveStage(person);
      }

      return {
        'id': person.publicId,
        'name': person.name,
        'mood': person.mood.name,
        'gender': person.gender.name,
        'avatarVariant': person.avatarVariant,
        'activeStage': activeStage,
      };
    }).toList();

    await HomeWidget.saveWidgetData(peopleKey, jsonEncode(data));

    await HomeWidget.updateWidget(iOSName: 'NastroiWidget');
  }

  static String? _getActiveStage(Person person) {
    final start = DateTime.tryParse(person.cycleStartDateIso ?? '');

    if (start == null) return null;

    final totalDays = person.cycleStages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationDays,
    );

    if (totalDays == 0) return null;

    final today = DateTime.now();
    final diff = today.difference(start).inDays;
    final currentDay = (diff % totalDays) + 1;

    int passed = 0;

    for (final stage in person.cycleStages) {
      passed += stage.durationDays;

      if (currentDay <= passed) {
        return stage.title.isNotEmpty ? stage.title : stage.mood.name;
      }
    }

    return null;
  }
}
