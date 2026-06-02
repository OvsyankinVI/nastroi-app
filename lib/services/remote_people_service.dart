import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/person.dart';

class RemotePeopleService {
  static final SupabaseClient _client = Supabase.instance.client;

static Future<Person?> loadMyRemotePerson() async {
  final user = _client.auth.currentUser;
  if (user == null) return null;

  final response = await _client
      .from('people')
      .select()
      .eq('owner_user_id', user.id)
      .eq('relation_type', 'me')
      .maybeSingle();

  if (response == null) return null;

  return _personFromRemoteMap(
    response,
    id: 'me',
    sourceType: 'local',
    relationType: 'me',
  );
}

static Person _personFromRemoteMap(
  Map<String, dynamic> data, {
  required String id,
  required String sourceType,
  required String relationType,
}) {
  return Person.fromMap({
    'id': id,
    'publicId': data['public_id'],
    'name': data['name'],
    'gender': data['gender'],
    'avatarVariant': data['avatar_variant'],
    'mood': data['mood'],
    'relationType': relationType,
    'customRelationLabel': data['custom_relation_label'],
    'helpfulActions': List<String>.from(data['helpful_actions'] ?? []),
    'avoidActions': List<String>.from(data['avoid_actions'] ?? []),
    'sourceType': sourceType,
    'lifeCycleEnabled': data['life_cycle_enabled'] ?? false,
    'cycleStages': data['cycle_stages'] ?? [],
    'cycleStartDateIso': data['cycle_start_date_iso'],
    'manualMoodOverride': data['manual_mood_override'],
    'manualMoodOverrideDateIso': data['manual_mood_override_date_iso'],
  });
}

  static Future<List<Person>> loadMyRemoteFriends() async {
  final user = _client.auth.currentUser;
  if (user == null) return [];

  final rows = await _client
      .from('friend_links')
      .select('people:friend_person_id(*)')
      .eq('owner_user_id', user.id)
      .eq('status', 'accepted');

  return rows
      .map<Person?>((row) {
        final personData = row['people'];
        if (personData == null) return null;

        return _personFromRemoteMap(
            Map<String, dynamic>.from(personData),
            id: personData['public_id'],
            sourceType: 'imported',
            relationType: 'other',
        );
      })
      .whereType<Person>()
      .toList();
}

  static Future<void> upsertMyPerson(Person person) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('people').upsert(
      {
        'owner_user_id': user.id,
        'public_id': person.publicId,
        'name': person.name,
        'gender': person.gender.name,
        'avatar_variant': person.avatarVariant,
        'mood': person.mood.name,
        'relation_type': person.relationType.name,
        'custom_relation_label': person.customRelationLabel,
        'helpful_actions': person.helpfulActions,
        'avoid_actions': person.avoidActions,
        'life_cycle_enabled': person.lifeCycleEnabled,
        'cycle_stages': person.cycleStages.map((e) => e.toMap()).toList(),
        'cycle_start_date_iso': person.cycleStartDateIso,
        'manual_mood_override': person.manualMoodOverride?.name,
        'manual_mood_override_date_iso': person.manualMoodOverrideDateIso,
        'is_public': true,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'public_id',
    );
  }

  static Future<Person?> findPublicPersonByPublicId(String publicId) async {
    final response = await _client
        .from('people')
        .select()
        .eq('public_id', publicId)
        .eq('is_public', true)
        .maybeSingle();

    if (response == null) return null;

    return _personFromRemoteMap(
        Map<String, dynamic>.from(response),
        id: response['public_id'],
        sourceType: 'imported',
        relationType: response['relation_type'] ?? 'other',
    );
  }
}