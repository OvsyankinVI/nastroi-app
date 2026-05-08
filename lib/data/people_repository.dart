import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';
import 'mock_people.dart';

class PeopleRepository {
  static const _storageKey = 'people_storage_v1';

  Future<List<Person>> loadPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored == null || stored.isEmpty) {
      return List<Person>.from(mockPeople);
    }

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      return decoded
          .map((item) => Person.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List<Person>.from(mockPeople);
    }
  }

  Future<void> savePeople(List<Person> people) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      people.map((p) => p.toMap()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }
}