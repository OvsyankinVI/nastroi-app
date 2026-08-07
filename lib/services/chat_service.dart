import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';

Map<String, dynamic> buildMessageInsertPayload({
  required String messageId,
  required String threadId,
  required String senderId,
  required String text,
  String? replyToMessageId,
}) {
  final payload = <String, dynamic>{
    'id': messageId,
    'thread_id': threadId,
    'sender_id': senderId,
    'text': text.trim(),
  };
  if (replyToMessageId != null) {
    payload['reply_to_message_id'] = replyToMessageId;
  }
  return payload;
}

class ChatService {
  ChatService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const networkTimeout = Duration(seconds: 15);
  String get currentUserId => _client.auth.currentUser!.id;

  Future<List<ChatThread>> loadThreads() async {
    final rows = await _client.rpc('list_chat_threads').timeout(networkTimeout);
    return (rows as List)
        .map((row) => ChatThread.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<ChatThread> getOrCreateThread(String friendUserId) async {
    try {
      final row = await _client
          .rpc(
            'get_or_create_direct_thread',
            params: {'p_friend_user_id': friendUserId},
          )
          .single()
          .timeout(networkTimeout);
      return ChatThread.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      debugLogOperationError('get_or_create_thread', error);
      rethrow;
    }
  }

  Future<List<ChatMessage>> loadMessages(
    String threadId, {
    DateTime? before,
    int limit = 40,
  }) async {
    var query = _client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(networkTimeout);
    return sortMessages(
      rows.map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row))),
    );
  }

  String createMessageId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<ChatMessage> sendMessage(
    String threadId,
    String rawText, {
    required String messageId,
    String? replyToMessageId,
  }) async {
    final error = validateChatMessage(rawText);
    if (error != null) throw FormatException(error);
    final payload = buildMessageInsertPayload(
      messageId: messageId,
      threadId: threadId,
      senderId: currentUserId,
      text: rawText,
      replyToMessageId: replyToMessageId,
    );
    final row = await _client
        .from('chat_messages')
        .insert(payload)
        .select()
        .single()
        .timeout(networkTimeout);
    return ChatMessage.fromMap(row);
  }

  Future<ChatMessage> editMessage(ChatMessage message, String rawText) async {
    final error = validateChatMessage(rawText);
    if (error != null) throw FormatException(error);
    if (!canModifyChatMessage(message, currentUserId)) {
      throw StateError('Message cannot be edited');
    }
    final row = await _client
        .from('chat_messages')
        .update({
          'text': rawText.trim(),
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', message.id)
        .eq('sender_id', currentUserId)
        .select()
        .single()
        .timeout(networkTimeout);
    return ChatMessage.fromMap(row);
  }

  Future<ChatMessage> deleteMessage(ChatMessage message) async {
    if (!canModifyChatMessage(message, currentUserId)) {
      throw StateError('Message cannot be deleted');
    }
    final row = await _client
        .from('chat_messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', message.id)
        .eq('sender_id', currentUserId)
        .select()
        .single()
        .timeout(networkTimeout);
    return ChatMessage.fromMap(row);
  }

  void debugLogOperationError(String operation, Object error) {
    if (!kDebugMode) return;
    if (error is PostgrestException) {
      final details = _safeDiagnostic(error.details?.toString());
      final hint = _safeDiagnostic(error.hint?.toString());
      debugPrint(
        '[Chat] $operation failed: code=${error.code} '
        'message=${error.message} details=$details hint=$hint',
      );
    } else {
      debugPrint('[Chat] $operation failed: ${error.runtimeType}');
    }
  }

  String _safeDiagnostic(String? value) {
    if (value == null || value == 'null') return '-';
    return value.replaceAll(
      RegExp(
        r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b',
      ),
      '<uuid>',
    );
  }

  Future<void> markThreadRead(String threadId) async {
    await _client
        .rpc('mark_chat_thread_read', params: {'p_thread_id': threadId})
        .timeout(networkTimeout);
  }

  RealtimeChannel subscribeToThreads(void Function() onChanged) {
    return _client
        .channel('chat_threads_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToMessages(
    String threadId,
    void Function(ChatMessage) onMessage,
  ) {
    return _client
        .channel('chat_messages_$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onMessage(ChatMessage.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  void disposeChannel(RealtimeChannel? channel) {
    if (channel != null) _client.removeChannel(channel);
  }
}
