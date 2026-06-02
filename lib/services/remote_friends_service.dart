import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteFriendsService {
  static final SupabaseClient _client = Supabase.instance.client;

static Future<void> removeFriendByPublicId(String publicId) async {
  final user = _client.auth.currentUser;
  if (user == null) return;

  final friendPerson = await _client
      .from('people')
      .select('id')
      .eq('public_id', publicId)
      .maybeSingle();

  if (friendPerson == null) return;

  await _client
      .from('friend_links')
      .delete()
      .eq('owner_user_id', user.id)
      .eq('friend_person_id', friendPerson['id']);
}

  static Future<void> addFriendByPublicId(String publicId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final friendPerson = await _client
        .from('people')
        .select('id, owner_user_id, public_id')
        .eq('public_id', publicId)
        .eq('is_public', true)
        .maybeSingle();

    if (friendPerson == null) {
      throw Exception('Профиль не найден');
    }

    if (friendPerson['owner_user_id'] == user.id) {
      throw Exception('Нельзя добавить самого себя');
    }

    await _client.from('friend_links').upsert(
      {
        'owner_user_id': user.id,
        'friend_user_id': friendPerson['owner_user_id'],
        'friend_person_id': friendPerson['id'],
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'owner_user_id,friend_person_id',
    );
  }
}