import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_colors.dart';
import '../models/chat.dart';
import '../models/person.dart';
import '../services/chat_service.dart';
import '../widgets/person_avatar.dart';

final ValueNotifier<String?> activeChatThreadId = ValueNotifier<String?>(null);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.friend, this.initialThread});

  final Person friend;
  final ChatThread? initialThread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _service = ChatService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  ChatThread? _thread;
  RealtimeChannel? _channel;
  ChatComposerMode _composerMode = ChatComposerMode.normal;
  ChatMessage? _replyingTo;
  ChatMessage? _editing;
  String _draftBeforeEdit = '';
  bool _loading = false;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _thread = widget.initialThread;
    _scrollController.addListener(_handleScroll);
    if (_thread != null) _attachThread(_thread!, loadMessages: true);
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'chat_opened'));
  }

  @override
  void dispose() {
    if (activeChatThreadId.value == _thread?.id) {
      activeChatThreadId.value = null;
    }
    _service.disposeChannel(_channel);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final thread = _thread;
    if (thread == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _service.loadMessages(thread.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
        _hasMore = messages.length == 40;
      });
      await _service.markThreadRead(thread.id);
      _scrollToBottom();
    } catch (error, stack) {
      _recordError('load', error, stack);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить сообщения';
        });
      }
    }
  }

  void _attachThread(ChatThread thread, {required bool loadMessages}) {
    _thread = thread;
    activeChatThreadId.value = thread.id;
    _service.disposeChannel(_channel);
    _channel = _service.subscribeToMessages(thread.id, _onRealtimeMessage);
    if (loadMessages) unawaited(_loadInitial());
  }

  Future<void> _handleScroll() async {
    if (!_scrollController.hasClients ||
        _scrollController.position.pixels > 80 ||
        _loadingOlder ||
        !_hasMore ||
        _messages.isEmpty) {
      return;
    }
    final threadId = _thread?.id;
    if (threadId == null) return;
    _loadingOlder = true;
    final previousExtent = _scrollController.position.maxScrollExtent;
    try {
      final older = await _service.loadMessages(
        threadId,
        before: _messages.first.createdAt,
      );
      if (!mounted) return;
      setState(() {
        for (final message in older.reversed) {
          if (!_messages.any((item) => item.id == message.id)) {
            _messages.insert(0, message);
          }
        }
        _hasMore = older.length == 40;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final addedExtent =
              _scrollController.position.maxScrollExtent - previousExtent;
          _scrollController.jumpTo(
            (_scrollController.position.pixels + addedExtent).clamp(
              0,
              _scrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (error, stack) {
      _recordError('pagination', error, stack);
    } finally {
      _loadingOlder = false;
    }
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() => mergeRealtimeMessage(_messages, message));
    final threadId = _thread?.id;
    if (threadId != null && message.senderId != _service.currentUserId) {
      unawaited(_service.markThreadRead(threadId));
    }
    if (!message.isPending) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_composerMode == ChatComposerMode.edit) {
      await _saveEdit();
    } else {
      await _sendNewMessage();
    }
  }

  Future<void> _sendNewMessage() async {
    final validation = validateChatMessage(_controller.text);
    if (validation != null) return;
    final text = _controller.text.trim();
    final messageId = _service.createMessageId();
    final replyId = _replyingTo?.id;
    final optimistic = ChatMessage(
      id: messageId,
      threadId: _thread?.id ?? '',
      senderId: _service.currentUserId,
      text: text,
      createdAt: DateTime.now(),
      replyToMessageId: replyId,
      isPending: true,
    );
    setState(() {
      _sending = true;
      _messages.add(optimistic);
      _controller.clear();
      _cancelComposer(clearInput: false);
    });
    _scrollToBottom();
    try {
      var thread = _thread;
      if (thread == null) {
        thread = await _service.getOrCreateThread(
          resolveFriendUserId(widget.friend),
        );
        if (!mounted) return;
        _attachThread(thread, loadMessages: false);
      }
      final message = await _service.sendMessage(
        thread.id,
        text,
        messageId: messageId,
        replyToMessageId: replyId,
      );
      if (!mounted) return;
      setState(() => mergeRealtimeMessage(_messages, message));
      unawaited(FirebaseAnalytics.instance.logEvent(name: 'message_sent'));
      if (replyId != null) {
        unawaited(FirebaseAnalytics.instance.logEvent(name: 'message_replied'));
      }
    } catch (error, stack) {
      _recordError(
        _thread == null ? 'thread_create' : 'message_insert',
        error,
        stack,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == messageId);
        if (index != -1) {
          _messages[index] = optimistic.copyWith(hasError: true);
        }
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        if (replyId != null) {
          _composerMode = ChatComposerMode.reply;
          _replyingTo = _messageById(replyId);
        }
      });
      _showError('Не удалось отправить сообщение. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveEdit() async {
    final message = _editing;
    if (message == null || _sending) return;
    if (validateChatMessage(_controller.text) != null) return;
    setState(() => _sending = true);
    try {
      final updated = await _service.editMessage(message, _controller.text);
      if (!mounted) return;
      setState(() {
        mergeRealtimeMessage(_messages, updated);
        _cancelComposer(clearInput: true);
      });
      unawaited(FirebaseAnalytics.instance.logEvent(name: 'message_edited'));
    } catch (error, stack) {
      _recordError('message_update', error, stack);
      if (mounted) _showError('Не удалось изменить сообщение.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(ChatMessage message) {
    if (message.isDeleted) return;
    setState(() {
      _composerMode = ChatComposerMode.reply;
      _replyingTo = message;
      _editing = null;
    });
    _focusNode.requestFocus();
  }

  void _startEdit(ChatMessage message) {
    if (!canModifyChatMessage(message, _service.currentUserId)) return;
    setState(() {
      _draftBeforeEdit = _controller.text;
      _composerMode = ChatComposerMode.edit;
      _editing = message;
      _replyingTo = null;
      _controller.text = message.text;
      _controller.selection = TextSelection.collapsed(
        offset: message.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelComposer({bool clearInput = false}) {
    final wasEditing = _composerMode == ChatComposerMode.edit;
    _composerMode = ChatComposerMode.normal;
    _replyingTo = null;
    _editing = null;
    if (clearInput) {
      _controller.text = wasEditing ? _draftBeforeEdit : '';
    }
    _draftBeforeEdit = '';
  }

  Future<void> _delete(ChatMessage message) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Оно будет удалено у всех участников.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final deleted = await _service.deleteMessage(message);
      if (!mounted) return;
      setState(() => mergeRealtimeMessage(_messages, deleted));
      unawaited(FirebaseAnalytics.instance.logEvent(name: 'message_deleted'));
    } catch (error, stack) {
      _recordError('message_delete', error, stack);
      if (mounted) _showError('Не удалось удалить сообщение.');
    }
  }

  Future<void> _showActions(ChatMessage message) async {
    final mine = message.senderId == _service.currentUserId;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          if (message.hasError)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _messages.removeWhere((item) => item.id == message.id);
                  _controller.text = message.text;
                  _controller.selection = TextSelection.collapsed(
                    offset: message.text.length,
                  );
                });
                _focusNode.requestFocus();
              },
              child: const Text('Повторить отправку'),
            ),
          if (!message.isDeleted)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _startReply(message);
              },
              child: const Text('Ответить'),
            ),
          if (mine && !message.isDeleted)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _startEdit(message);
              },
              child: const Text('Изменить'),
            ),
          if (!message.isDeleted)
            CupertinoActionSheetAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(sheetContext);
              },
              child: const Text('Копировать'),
            ),
          if (mine && !message.isDeleted)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                unawaited(_delete(message));
              },
              child: const Text('Удалить'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Отмена'),
        ),
      ),
    );
  }

  void _recordError(String operation, Object error, StackTrace stack) {
    _service.debugLogOperationError(operation, error);
    unawaited(FirebaseCrashlytics.instance.recordError(error, stack));
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  ChatMessage? _messageById(String? id) {
    if (id == null) return null;
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  void _scrollToMessage(String id) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index == -1 || !_scrollController.hasClients) return;
    final target =
        index / _messages.length * _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background(context),
    appBar: AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          PersonAvatar(
            mood: widget.friend.mood,
            gender: widget.friend.gender,
            avatarVariant: widget.friend.avatarVariant,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.friend.name, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(child: _messageArea()),
            _composer(),
          ],
        ),
      ),
    ),
  );

  Widget _messageArea() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            CupertinoButton(
              onPressed: _loadInitial,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) return _EmptyConversation(friend: widget.friend);
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, rawIndex) {
        if (_loadingOlder && rawIndex == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CupertinoActivityIndicator(),
          );
        }
        final index = rawIndex - (_loadingOlder ? 1 : 0);
        final message = _messages[index];
        final showDate =
            index == 0 ||
            isDifferentCalendarDay(
              _messages[index - 1].createdAt,
              message.createdAt,
            );
        final reply = _messageById(message.replyToMessageId);
        return Column(
          children: [
            if (showDate) _DateSeparator(date: message.createdAt),
            Dismissible(
              key: ValueKey('swipe_${message.id}'),
              direction: message.isDeleted
                  ? DismissDirection.none
                  : DismissDirection.startToEnd,
              dismissThresholds: const {DismissDirection.startToEnd: 0.28},
              confirmDismiss: (_) async {
                HapticFeedback.mediumImpact();
                _startReply(message);
                return false;
              },
              background: const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 18),
                  child: Icon(CupertinoIcons.reply),
                ),
              ),
              child: GestureDetector(
                onLongPress: () => _showActions(message),
                child: _MessageBubble(
                  message: message,
                  quotedMessage: reply,
                  quotedAuthor: reply?.senderId == _service.currentUserId
                      ? 'Вы'
                      : widget.friend.name,
                  mine: message.senderId == _service.currentUserId,
                  onQuoteTap: message.replyToMessageId == null
                      ? null
                      : () => _scrollToMessage(message.replyToMessageId!),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _composer() => Container(
    color: AppColors.surface(context).withValues(alpha: 0.94),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_composerMode != ChatComposerMode.normal) _composerPanel(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending || _controller.text.trim().isEmpty
                    ? null
                    : _submit,
                icon: _sending
                    ? const CupertinoActivityIndicator()
                    : Icon(
                        _composerMode == ChatComposerMode.edit
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.arrow_up_circle_fill,
                      ),
                iconSize: 34,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _composerPanel() {
    final isEdit = _composerMode == ChatComposerMode.edit;
    final target = isEdit ? _editing : _replyingTo;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.chip(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit
                      ? 'Редактирование сообщения'
                      : 'Ответ на ${target?.senderId == _service.currentUserId ? 'Вы' : widget.friend.name}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  target?.visibleText ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                setState(() => _cancelComposer(clearInput: isEdit)),
            icon: const Icon(CupertinoIcons.xmark_circle_fill),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.friend});
  final Person friend;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonAvatar(
            mood: friend.mood,
            gender: friend.gender,
            avatarVariant: friend.avatarVariant,
            size: 76,
          ),
          const SizedBox(height: 16),
          Text(
            'Начните общение',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Напишите первое сообщение для ${friend.name}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ],
      ),
    ),
  );
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.chip(context).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        chatDateLabel(date, DateTime.now()),
        style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.quotedMessage,
    required this.quotedAuthor,
    required this.mine,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final ChatMessage? quotedMessage;
  final String quotedAuthor;
  final bool mine;
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final foreground = mine
        ? Theme.of(context).colorScheme.onPrimary
        : AppColors.primaryText(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedOpacity(
        opacity: message.isPending ? 0.68 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 6),
          decoration: BoxDecoration(
            color: mine
                ? Theme.of(context).colorScheme.primary
                : AppColors.surface(context),
            border: message.hasError
                ? Border.all(color: CupertinoColors.systemRed, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyToMessageId != null)
                GestureDetector(
                  onTap: onQuoteTap,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.fromLTRB(9, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.1),
                      border: Border(
                        left: BorderSide(
                          color: foreground.withValues(alpha: 0.7),
                          width: 3,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotedAuthor,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          quotedMessage?.visibleText ??
                              'Исходное сообщение не загружено',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SelectableText(
                message.visibleText,
                style: TextStyle(
                  color: message.isDeleted
                      ? foreground.withValues(alpha: 0.7)
                      : foreground,
                  fontSize: 16,
                  fontStyle: message.isDeleted
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${message.editedAt == null ? '' : 'изменено · '}${_time(message.createdAt)}${message.isPending ? ' · отправка' : ''}${message.hasError ? ' · ошибка' : ''}',
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.65),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
