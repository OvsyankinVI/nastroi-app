import 'person.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.otherUserId,
    required this.otherPublicId,
    required this.otherName,
    required this.otherGender,
    required this.otherAvatarVariant,
    required this.otherMood,
    required this.updatedAt,
    this.lastMessageText,
    this.unreadCount = 0,
  });

  final String id;
  final String otherUserId;
  final String otherPublicId;
  final String otherName;
  final String otherGender;
  final int otherAvatarVariant;
  final String otherMood;
  final DateTime updatedAt;
  final String? lastMessageText;
  final int unreadCount;

  factory ChatThread.fromMap(Map<String, dynamic> map) => ChatThread(
    id: map['thread_id'].toString(),
    otherUserId: map['other_user_id'].toString(),
    otherPublicId: map['other_public_id']?.toString() ?? '',
    otherName: map['other_name']?.toString() ?? 'Пользователь',
    otherGender: map['other_gender']?.toString() ?? 'male',
    otherAvatarVariant: map['other_avatar_variant'] as int? ?? 0,
    otherMood: map['other_mood']?.toString() ?? 'calm',
    updatedAt:
        DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    lastMessageText: map['last_message_text']?.toString(),
    unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
  );
}

class ChatConversationItem {
  const ChatConversationItem({required this.friend, this.thread});

  final Person friend;
  final ChatThread? thread;

  String? get threadId => thread?.id;
  String? get lastMessage => thread?.lastMessageText;
  DateTime? get lastMessageAt => lastMessage == null ? null : thread?.updatedAt;
  int get unreadCount => thread?.unreadCount ?? 0;
  bool get hasThread => thread != null;
}

bool isRemoteChatFriend(Person person) =>
    person.sourceType == SourceType.imported &&
    person.publicId.isNotEmpty &&
    person.remoteUserId != null;

String resolveFriendUserId(Person friend) {
  if (!isRemoteChatFriend(friend)) {
    throw StateError('Remote chat user is unavailable');
  }
  return friend.remoteUserId!;
}

List<ChatConversationItem> mergeChatConversations(
  Iterable<Person> friends,
  Iterable<ChatThread> threads,
) {
  final threadByPublicId = <String, ChatThread>{
    for (final thread in threads) thread.otherPublicId: thread,
  };
  final result = friends
      .where(isRemoteChatFriend)
      .map(
        (friend) => ChatConversationItem(
          friend: friend,
          thread: threadByPublicId[friend.publicId],
        ),
      )
      .toList();
  result.sort((a, b) {
    final aDate = a.lastMessageAt;
    final bDate = b.lastMessageAt;
    if (aDate != null && bDate != null) return bDate.compareTo(aDate);
    if (aDate != null) return -1;
    if (bDate != null) return 1;
    return a.friend.name.toLowerCase().compareTo(b.friend.name.toLowerCase());
  });
  return result;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readAt,
    this.editedAt,
    this.replyToMessageId,
    this.deletedAt,
    this.isPending = false,
    this.hasError = false,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final String? replyToMessageId;
  final DateTime? deletedAt;
  final bool isPending;
  final bool hasError;

  bool get isDeleted => deletedAt != null;
  String get visibleText => isDeleted ? 'Сообщение удалено' : text;

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? text,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? editedAt,
    String? replyToMessageId,
    DateTime? deletedAt,
    bool? isPending,
    bool? hasError,
  }) => ChatMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    senderId: senderId ?? this.senderId,
    text: text ?? this.text,
    createdAt: createdAt ?? this.createdAt,
    readAt: readAt ?? this.readAt,
    editedAt: editedAt ?? this.editedAt,
    replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    deletedAt: deletedAt ?? this.deletedAt,
    isPending: isPending ?? this.isPending,
    hasError: hasError ?? this.hasError,
  );

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'].toString(),
    threadId: map['thread_id'].toString(),
    senderId: map['sender_id'].toString(),
    text: map['text'].toString(),
    createdAt: DateTime.parse(map['created_at'].toString()),
    readAt: DateTime.tryParse(map['read_at']?.toString() ?? ''),
    editedAt: DateTime.tryParse(map['edited_at']?.toString() ?? ''),
    replyToMessageId: map['reply_to_message_id']?.toString(),
    deletedAt: DateTime.tryParse(map['deleted_at']?.toString() ?? ''),
  );
}

enum ChatComposerMode { normal, reply, edit }

bool canModifyChatMessage(ChatMessage message, String currentUserId) =>
    !message.isDeleted && message.senderId == currentUserId;

void mergeRealtimeMessage(List<ChatMessage> messages, ChatMessage incoming) {
  final index = messages.indexWhere((message) => message.id == incoming.id);
  if (index == -1) {
    messages.add(incoming);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  } else {
    messages[index] = incoming;
  }
}

bool isDifferentCalendarDay(DateTime previous, DateTime current) {
  final a = previous.toLocal();
  final b = current.toLocal();
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

String chatDateLabel(DateTime value, DateTime now) {
  final date = DateTime(
    value.toLocal().year,
    value.toLocal().month,
    value.toLocal().day,
  );
  final today = DateTime(
    now.toLocal().year,
    now.toLocal().month,
    now.toLocal().day,
  );
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Сегодня';
  if (difference == 1) return 'Вчера';
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final year = date.year == today.year ? '' : ' ${date.year}';
  return '${date.day} ${months[date.month - 1]}$year';
}

String? validateChatMessage(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 'Напиши сообщение';
  if (text.length > 4000) return 'Сообщение длиннее 4000 символов';
  return null;
}

List<ChatMessage> sortMessages(Iterable<ChatMessage> messages) {
  final result = messages.toList();
  result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return result;
}
