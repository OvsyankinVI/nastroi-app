import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteFriendRequest {
  final String id;
  final String status;
  final bool isIncoming;
  final String otherUserId;
  final String otherPersonId;
  final String otherPublicId;
  final String otherName;

  const RemoteFriendRequest({
    required this.id,
    required this.status,
    required this.isIncoming,
    required this.otherUserId,
    required this.otherPersonId,
    required this.otherPublicId,
    required this.otherName,
  });
}

class RemoteFriendRequestsService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> createRequestByPublicId(String publicId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final myPerson = await _client
        .from('people')
        .select('id, owner_user_id')
        .eq('owner_user_id', user.id)
        .eq('relation_type', 'me')
        .maybeSingle();

    if (myPerson == null) {
      throw Exception('Твой профиль не найден');
    }

    final targetPerson = await _client
        .from('people')
        .select('id, owner_user_id')
        .eq('public_id', publicId)
        .eq('is_public', true)
        .maybeSingle();

    if (targetPerson == null) {
      throw Exception('Профиль не найден');
    }

    if (targetPerson['owner_user_id'] == user.id) {
      throw Exception('Нельзя добавить самого себя');
    }

    await _client.from('friend_requests').insert({
      'requester_user_id': user.id,
      'requester_person_id': myPerson['id'],
      'target_user_id': targetPerson['owner_user_id'],
      'target_person_id': targetPerson['id'],
      'status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<RemoteFriendRequest>> loadMyRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('friend_requests')
        .select('''
          id,
          status,
          requester_user_id,
          target_user_id,
          requester:requester_person_id(id, public_id, name),
          target:target_person_id(id, public_id, name)
        ''')
        .eq('status', 'pending')
        .or('requester_user_id.eq.${user.id},target_user_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return rows.map<RemoteFriendRequest>((row) {
      final isIncoming = row['target_user_id'] == user.id;
      final person = isIncoming ? row['requester'] : row['target'];
      final otherUserId = isIncoming
          ? row['requester_user_id']
          : row['target_user_id'];

      return RemoteFriendRequest(
        id: row['id'],
        status: row['status'],
        isIncoming: isIncoming,
        otherUserId: otherUserId,
        otherPersonId: person['id'],
        otherPublicId: person['public_id'],
        otherName: person['name'],
      );
    }).toList();
  }

  static Future<void> acceptRequest(String requestId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final request = await _client
        .from('friend_requests')
        .select()
        .eq('id', requestId)
        .eq('target_user_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();

    if (request == null) {
      throw Exception('Заявка не найдена');
    }

    await _client.rpc(
      'accept_friend_request',
      params: {'p_request_id': requestId},
    );

    await _client
        .from('friend_requests')
        .update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  static Future<void> declineRequest(String requestId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('friend_requests')
        .update({
          'status': 'declined',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('target_user_id', user.id)
        .eq('status', 'pending');
  }

  static Future<void> cancelRequest(String requestId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('friend_requests')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('requester_user_id', user.id)
        .eq('status', 'pending');
  }
}
