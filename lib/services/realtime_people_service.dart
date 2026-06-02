import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimePeopleService {
  static final _client = Supabase.instance.client;

  static RealtimeChannel subscribeToPeople({
    required void Function(String publicId) onPersonChanged,
  }) {
    final channel = _client.channel('people_updates');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'people',
          callback: (payload) {
            final publicId = payload.newRecord['public_id']?.toString();
            if (publicId == null) return;
            onPersonChanged(publicId);
          },
        )
        .subscribe();

    return channel;
  }

  static RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function() onRequestsChanged,
  }) {
    final channel = _client.channel('friend_requests_updates_$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) {
            final oldRecord = payload.oldRecord;
            final newRecord = payload.newRecord;

            final requesterUserId =
                newRecord['requester_user_id']?.toString() ??
                oldRecord['requester_user_id']?.toString();

            final targetUserId =
                newRecord['target_user_id']?.toString() ??
                oldRecord['target_user_id']?.toString();

            if (requesterUserId == userId || targetUserId == userId) {
              onRequestsChanged();
            }
          },
        )
        .subscribe();

    return channel;
  }

  static RealtimeChannel subscribeToFriendLinks({
    required String userId,
    required void Function() onFriendLinksChanged,
  }) {
    final channel = _client.channel('friend_links_updates_$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_links',
          callback: (payload) {
            final oldRecord = payload.oldRecord;
            final newRecord = payload.newRecord;

            final ownerUserId =
                newRecord['owner_user_id']?.toString() ??
                oldRecord['owner_user_id']?.toString();

            if (ownerUserId == userId) {
              onFriendLinksChanged();
            }
          },
        )
        .subscribe();

    return channel;
  }

  static void dispose(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}