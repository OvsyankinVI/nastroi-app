import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_colors.dart';
import '../models/chat.dart';
import '../models/person.dart';
import '../services/chat_service.dart';
import '../services/realtime_people_service.dart';
import '../services/remote_people_service.dart';
import '../widgets/person_avatar.dart';
import 'chat_screen.dart';

final ValueNotifier<int> totalChatUnread = ValueNotifier<int>(0);
final ValueNotifier<String?> pendingChatThreadId = ValueNotifier<String?>(null);

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.initialFriends,
    required this.onOpenPeople,
  });

  final List<Person> initialFriends;
  final VoidCallback onOpenPeople;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final ChatService _service = ChatService();
  late List<Person> _friends;
  List<ChatThread> _threads = [];
  bool _loadingMetadata = true;
  String? _error;
  bool _metadataUnavailable = false;
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _friendChannel;
  Timer? _debounce;

  List<ChatConversationItem> get _items =>
      mergeChatConversations(_friends, _threads);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _friends = widget.initialFriends.where(isRemoteChatFriend).toList();
    _load();
    _messageChannel = _service.subscribeToThreads(_scheduleLoad);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _friendChannel = RealtimePeopleService.subscribeToFriendLinks(
        userId: userId,
        onFriendLinksChanged: _scheduleLoad,
      );
    }
    pendingChatThreadId.addListener(_handlePendingThread);
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialFriends.where(isRemoteChatFriend).toList();
    if (_publicIds(next) != _publicIds(_friends)) {
      setState(() => _friends = next);
    }
  }

  String _publicIds(List<Person> values) {
    final ids = values.map((person) => person.publicId).toList()..sort();
    return ids.join('|');
  }

  @override
  void dispose() {
    pendingChatThreadId.removeListener(_handlePendingThread);
    _debounce?.cancel();
    _service.disposeChannel(_messageChannel);
    if (_friendChannel != null) RealtimePeopleService.dispose(_friendChannel!);
    super.dispose();
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _loadFriendsSafely(),
      _loadThreadsSafely(),
    ]);
    if (!mounted) return;
    final friends = results[0] as List<Person>?;
    final threads = results[1] as List<ChatThread>?;
    setState(() {
      if (friends != null) _friends = friends;
      if (threads != null) _threads = threads;
      _loadingMetadata = false;
      _metadataUnavailable = threads == null;
      _error = friends == null && _friends.isEmpty
          ? 'Не удалось загрузить друзей'
          : null;
    });
    totalChatUnread.value = _items.fold(
      0,
      (sum, item) => sum + item.unreadCount,
    );
    _handlePendingThread();
  }

  Future<List<Person>?> _loadFriendsSafely() async {
    try {
      return await RemotePeopleService.loadMyRemoteFriends();
    } catch (error, stack) {
      _service.debugLogOperationError('friends_load', error);
      unawaited(FirebaseCrashlytics.instance.recordError(error, stack));
      return null;
    }
  }

  Future<List<ChatThread>?> _loadThreadsSafely() async {
    try {
      return await _service.loadThreads();
    } catch (error, stack) {
      _service.debugLogOperationError('threads_load', error);
      unawaited(FirebaseCrashlytics.instance.recordError(error, stack));
      return null;
    }
  }

  void _handlePendingThread() {
    final id = pendingChatThreadId.value;
    if (!mounted || id == null) return;
    final matches = _items.where((item) => item.threadId == id);
    if (matches.isEmpty) return;
    pendingChatThreadId.value = null;
    _open(matches.first);
  }

  Future<void> _open(ChatConversationItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(friend: item.friend, initialThread: item.thread),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _items;
    if (items.isEmpty && _loadingMetadata) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (items.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const PageStorageKey('chat_list'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
        itemCount: items.length + (_metadataUnavailable ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, index) {
          if (index == items.length) {
            return CupertinoButton(
              onPressed: _load,
              child: Text(
                'История временно недоступна · Обновить',
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 13,
                ),
              ),
            );
          }
          return _conversationRow(items[index]);
        },
      ),
    );
  }

  Widget _conversationRow(ChatConversationItem item) {
    final person = item.friend;
    return ListTile(
      minTileHeight: 68,
      leading: PersonAvatar(
        mood: person.mood,
        gender: person.gender,
        avatarVariant: person.avatarVariant,
        size: 52,
      ),
      title: Text(
        person.name,
        style: TextStyle(
          fontWeight: item.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        item.lastMessage ?? 'Напишите сообщение',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: item.lastMessage == null
            ? TextStyle(color: AppColors.mutedText(context))
            : null,
      ),
      trailing: item.lastMessageAt == null && item.unreadCount == 0
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.lastMessageAt case final value?)
                  Text(
                    _time(value),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText(context),
                    ),
                  ),
                if (item.unreadCount > 0) _unreadBadge(item.unreadCount),
              ],
            ),
      onTap: () => _open(item),
    );
  }

  Widget _unreadBadge(int count) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary,
        fontSize: 11,
      ),
    ),
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 58,
            color: AppColors.mutedText(context),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Пока некому написать',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error == null
                ? 'Добавьте друзей, чтобы начать общение.'
                : 'Проверьте соединение и попробуйте снова.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _error == null ? widget.onOpenPeople : _load,
            child: Text(_error == null ? 'Открыть людей' : 'Повторить'),
          ),
        ],
      ),
    ),
  );

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
