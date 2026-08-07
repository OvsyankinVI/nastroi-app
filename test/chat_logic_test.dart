import 'package:flutter_test/flutter_test.dart';
import 'package:nastroi_app/models/chat.dart';
import 'package:nastroi_app/models/person.dart';
import 'package:nastroi_app/services/chat_service.dart';

void main() {
  Person friend(String id, String name) => Person(
    id: id,
    publicId: id,
    remoteUserId: '00000000-0000-4000-8000-${id.padLeft(12, '0')}',
    name: name,
    gender: GenderType.male,
    avatarVariant: 0,
    mood: MoodType.calm,
    helpfulActions: const [],
    avoidActions: const [],
    sourceType: SourceType.imported,
  );

  ChatThread thread({
    required String friendId,
    required DateTime updatedAt,
    String? message,
    int unread = 0,
  }) => ChatThread(
    id: 'thread_$friendId',
    otherUserId: 'auth_$friendId',
    otherPublicId: friendId,
    otherName: friendId,
    otherGender: 'male',
    otherAvatarVariant: 0,
    otherMood: 'calm',
    updatedAt: updatedAt,
    lastMessageText: message,
    unreadCount: unread,
  );

  test('message validation rejects blank and oversized text', () {
    expect(validateChatMessage('   '), isNotNull);
    expect(validateChatMessage(List.filled(4001, 'a').join()), isNotNull);
    expect(validateChatMessage('Привет 👋'), isNull);
  });

  test('messages are sorted oldest first', () {
    final newer = ChatMessage(
      id: '2',
      threadId: 't',
      senderId: 'b',
      text: 'new',
      createdAt: DateTime(2026, 2),
    );
    final older = ChatMessage(
      id: '1',
      threadId: 't',
      senderId: 'a',
      text: 'old',
      createdAt: DateTime(2026, 1),
    );
    expect(sortMessages([newer, older]).map((item) => item.id), ['1', '2']);
  });

  test('request placeholders are not eligible for chat', () {
    const request = Person(
      id: 'request_1',
      publicId: 'user_x',
      name: 'Request',
      gender: GenderType.male,
      avatarVariant: 0,
      mood: MoodType.calm,
      helpfulActions: [],
      avoidActions: [],
      sourceType: SourceType.friendRequestIncoming,
    );
    expect(request.sourceType == SourceType.imported, isFalse);
  });

  test('three remote friends without threads produce three empty items', () {
    final items = mergeChatConversations([
      friend('a', 'Аня'),
      friend('m', 'Мама'),
      friend('v', 'Влад'),
    ], const []);
    expect(items, hasLength(3));
    expect(items.every((item) => !item.hasThread), isTrue);
    expect(items.every((item) => item.unreadCount == 0), isTrue);
  });

  test('friend merges with existing thread and message preview', () {
    final existing = thread(
      friendId: 'a',
      updatedAt: DateTime(2026, 8, 7),
      message: 'До встречи!',
      unread: 2,
    );
    final item = mergeChatConversations(
      [friend('a', 'Аня')],
      [existing],
    ).single;
    expect(item.threadId, existing.id);
    expect(item.lastMessage, 'До встречи!');
    expect(item.unreadCount, 2);
  });

  test('active conversations precede alphabetical empty friends', () {
    final items = mergeChatConversations(
      [friend('z', 'Зоя'), friend('b', 'Борис'), friend('a', 'Аня')],
      [
        thread(
          friendId: 'z',
          updatedAt: DateTime(2026, 8, 7, 18),
          message: 'Новое',
        ),
        thread(
          friendId: 'b',
          updatedAt: DateTime(2026, 8, 7, 17),
          message: 'Старое',
        ),
      ],
    );
    expect(items.map((item) => item.friend.name), ['Зоя', 'Борис', 'Аня']);
  });

  test('local-only and request people are excluded from chat list', () {
    final local = friend(
      'local',
      'Local',
    ).copyWith(sourceType: SourceType.local);
    final request = friend(
      'request',
      'Request',
    ).copyWith(sourceType: SourceType.friendRequestPending);
    expect(mergeChatConversations([local, request], const []), isEmpty);
  });

  test('date labels and day boundaries are calendar-aware', () {
    final now = DateTime(2026, 8, 7, 20);
    expect(chatDateLabel(DateTime(2026, 8, 7, 1), now), 'Сегодня');
    expect(chatDateLabel(DateTime(2026, 8, 6, 23), now), 'Вчера');
    expect(chatDateLabel(DateTime(2026, 8, 5), now), '5 августа');
    expect(chatDateLabel(DateTime(2025, 12, 31), now), '31 декабря 2025');
    expect(
      isDifferentCalendarDay(DateTime(2026, 8, 7, 1), DateTime(2026, 8, 7, 23)),
      isFalse,
    );
    expect(
      isDifferentCalendarDay(DateTime(2026, 8, 6, 23), DateTime(2026, 8, 7, 1)),
      isTrue,
    );
  });

  test('reply, edit and deleted presentation are represented by model', () {
    final original = ChatMessage(
      id: 'original',
      threadId: 'thread',
      senderId: 'friend',
      text: 'Исходный текст',
      createdAt: DateTime(2026, 8, 7),
    );
    final reply = ChatMessage(
      id: 'reply',
      threadId: 'thread',
      senderId: 'me',
      text: 'Ответ',
      createdAt: DateTime(2026, 8, 7, 1),
      replyToMessageId: original.id,
    );
    expect(reply.replyToMessageId, original.id);
    expect(canModifyChatMessage(reply, 'me'), isTrue);
    expect(canModifyChatMessage(original, 'me'), isFalse);

    final edited = reply.copyWith(
      text: 'Исправленный ответ',
      editedAt: DateTime(2026, 8, 7, 2),
    );
    expect(edited.editedAt, isNotNull);
    expect(edited.visibleText, 'Исправленный ответ');

    final deleted = edited.copyWith(deletedAt: DateTime(2026, 8, 7, 3));
    expect(deleted.visibleText, 'Сообщение удалено');
    expect(deleted.text, 'Исправленный ответ');
    expect(canModifyChatMessage(deleted, 'me'), isFalse);
  });

  test('realtime replaces optimistic message without a duplicate', () {
    final pending = ChatMessage(
      id: 'same-client-id',
      threadId: 'thread',
      senderId: 'me',
      text: 'Привет',
      createdAt: DateTime(2026, 8, 7),
      isPending: true,
    );
    final confirmed = ChatMessage(
      id: pending.id,
      threadId: 'thread',
      senderId: 'me',
      text: 'Привет',
      createdAt: pending.createdAt,
    );
    final messages = [pending];
    mergeRealtimeMessage(messages, confirmed);
    expect(messages, hasLength(1));
    expect(messages.single.isPending, isFalse);

    final updated = confirmed.copyWith(
      text: 'Изменено',
      editedAt: DateTime(2026, 8, 7, 1),
    );
    mergeRealtimeMessage(messages, updated);
    expect(messages, hasLength(1));
    expect(messages.single.text, 'Изменено');
  });

  test('composer modes are mutually exclusive states', () {
    expect(ChatComposerMode.values, [
      ChatComposerMode.normal,
      ChatComposerMode.reply,
      ChatComposerMode.edit,
    ]);
  });

  test('remote auth UUID is resolved centrally', () {
    final remote = friend('1', 'Аня');
    expect(resolveFriendUserId(remote), remote.remoteUserId);
    expect(
      () => resolveFriendUserId(remote.copyWith(sourceType: SourceType.local)),
      throwsStateError,
    );
  });

  test('normal insert payload omits unsupported nullable action fields', () {
    final payload = buildMessageInsertPayload(
      messageId: 'message',
      threadId: 'thread',
      senderId: 'sender',
      text: '  Привет  ',
    );
    expect(payload['text'], 'Привет');
    expect(payload.containsKey('edited_at'), isFalse);
    expect(payload.containsKey('reply_to_message_id'), isFalse);
    expect(payload.containsKey('deleted_at'), isFalse);
  });

  test('reply insert payload contains only a real reply id', () {
    final payload = buildMessageInsertPayload(
      messageId: 'message',
      threadId: 'thread',
      senderId: 'sender',
      text: 'Ответ',
      replyToMessageId: 'original',
    );
    expect(payload['reply_to_message_id'], 'original');
  });
}
