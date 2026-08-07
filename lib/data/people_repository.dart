import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';
import 'mock_people.dart';

class PeopleRepository {
  final String userId;

  PeopleRepository({required this.userId});

  String get _storageKey => 'people_storage_v1_$userId';

  Future<List<Person>> loadPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored == null || stored.isEmpty) {
      final defaults = _ensureUniqueMyPublicId(List<Person>.from(mockPeople));

      await savePeople(defaults);
      return defaults;
    }

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;

      final people = decoded
          .map((item) => Person.fromMap(item as Map<String, dynamic>))
          .toList();

      final migrated = _ensureUniqueMyPublicId(people);
      await savePeople(migrated);

      return migrated;
    } catch (_) {
      final defaults = _ensureUniqueMyPublicId(List<Person>.from(mockPeople));

      await savePeople(defaults);
      return defaults;
    }
  }

  Future<void> savePeople(List<Person> people) async {
    final prefs = await SharedPreferences.getInstance();

    final persistentPeople = people.where(
      (person) =>
          person.sourceType != SourceType.friendRequestIncoming &&
          person.sourceType != SourceType.friendRequestPending,
    );

    final encoded = jsonEncode(
      persistentPeople.map((person) => person.toMap()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  List<Person> _ensureUniqueMyPublicId(List<Person> source) {
    return source.map((person) {
      if (person.id != 'me') return person;

      final current = person.publicId.trim();

      final isDefaultPublicId =
          current.isEmpty ||
          current == 'me' ||
          current == 'me000001' ||
          current == 'demo_me' ||
          current == 'my_profile';

      if (!isDefaultPublicId) return person;

      return person.copyWith(publicId: 'user_${userId.replaceAll('-', '')}');
    }).toList();
  }
}
