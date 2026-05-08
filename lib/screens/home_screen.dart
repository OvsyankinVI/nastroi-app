import 'package:flutter/material.dart';
import 'package:reorderable_grid/reorderable_grid.dart';

import '../app_colors.dart';
import '../app_theme_controller.dart';
import '../data/people_repository.dart';
import '../models/person.dart';
import '../widgets/person_avatar.dart';
import 'about_screen.dart';
import 'create_person_screen.dart';
import 'import_person_screen.dart';
import 'person_screen.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../services/watch_sync_service.dart';

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
  final repository = PeopleRepository();

  List<Person> people = [];
  bool isLoading = true;
  String searchQuery = '';
  bool isFabMenuOpen = false;
  bool isHintDismissed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loaded = await repository.loadPeople();
    final normalized = _applyDailyStateToPeople(loaded);

    setState(() {
      people = normalized;
      isLoading = false;
    });

    await repository.savePeople(normalized);
    await WidgetService.updatePeople(normalized);
    await WatchSyncService.updatePeople(normalized);
    await NotificationService.rescheduleCycleNotifications(normalized);
  }

  List<Person> _applyDailyStateToPeople(List<Person> source) {
    final today = DateTime.now();
    return source.map((person) => person.applyLifeCycleForDate(today)).toList();
  }

Future<void> _persist() async {
  await repository.savePeople(people);
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

  Future<void> _deletePerson(String personId) async {
    setState(() {
      people.removeWhere((p) => p.id == personId);
    });

    await _persist();
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

  Future<void> _openImportPerson() async {
    final imported = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => const ImportPersonScreen()),
    );

    if (imported == null) return;

    final alreadyExists = people.any((p) => p.publicId == imported.publicId);
    if (alreadyExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Человек с таким кодом уже есть в списке')),
      );
      return;
    }

    await _addPerson(imported);
  }

  Future<void> _openAddMenu() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person_add_alt_1,
                    color: AppColors.primaryText(context)),
                title: Text(
                  'Создать вручную',
                  style: TextStyle(color: AppColors.primaryText(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openCreatePerson();
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.qr_code_2, color: AppColors.primaryText(context)),
                title: Text(
                  'Импорт по коду',
                  style: TextStyle(color: AppColors.primaryText(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openImportPerson();
                },
              ),
            ],
          ),
        );
      },
    );
  }

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

  void _toggleFabMenu() {
    setState(() {
      isFabMenuOpen = !isFabMenuOpen;
    });
  }

  void _closeFabMenu() {
    if (!isFabMenuOpen) return;
    setState(() => isFabMenuOpen = false);
  }

  Future<void> _handleAddPersonAction() async {
    _closeFabMenu();
    await _openAddMenu();
  }

  Future<void> _handleMyMoodAction() async {
    _closeFabMenu();
    await _openQuickMoodPicker();
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

    final updatedMe = me.copyWith(
      manualMoodOverride: selectedMood,
      manualMoodOverrideDateIso: Person.dateOnlyIso(DateTime.now()),
      mood: selectedMood,
    ).applyLifeCycleForDate(DateTime.now());

    await _updatePerson(updatedMe);
  }

  Widget _moodOption(String text, MoodType mood) {
    return ListTile(
      title: Text(
        text,
        style: TextStyle(color: AppColors.primaryText(context)),
      ),
      onTap: () => Navigator.pop(context, mood),
    );
  }

  Color _glowColor(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return const Color(0xFFFFC857);
      case MoodType.calm:
        return const Color(0xFF6FCF97);
      case MoodType.sad:
        return const Color(0xFF5B8DEF);
      case MoodType.irritated:
        return const Color(0xFFFF6B6B);
      case MoodType.tired:
        return const Color(0xFF9B7EDE);
      case MoodType.needsCare:
        return const Color(0xFFFF8CC8);
    }
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

  Widget _buildHintCard() {
    final hasSearch = searchQuery.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              hasSearch
                  ? 'Во время поиска порядок не меняется. Очисти поиск, чтобы переставлять карточки.'
                  : 'Нажми на +, чтобы быстро изменить свой настрой или добавить человека. Зажми карточку и перетащи её в нужное место.',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => isHintDismissed = true),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chip(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: AppColors.secondaryText(context),
                size: 18,
              ),
            ),
          ),
        ],
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

  Widget _buildMyAvatarButton() {
    final me = _me();
    if (me == null) return const SizedBox.shrink();

    final glowColor = _glowColor(me.mood);

    return GestureDetector(
      onTap: _openMyProfile,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.avatarGlow(glowColor, context),
              AppColors.avatarGlowSoft(glowColor, context),
              Colors.transparent,
            ],
            stops: const [0.20, 0.58, 1.0],
          ),
        ),
        alignment: Alignment.center,
        child: PersonAvatar(
          mood: me.mood,
          gender: me.gender,
          avatarVariant: me.avatarVariant,
          size: 38,
          isMyProfile: true,
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
              child: _buildPersonTile(
                person,
                avatarSize: 190,
                nameSize: 18,
              ),
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
    final shouldShowHint = !isSinglePersonMode && !isHintDismissed;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Настрой',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
              child: Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.mutedText(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Сменить тему',
            onPressed: () {
              appThemeMode.value =
                  appThemeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            icon: Icon(
              appThemeMode.value == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: AppColors.secondaryText(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _buildMyAvatarButton()),
          ),
        ],
      ),
      floatingActionButton: _buildFabMenu(),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeFabMenu,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryText(context),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    if (!isSinglePersonMode && shouldShowSearch) ...[
                      _buildSearchField(),
                      const SizedBox(height: 12),
                    ],
                    if (shouldShowHint) ...[
                      _buildHintCard(),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: _buildPeopleContent(visiblePeople, hasSearch),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}