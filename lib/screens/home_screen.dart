import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:reorderable_grid/reorderable_grid.dart';

import '../app_colors.dart';
import '../app_theme_controller.dart';
import '../data/people_repository.dart';
import '../models/person.dart';
import '../models/chat.dart';
import '../widgets/person_avatar.dart';

import 'about_screen.dart';
import 'create_person_screen.dart';
import 'import_person_screen.dart';
import 'person_screen.dart';
import 'qr_scanner_screen.dart';

import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../services/watch_sync_service.dart';
import '../services/remote_people_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/remote_friends_service.dart';

import '../services/remote_friend_requests_service.dart';

import '../services/realtime_people_service.dart';
import '../services/auth_service.dart';
import '../utils/person_link.dart';
import '../widgets/glass_tab_bar.dart';

import 'dart:async';
import 'chat_list_screen.dart';
import 'chat_screen.dart';

final ValueNotifier<int> homeTabIndex = ValueNotifier<int>(0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeGridConfig {
  final int columns;
  final double avatarSize;
  final double nameSize;
  final double childAspectRatio;
  final double mainSpacing;
  final double crossSpacing;

  const _HomeGridConfig({
    required this.columns,
    required this.avatarSize,
    required this.nameSize,
    required this.childAspectRatio,
    required this.mainSpacing,
    required this.crossSpacing,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  late final String userId;
  late final PeopleRepository repository;

  String? _requestAvatarAsset(Person person) {
    if (person.sourceType == SourceType.friendRequestIncoming) {
      return 'assets/images/friend_requests/request_incoming.png';
    }

    if (person.sourceType == SourceType.friendRequestPending) {
      return 'assets/images/friend_requests/request_pending.png';
    }

    return null;
  }

  RealtimeChannel? _peopleRealtimeChannel;
  RealtimeChannel? _friendRequestsRealtimeChannel;
  RealtimeChannel? _friendLinksRealtimeChannel;

  List<Person> people = [];
  List<RemoteFriendRequest> _latestFriendRequests = [];
  bool isLoading = true;
  bool _isRefreshing = false;
  String? _loadError;
  int _selectedTab = 0;
  bool isFabMenuOpen = false;
  Timer? _realtimeDebounce;
  String searchQuery = '';
  List<Person> _requestsAsPeople(List<RemoteFriendRequest> requests) {
    return requests.map((request) {
      return Person(
        id: 'request_${request.id}',
        publicId: request.otherPublicId,
        name: request.otherName,
        gender: GenderType.male,
        avatarVariant: 0,
        mood: MoodType.calm,
        helpfulActions: const [],
        avoidActions: const [],
        relationType: RelationType.other,
        sourceType: request.isIncoming
            ? SourceType.friendRequestIncoming
            : SourceType.friendRequestPending,
      );
    }).toList();
  }

  RemoteFriendRequest? _requestForPerson(Person person) {
    final requestId = person.id.replaceFirst('request_', '');

    for (final request in _latestFriendRequests) {
      if (request.id == requestId) return request;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    _selectedTab = homeTabIndex.value;
    homeTabIndex.addListener(_handleExternalTabChange);

    userId = Supabase.instance.client.auth.currentUser!.id;
    repository = PeopleRepository(userId: userId);

    _init();
    _startRealtimeSync();
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_handleExternalTabChange);
    _realtimeDebounce?.cancel();
    final peopleChannel = _peopleRealtimeChannel;
    if (peopleChannel != null) {
      RealtimePeopleService.dispose(peopleChannel);
    }

    final requestsChannel = _friendRequestsRealtimeChannel;
    if (requestsChannel != null) {
      RealtimePeopleService.dispose(requestsChannel);
    }

    final linksChannel = _friendLinksRealtimeChannel;
    if (linksChannel != null) {
      RealtimePeopleService.dispose(linksChannel);
    }

    super.dispose();
  }

  void _handleExternalTabChange() {
    if (mounted && _selectedTab != homeTabIndex.value) {
      setState(() => _selectedTab = homeTabIndex.value);
    }
  }

  void _startRealtimeSync() {
    _peopleRealtimeChannel = RealtimePeopleService.subscribeToPeople(
      onPersonChanged: (publicId) async {
        final hasThisPerson = people.any(
          (person) => person.publicId == publicId,
        );

        if (!hasThisPerson) return;

        _scheduleRealtimeRefresh();
      },
    );

    _friendRequestsRealtimeChannel =
        RealtimePeopleService.subscribeToFriendRequests(
          userId: userId,
          onRequestsChanged: () async {
            _scheduleRealtimeRefresh();
          },
        );

    _friendLinksRealtimeChannel = RealtimePeopleService.subscribeToFriendLinks(
      userId: userId,
      onFriendLinksChanged: () async {
        _scheduleRealtimeRefresh();
      },
    );
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_refreshAll());
    });
  }

  Future<void> _refreshFriendRequests() async {
    final requests = await RemoteFriendRequestsService.loadMyRequests();

    if (!mounted) return;

    setState(() {
      _latestFriendRequests = requests;
      people = [
        ...people.where(
          (person) =>
              person.sourceType != SourceType.friendRequestIncoming &&
              person.sourceType != SourceType.friendRequestPending,
        ),
        ..._requestsAsPeople(requests),
      ];
    });
  }

  Future<void> _init() async {
    try {
      final loaded = _applyDailyStateToPeople(await repository.loadPeople());
      if (!mounted) return;
      setState(() {
        people = loaded;
        isLoading = false;
      });
      await _refreshAll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = 'Не удалось загрузить данные';
      });
    }
  }

  List<Person> _applyDailyStateToPeople(List<Person> source) {
    final today = DateTime.now();
    return source.map((person) => person.applyLifeCycleForDate(today)).toList();
  }

  Future<void> _persist() async {
    await repository.savePeople(people);
    Person? me;
    for (final person in people) {
      if (person.id == 'me') {
        me = person;
        break;
      }
    }

    if (me != null) {
      await RemotePeopleService.upsertMyPerson(me);
    }
    await WidgetService.updatePeople(people);
    await WatchSyncService.updatePeople(people);
    await NotificationService.rescheduleCycleNotifications(people);
  }

  Future<void> _updatePerson(Person updatedPerson) async {
    final normalized = updatedPerson.applyLifeCycleForDate(DateTime.now());
    final index = people.indexWhere((p) => p.id == normalized.id);
    if (index == -1) return;

    setState(() {
      people[index] = normalized;
    });

    await _persist();
  }

  Future<void> _addPerson(Person newPerson) async {
    final normalized = newPerson.applyLifeCycleForDate(DateTime.now());

    setState(() {
      people.add(normalized);
    });

    await _persist();
  }

  Future<List<Person>> _syncFromRemoteOnLaunch(List<Person> localPeople) async {
    localPeople = localPeople
        .where(
          (person) =>
              person.sourceType != SourceType.friendRequestIncoming &&
              person.sourceType != SourceType.friendRequestPending,
        )
        .toList();

    final results = await Future.wait<Object?>([
      RemotePeopleService.loadMyRemotePerson(),
      RemotePeopleService.loadMyRemoteFriends(),
    ]).timeout(const Duration(seconds: 12));
    final remoteMe = results[0] as Person?;
    final remoteFriends = results[1] as List<Person>;

    final localMe = localPeople.where((person) => person.id == 'me').toList();
    final me = remoteMe ?? (localMe.isNotEmpty ? localMe.first : null);

    final localFriends = localPeople
        .where((person) => person.id != 'me')
        .toList();

    final remoteFriendIds = remoteFriends
        .map((person) => person.publicId)
        .toSet();

    final localOnlyFriends = localFriends
        .where((person) => !remoteFriendIds.contains(person.publicId))
        .toList();

    return [?me, ...remoteFriends, ...localOnlyFriends];
  }

  Future<void> _deletePerson(String personId) async {
    final person = people.firstWhere((p) => p.id == personId);

    if (person.sourceType == SourceType.imported) {
      await RemoteFriendsService.removeFriendByPublicId(person.publicId);
    }

    setState(() {
      people.removeWhere((p) => p.id == personId);
    });

    await _persist();
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'friend_removed'));
  }

  Person? _me() {
    try {
      return people.firstWhere((p) => p.id == 'me');
    } catch (_) {
      return null;
    }
  }

  List<Person> _friends() {
    return people.where((p) => p.id != 'me').toList();
  }

  List<Person> _visiblePeople() {
    return _friends().where((person) {
      return person.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  _HomeGridConfig _gridConfig(int count) {
    if (count >= 8) {
      return const _HomeGridConfig(
        columns: 3,
        avatarSize: 112,
        nameSize: 15,
        childAspectRatio: 0.96,
        mainSpacing: 8,
        crossSpacing: 8,
      );
    }

    if (count >= 5) {
      return const _HomeGridConfig(
        columns: 2,
        avatarSize: 128,
        nameSize: 16,
        childAspectRatio: 1.06,
        mainSpacing: 10,
        crossSpacing: 12,
      );
    }

    return const _HomeGridConfig(
      columns: 2,
      avatarSize: 150,
      nameSize: 17,
      childAspectRatio: 1.02,
      mainSpacing: 12,
      crossSpacing: 12,
    );
  }

  Future<void> _reorderFriends(int oldIndex, int newIndex) async {
    final me = _me();
    final friends = _friends();

    if (oldIndex < 0 ||
        oldIndex >= friends.length ||
        newIndex < 0 ||
        newIndex >= friends.length) {
      return;
    }

    final moved = friends.removeAt(oldIndex);
    friends.insert(newIndex, moved);

    setState(() {
      people = me != null ? [me, ...friends] : [...friends];
    });

    await _persist();
  }

  Future<void> _openCreatePerson() async {
    final created = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePersonScreen()),
    );

    if (created != null) {
      await _addPerson(created);
    }
  }

  Future<void> _refreshRemoteFriendsWithRetry() async {
    for (int attempt = 0; attempt < 4; attempt++) {
      await _refreshAll();

      final hasPendingRequest = people.any(
        (person) =>
            person.sourceType == SourceType.friendRequestIncoming ||
            person.sourceType == SourceType.friendRequestPending,
      );

      if (!hasPendingRequest) return;

      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _openImportPerson({bool linkOnly = false}) async {
    final imported = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => ImportPersonScreen(linkOnly: linkOnly)),
    );

    await _handleImportedPerson(imported);
  }

  Future<void> _openQrScanner() async {
    final imported = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    await _handleImportedPerson(imported);
  }

  Future<void> _handleImportedPerson(Person? imported) async {
    if (imported == null) return;

    final alreadyExists = people.any((p) => p.publicId == imported.publicId);
    if (alreadyExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Человек с таким кодом уже есть в списке'),
        ),
      );
      return;
    }

    try {
      await RemoteFriendRequestsService.createRequestByPublicId(
        imported.publicId,
      );
      unawaited(
        FirebaseAnalytics.instance.logEvent(name: 'friend_request_sent'),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));

    await _refreshFriendRequests();
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final current = people
          .where(
            (p) =>
                p.sourceType != SourceType.friendRequestIncoming &&
                p.sourceType != SourceType.friendRequestPending,
          )
          .toList();
      final results = await Future.wait<Object?>([
        _syncFromRemoteOnLaunch(current),
        RemoteFriendRequestsService.loadMyRequests(),
      ]).timeout(const Duration(seconds: 15));
      final normalized = _applyDailyStateToPeople(results[0] as List<Person>);
      final requests = results[1] as List<RemoteFriendRequest>;
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _latestFriendRequests = requests;
        people = [...normalized, ..._requestsAsPeople(requests)];
      });
      unawaited(_persistBackground(normalized));
    } catch (_) {
      if (mounted && people.isEmpty) {
        setState(() => _loadError = 'Не удалось загрузить данные');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _persistBackground(List<Person> realPeople) async {
    await Future.wait<void>(
      [
        repository.savePeople(realPeople),
        WidgetService.updatePeople(realPeople),
        WatchSyncService.updatePeople(realPeople),
        NotificationService.rescheduleCycleNotifications(realPeople),
      ].map(
        (future) =>
            future.timeout(const Duration(seconds: 8)).catchError((_) {}),
      ),
    );
    final me = realPeople.where((p) => p.id == 'me').firstOrNull;
    if (me != null) {
      await RemotePeopleService.upsertMyPerson(
        me,
      ).timeout(const Duration(seconds: 10)).catchError((_) {});
    }
  }

  Future<void> _acceptRequest(RemoteFriendRequest request) async {
    try {
      await RemoteFriendRequestsService.acceptRequest(request.id);
      unawaited(
        FirebaseAnalytics.instance.logEvent(name: 'friend_request_accepted'),
      );

      await _refreshRemoteFriendsWithRetry();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Человек добавлен')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _declineRequest(RemoteFriendRequest request) async {
    await RemoteFriendRequestsService.declineRequest(request.id);
    unawaited(
      FirebaseAnalytics.instance.logEvent(name: 'friend_request_declined'),
    );

    if (!mounted) return;

    setState(() {
      _latestFriendRequests.removeWhere((r) => r.id == request.id);
      people.removeWhere((p) => p.id == 'request_${request.id}');
    });
  }

  Future<void> _cancelRequest(RemoteFriendRequest request) async {
    await RemoteFriendRequestsService.cancelRequest(request.id);

    if (!mounted) return;

    setState(() {
      _latestFriendRequests.removeWhere((r) => r.id == request.id);
      people.removeWhere((p) => p.id == 'request_${request.id}');
    });
  }

  Future<void> _openAddMenu() async {
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'add_person_opened'));
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Добавить человека'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openQrScanner();
            },
            child: const Text('Сканировать QR-код'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              unawaited(
                FirebaseAnalytics.instance.logEvent(
                  name: 'public_id_import_started',
                ),
              );
              _openImportPerson();
            },
            child: const Text('Ввести код'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openImportPerson(linkOnly: true);
            },
            child: const Text('Вставить ссылку'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCreatePerson();
            },
            child: const Text('Создать вручную'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Отмена'),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Локальные данные останутся привязаны к этому аккаунту.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'logout'));
    await AuthService.signOut();
  }

  Widget _buildProfileTab() {
    final me = _me();
    if (me == null) return const Center(child: CupertinoActivityIndicator());
    final link = buildPersonLink(me);
    return ListView(
      key: const PageStorageKey('profile_tab'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Center(
          child: PersonAvatar(
            mood: me.mood,
            gender: me.gender,
            avatarVariant: me.avatarVariant,
            size: 150,
            isMyProfile: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          me.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryText(context),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Текущий настрой: ${me.mood.name}',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText(context)),
        ),
        const SizedBox(height: 20),
        Center(
          child: QrImageView(
            data: link,
            size: 170,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        _profileAction(
          CupertinoIcons.smiley,
          'Изменить настрой',
          _openQuickMoodPicker,
        ),
        _profileAction(
          CupertinoIcons.pencil,
          'Редактировать профиль',
          _openMyProfile,
        ),
        _profileAction(CupertinoIcons.share, 'Поделиться профилем', () async {
          await Clipboard.setData(ClipboardData(text: link));
          unawaited(
            FirebaseAnalytics.instance.logEvent(name: 'profile_shared'),
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
          }
        }),
        _profileAction(CupertinoIcons.doc_on_doc, 'Скопировать код', () async {
          await Clipboard.setData(ClipboardData(text: me.publicId));
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Код скопирован')));
          }
        }),
        _profileAction(
          CupertinoIcons.info,
          'О приложении и настройки',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
        const SizedBox(height: 28),
        CupertinoButton(
          onPressed: _confirmLogout,
          child: const Text(
            'Выйти из аккаунта',
            style: TextStyle(color: CupertinoColors.systemRed),
          ),
        ),
      ],
    );
  }

  Widget _profileAction(IconData icon, String title, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          minTileHeight: 52,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
          onTap: onTap,
        ),
      );

  Future<void> _openMyProfile() async {
    final me = _me();
    if (me == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonScreen(
          person: me,
          onPersonUpdated: _updatePerson,
          isEditable: true,
          isMyProfile: true,
          onPersonDeleted: null,
          onTogglePin: null,
        ),
      ),
    );
  }

  Future<void> _startChat(Person friend) async {
    if (friend.sourceType != SourceType.imported) return;
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'chat_started'));
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
    );
  }

  Future<void> _openQuickMoodPicker() async {
    final me = _me();
    if (me == null) return;

    final selectedMood = await showModalBottomSheet<MoodType>(
      context: context,
      backgroundColor: AppColors.surface(context),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Изменить мой настрой',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _moodOption('😌 Спокойно', MoodType.calm),
              _moodOption('🙂 Радостно', MoodType.happy),
              _moodOption('😔 Грустно', MoodType.sad),
              _moodOption('😠 Раздражён', MoodType.irritated),
              _moodOption('🥱 Устал', MoodType.tired),
              _moodOption('🥺 Нужна забота', MoodType.needsCare),
            ],
          ),
        );
      },
    );

    if (selectedMood == null) return;

    final updatedMe = me
        .copyWith(
          manualMoodOverride: selectedMood,
          manualMoodOverrideDateIso: Person.dateOnlyIso(DateTime.now()),
          mood: selectedMood,
        )
        .applyLifeCycleForDate(DateTime.now());

    await _updatePerson(updatedMe);
    unawaited(FirebaseAnalytics.instance.logEvent(name: 'own_mood_changed'));
  }

  void _toggleFabMenu() => setState(() => isFabMenuOpen = !isFabMenuOpen);

  Future<void> _handleAddPersonAction() => _openAddMenu();

  Future<void> _handleMyMoodAction() => _openQuickMoodPicker();

  Widget _moodOption(String text, MoodType mood) {
    return ListTile(
      title: Text(
        text,
        style: TextStyle(color: AppColors.primaryText(context)),
      ),
      onTap: () => Navigator.pop(context, mood),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => searchQuery = value),
      style: TextStyle(color: AppColors.primaryText(context)),
      decoration: InputDecoration(
        hintText: 'Поиск по имени',
        hintStyle: TextStyle(color: AppColors.subtleText(context)),
        prefixIcon: Icon(Icons.search, color: AppColors.mutedText(context)),
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.subtleText(context)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String heroTag,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        onPressed: onTap,
        child: Icon(icon, color: AppColors.primaryText(context)),
      ),
    );
  }

  // Kept temporarily for compatibility with existing hero tags; not rendered.
  // ignore: unused_element
  Widget _buildFabMenu() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            right: 0,
            bottom: isFabMenuOpen ? 72 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isFabMenuOpen ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isFabMenuOpen,
                child: _buildMiniActionButton(
                  heroTag: 'fab_mood_action',
                  icon: Icons.emoji_emotions_outlined,
                  onTap: _handleMyMoodAction,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            right: isFabMenuOpen ? 72 : 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isFabMenuOpen ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isFabMenuOpen,
                child: _buildMiniActionButton(
                  heroTag: 'fab_add_action',
                  icon: Icons.person_add_alt_1,
                  onTap: _handleAddPersonAction,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            heroTag: 'main_actions',
            backgroundColor: AppColors.chip(context),
            elevation: 0,
            onPressed: _toggleFabMenu,
            child: Icon(Icons.add, color: AppColors.primaryText(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTile(
    Person person, {
    required double avatarSize,
    required double nameSize,
  }) {
    final isEditable = person.sourceType == SourceType.local;

    return GestureDetector(
      onTap: () {
        unawaited(FirebaseAnalytics.instance.logEvent(name: 'person_opened'));
        if (person.sourceType == SourceType.friendRequestIncoming ||
            person.sourceType == SourceType.friendRequestPending) {
          final request = _requestForPerson(person);
          if (request == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonScreen(
                person: person,
                friendRequest: request,
                onPersonUpdated: (_) {},
                isEditable: false,
                isMyProfile: false,
                onPersonDeleted: null,
                onAcceptRequest: _acceptRequest,
                onDeclineRequest: _declineRequest,
                onCancelRequest: _cancelRequest,
                onTogglePin: null,
              ),
            ),
          );

          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonScreen(
              person: person,
              onPersonUpdated: _updatePerson,
              isEditable: isEditable,
              isMyProfile: false,
              onPersonDeleted: () => _deletePerson(person.id),
              onTogglePin: null,
              onStartChat: person.sourceType == SourceType.imported
                  ? () => _startChat(person)
                  : null,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: PersonAvatar(
                mood: person.mood,
                gender: person.gender,
                avatarVariant: person.avatarVariant,
                size: avatarSize,
                customAsset: _requestAvatarAsset(person),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: nameSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridPeople(List<Person> visiblePeople) {
    final config = _gridConfig(visiblePeople.length);

    return ReorderableGridView.count(
      crossAxisCount: config.columns,
      mainAxisSpacing: config.mainSpacing,
      crossAxisSpacing: config.crossSpacing,
      childAspectRatio: config.childAspectRatio,
      onReorder: _reorderFriends,
      children: [
        for (final person in visiblePeople)
          Container(
            key: ValueKey(person.id),
            child: _buildPersonTile(
              person,
              avatarSize: config.avatarSize,
              nameSize: config.nameSize,
            ),
          ),
      ],
    );
  }

  Widget _buildPeopleContent(List<Person> visiblePeople, bool hasSearch) {
    if (visiblePeople.isEmpty) {
      return hasSearch
          ? _buildEmptyState(
              icon: Icons.search_off,
              title: 'Ничего не найдено',
              subtitle: 'Попробуй изменить запрос или очистить поиск.',
            )
          : _buildEmptyState(
              icon: Icons.people_outline,
              title: 'Пока никого нет',
              subtitle:
                  'Добавь человека вручную или импортируй профиль по ссылке или коду.',
            );
    }

    if (visiblePeople.length == 1) {
      final person = visiblePeople.first;
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: 300,
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildPersonTile(person, avatarSize: 190, nameSize: 18),
            ),
          ),
        ),
      );
    }

    if (hasSearch) {
      final config = _gridConfig(visiblePeople.length);

      return GridView.count(
        crossAxisCount: config.columns,
        mainAxisSpacing: config.mainSpacing,
        crossAxisSpacing: config.crossSpacing,
        childAspectRatio: config.childAspectRatio,
        children: [
          for (final person in visiblePeople)
            _buildPersonTile(
              person,
              avatarSize: config.avatarSize,
              nameSize: config.nameSize,
            ),
        ],
      );
    }

    return _buildGridPeople(visiblePeople);
  }

  @override
  Widget build(BuildContext context) {
    final friendsCount = _friends().length;
    final shouldShowSearch = friendsCount >= 9;

    if (!shouldShowSearch && searchQuery.isNotEmpty) {
      searchQuery = '';
    }

    final visiblePeople = _visiblePeople();
    final hasSearch = searchQuery.trim().isNotEmpty;
    final isSinglePersonMode = friendsCount == 1;

    final peopleTab = isLoading
        ? const Center(child: CupertinoActivityIndicator(radius: 14))
        : _loadError != null && people.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _init, child: const Text('Повторить')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _refreshAll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  if (!isSinglePersonMode && shouldShowSearch) ...[
                    _buildSearchField(),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: _buildPeopleContent(visiblePeople, hasSearch),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        centerTitle: false,
        title: Text(
          switch (_selectedTab) {
            0 => 'Люди',
            1 => 'Чаты',
            _ => 'Профиль',
          },
          style: TextStyle(
            color: AppColors.primaryText(context),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              tooltip: 'Добавить человека',
              onPressed: _openAddMenu,
              icon: Icon(
                CupertinoIcons.add,
                color: AppColors.primaryText(context),
              ),
            ),
          if (_selectedTab == 2)
            IconButton(
              tooltip: 'Сменить тему',
              onPressed: () =>
                  appThemeMode.value = appThemeMode.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
              icon: Icon(
                appThemeMode.value == ThemeMode.dark
                    ? CupertinoIcons.sun_max
                    : CupertinoIcons.moon,
                color: AppColors.primaryText(context),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          peopleTab,
          ChatListScreen(
            initialFriends: people.where(isRemoteChatFriend).toList(),
            onOpenPeople: () => homeTabIndex.value = 0,
          ),
          _buildProfileTab(),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: totalChatUnread,
        builder: (_, unread, _) => GlassTabBar(
          index: _selectedTab,
          unread: unread,
          onChanged: (index) {
            if (index == _selectedTab) return;
            setState(() => _selectedTab = index);
            homeTabIndex.value = index;
            final event = switch (index) {
              0 => 'people_tab_opened',
              1 => 'chats_tab_opened',
              _ => 'profile_tab_opened',
            };
            unawaited(FirebaseAnalytics.instance.logEvent(name: event));
          },
        ),
      ),
    );
  }
}
