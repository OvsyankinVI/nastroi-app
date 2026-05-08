import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/person.dart';

class LifeCycleScreen extends StatefulWidget {
  final Person person;

  const LifeCycleScreen({
    super.key,
    required this.person,
  });

  @override
  State<LifeCycleScreen> createState() => _LifeCycleScreenState();
}

class _LifeCycleScreenState extends State<LifeCycleScreen> {
  late bool _lifeCycleEnabled;
  late List<CycleStage> _stages;
  late String? _cycleStartDateIso;

  @override
  void initState() {
    super.initState();
    _lifeCycleEnabled = widget.person.lifeCycleEnabled;
    _stages = List<CycleStage>.from(widget.person.cycleStages);
    _cycleStartDateIso = widget.person.cycleStartDateIso;

    if (_lifeCycleEnabled && _cycleStartDateIso == null) {
      _cycleStartDateIso = DateTime.now().toIso8601String();
    }
  }

  String _visibleActionText(String value) {
    final trimmed = value.trim();

    if (trimmed.startsWith('emoji::')) {
      final parts = trimmed.split('::');
      if (parts.length >= 3) {
        return parts.sublist(2).join('::').trim();
      }
    }

    return trimmed;
  }

  String _actionsText(List<String> actions) {
    return actions.map(_visibleActionText).where((e) => e.isNotEmpty).join(', ');
  }

  String _moodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Радостно';
      case MoodType.calm:
        return 'Спокойно';
      case MoodType.sad:
        return 'Грустно';
      case MoodType.irritated:
        return 'Раздражён';
      case MoodType.tired:
        return 'Устал';
      case MoodType.needsCare:
        return 'Нужна забота';
    }
  }

  String _moodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return '🙂';
      case MoodType.calm:
        return '😌';
      case MoodType.sad:
        return '😔';
      case MoodType.irritated:
        return '😠';
      case MoodType.tired:
        return '🥱';
      case MoodType.needsCare:
        return '🥺';
    }
  }

  Color _moodAccent(MoodType mood) {
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

  int get _totalCycleDays {
    return _stages.fold<int>(0, (sum, stage) => sum + stage.durationDays);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int get _activeCycleDay {
    final totalDays = _totalCycleDays;
    if (totalDays <= 0) return 1;

    final startDate =
        _cycleStartDateIso != null ? DateTime.tryParse(_cycleStartDateIso!) : null;

    final normalizedStart = _dateOnly(startDate ?? DateTime.now());
    final normalizedToday = _dateOnly(DateTime.now());

    final diff = normalizedToday.difference(normalizedStart).inDays;
    final safeDiff = diff < 0 ? 0 : diff;
    final dayIndex = safeDiff % totalDays;

    return dayIndex + 1;
  }

  int? get _activeStageIndex {
    if (_stages.isEmpty) return null;

    final activeDay = _activeCycleDay;
    int passed = 0;

    for (int i = 0; i < _stages.length; i++) {
      passed += _stages[i].durationDays;
      if (activeDay <= passed) return i;
    }

    return _stages.isEmpty ? null : _stages.length - 1;
  }

  CycleStage? get _activeStageToday {
    final index = _activeStageIndex;
    if (index == null) return null;
    return _stages[index];
  }

  void _setActiveCycleDay(int dayNumber) {
    final totalDays = _totalCycleDays;
    if (totalDays <= 0) return;

    final safeDay = dayNumber.clamp(1, totalDays);
    final today = _dateOnly(DateTime.now());
    final adjustedStart = today.subtract(Duration(days: safeDay - 1));

    setState(() {
      _cycleStartDateIso = adjustedStart.toIso8601String();
    });
  }

  void _normalizeActiveDayIfNeeded() {
    final totalDays = _totalCycleDays;
    if (totalDays <= 0) return;

    final currentDay = _activeCycleDay;
    if (currentDay > totalDays) {
      _setActiveCycleDay(totalDays);
    }
  }

  Future<void> _addStage() async {
    final created = await showModalBottomSheet<CycleStage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      builder: (_) => const _CycleStageEditorSheet(),
    );

    if (created == null) return;

    setState(() {
      _stages.add(created);
    });

    _cycleStartDateIso ??= DateTime.now().toIso8601String();
    _normalizeActiveDayIfNeeded();
  }

  Future<void> _editStage(int index) async {
    final updated = await showModalBottomSheet<CycleStage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      builder: (_) => _CycleStageEditorSheet(
        initialStage: _stages[index],
      ),
    );

    if (updated == null) return;

    setState(() {
      _stages[index] = updated;
    });

    _normalizeActiveDayIfNeeded();
  }

  void _removeStage(int index) {
    setState(() {
      _stages.removeAt(index);
    });

    _normalizeActiveDayIfNeeded();
  }

  void _reorderStages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      final moved = _stages.removeAt(oldIndex);
      _stages.insert(newIndex, moved);
    });
  }

  void _save() {
    final updatedPerson = widget.person
        .copyWith(
          lifeCycleEnabled: _lifeCycleEnabled,
          cycleStages: _stages,
          cycleStartDateIso: _lifeCycleEnabled && _stages.isNotEmpty
              ? (_cycleStartDateIso ?? DateTime.now().toIso8601String())
              : null,
        )
        .applyLifeCycleForDate(DateTime.now());

    Navigator.pop(context, updatedPerson);
  }

  List<_CycleDayVisual> _buildDayVisuals() {
    final result = <_CycleDayVisual>[];
    int dayCounter = 1;

    for (final stage in _stages) {
      final color = _moodAccent(stage.mood);

      for (int i = 0; i < stage.durationDays; i++) {
        result.add(
          _CycleDayVisual(
            dayNumber: dayCounter,
            color: color,
            stageTitle:
                stage.title.isNotEmpty ? stage.title : _moodLabel(stage.mood),
            mood: stage.mood,
          ),
        );
        dayCounter++;
      }
    }

    return result;
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: child,
    );
  }

  Widget _buildCycleTimeline() {
    final days = _buildDayVisuals();
    final activeDay = _activeCycleDay;

    if (days.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Лента цикла',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Каждый день окрашен цветом своего этапа. Сегодняшний день выделен рамкой.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = days[index];
                final isActive = item.dayNumber == activeDay;

                return GestureDetector(
                  onTap: () => _setActiveCycleDay(item.dayNumber),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isActive ? 52 : 42,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: isActive ? 0.90 : 0.62),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryText(context)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.30),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${item.dayNumber}',
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: isActive ? 18 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard(CycleStage stage, int index) {
    final title = stage.title.isNotEmpty ? stage.title : _moodLabel(stage.mood);
    final isActive = _activeStageIndex == index;
    final accent = _moodAccent(stage.mood);

    return AnimatedContainer(
      key: ValueKey('${stage.title}_${stage.durationDays}_$index'),
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? accent.withValues(alpha: 0.75) : AppColors.border(context),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(
                Icons.drag_indicator,
                color: AppColors.subtleText(context),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isActive) ...[
                      Text(
                        _moodEmoji(stage.mood),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Сегодня',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_moodLabel(stage.mood)} • ${stage.durationDays} дн.',
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 14,
                  ),
                ),
                if (stage.helpfulActions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Помогает: ${_actionsText(stage.helpfulActions)}',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (stage.avoidActions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Избегать: ${_actionsText(stage.avoidActions)}',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _editStage(index),
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.secondaryText(context),
              ),
              IconButton(
                onPressed: () => _removeStage(index),
                icon: const Icon(Icons.delete_outline),
                color: AppColors.secondaryText(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStageCard() {
    final activeStage = _activeStageToday;
    if (activeStage == null) return const SizedBox.shrink();

    final accent = _moodAccent(activeStage.mood);
    final title = activeStage.title.isNotEmpty
        ? activeStage.title
        : _moodLabel(activeStage.mood);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сегодня активен этап',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _moodEmoji(activeStage.mood),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_moodLabel(activeStage.mood)} • День $_activeCycleDay из $_totalCycleDays',
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (activeStage.helpfulActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Помогает: ${_actionsText(activeStage.helpfulActions)}',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (activeStage.avoidActions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Избегать: ${_actionsText(activeStage.avoidActions)}',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveDayCard() {
    final totalDays = _totalCycleDays;
    final activeDay = _activeCycleDay;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активный день цикла',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Выбери, какой день цикла считается сегодняшним.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: activeDay > 1
                    ? () => _setActiveCycleDay(activeDay - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primaryText(context),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$activeDay / $totalDays',
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: activeDay < totalDays
                    ? () => _setActiveCycleDay(activeDay + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primaryText(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Добавь первый этап: например, 3 дня “Спокойно”, потом 2 дня “Устал”.',
        style: TextStyle(
          color: AppColors.secondaryText(context),
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasStages = _stages.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          'Цикличность жизни',
          style: TextStyle(color: AppColors.primaryText(context)),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Сохранить',
              style: TextStyle(color: AppColors.primaryText(context)),
            ),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        onReorder: _reorderStages,
        buildDefaultDragHandles: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _lifeCycleEnabled,
              onChanged: (value) {
                setState(() {
                  _lifeCycleEnabled = value;
                  if (_lifeCycleEnabled && _cycleStartDateIso == null) {
                    _cycleStartDateIso = DateTime.now().toIso8601String();
                  }
                });
              },
              activeThumbColor: AppColors.accent(context),
              activeTrackColor: AppColors.chip(context),
              title: Text(
                'Включить цикличность жизни',
                style: TextStyle(color: AppColors.primaryText(context)),
              ),
              subtitle: Text(
                'Настрой будет браться из последовательности этапов цикла.',
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Text(
                hasStages
                    ? 'Этапов: ${_stages.length} • Общая длина цикла: $_totalCycleDays дн.'
                    : 'Пока этапов нет. Добавь этапы цикла ниже.',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (_lifeCycleEnabled && hasStages) ...[
              const SizedBox(height: 16),
              _buildActiveDayCard(),
              const SizedBox(height: 12),
              _buildTodayStageCard(),
              const SizedBox(height: 12),
              _buildCycleTimeline(),
            ],
            const SizedBox(height: 20),
            Text(
              'Этапы цикла',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (!hasStages) ...[
              _buildEmptyState(),
              const SizedBox(height: 12),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Зажми и потяни этап за иконку слева, чтобы изменить порядок.',
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addStage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.chip(context),
                foregroundColor: AppColors.primaryText(context),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Добавить этап',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        children: [
          for (int i = 0; i < _stages.length; i++)
            _buildStageCard(_stages[i], i),
        ],
      ),
    );
  }
}

class _CycleDayVisual {
  final int dayNumber;
  final Color color;
  final String stageTitle;
  final MoodType mood;

  const _CycleDayVisual({
    required this.dayNumber,
    required this.color,
    required this.stageTitle,
    required this.mood,
  });
}

class _CycleStageEditorSheet extends StatefulWidget {
  final CycleStage? initialStage;

  const _CycleStageEditorSheet({
    this.initialStage,
  });

  @override
  State<_CycleStageEditorSheet> createState() => _CycleStageEditorSheetState();
}

class _CycleStageEditorSheetState extends State<_CycleStageEditorSheet> {
  late final TextEditingController _titleController;
  final List<_CustomActionDraft> _customHelpfulActions = [];
  final List<_CustomActionDraft> _customAvoidActions = [];

  late MoodType _selectedMood;
  late int _durationDays;

  String? _helpfulError;
  String? _avoidError;

  final List<String> _helpfulOptions = [
    'Обнять',
    'Написать',
    'Позвонить',
    'Подарок',
    'Сладкое',
    'Прогулка',
    'Тишина',
    'Поддержка',
    'Другое',
  ];

  final List<String> _avoidOptions = [
    'Спорить',
    'Давить',
    'Игнорировать',
    'Шутить',
    'Торопить',
    'Критиковать',
    'Шуметь',
    'Навязываться',
    'Другое',
  ];

  final Set<String> _selectedHelpful = {};
  final Set<String> _selectedAvoid = {};

  @override
  void initState() {
    super.initState();

    final stage = widget.initialStage;

    _titleController = TextEditingController(text: stage?.title ?? '');
    _selectedMood = stage?.mood ?? MoodType.calm;
    _durationDays = stage?.durationDays ?? 1;

    if (stage != null) {
      for (final item in stage.helpfulActions) {
        if (_helpfulOptions.contains(item)) {
          _selectedHelpful.add(item);
        } else {
          final parsed = _parseStoredEmojiAction(item, defaultEmoji: '✨');
        _customHelpfulActions.add(
          _CustomActionDraft(
            controller: TextEditingController(text: parsed.text),
            emoji: parsed.emoji,
          ),
        );
        }
      }

      for (final item in stage.avoidActions) {
        if (_avoidOptions.contains(item)) {
          _selectedAvoid.add(item);
        } else {
          final parsed = _parseStoredEmojiAction(item, defaultEmoji: '⚠️');
          _customAvoidActions.add(
            _CustomActionDraft(
              controller: TextEditingController(text: parsed.text),
              emoji: parsed.emoji,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final item in _customHelpfulActions) {
      item.controller.dispose();
    }

    for (final item in _customAvoidActions) {
      item.controller.dispose();
    }
    super.dispose();
  }

  _ParsedEmojiAction _parseStoredEmojiAction(
    String value, {
    required String defaultEmoji,
  }) {
    final trimmed = value.trim();

    if (trimmed.startsWith('emoji::')) {
      final parts = trimmed.split('::');
      if (parts.length >= 3) {
        return _ParsedEmojiAction(
          emoji: parts[1],
          text: parts.sublist(2).join('::').trim(),
        );
      }
    }

    return _ParsedEmojiAction(
      emoji: defaultEmoji,
      text: trimmed,
    );
  }

  String _buildStoredEmojiAction({
    required String emoji,
    required String text,
  }) {
    return 'emoji::$emoji::$text';
  }

  String _moodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Радостно';
      case MoodType.calm:
        return 'Спокойно';
      case MoodType.sad:
        return 'Грустно';
      case MoodType.irritated:
        return 'Раздражён';
      case MoodType.tired:
        return 'Устал';
      case MoodType.needsCare:
        return 'Нужна забота';
    }
  }

  String _normalizeText(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    final lower = compact.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  InputDecoration _decoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.secondaryText(context)),
      errorText: errorText,
      counterStyle: TextStyle(color: AppColors.subtleText(context)),
      filled: true,
      fillColor: AppColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

Future<void> _pickEmoji({
  required bool isHelpful,
  required int index,
}) async {
  final emojis = isHelpful
      ? ['✨', '🤗', '💬', '📞', '🎁', '🍬', '🚶', '🤫', '🫶', '🌷', '☕️', '🎧']
      : ['⚠️', '🔊', '⚡', '🧱', '🚫', '⏩', '❗', '🙄', '⛔', '😤', '💢', '🛑'];

  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface(context),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, emoji),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );

  if (selected == null) return;

  setState(() {
    final list = isHelpful ? _customHelpfulActions : _customAvoidActions;

    if (index >= 0 && index < list.length) {
      list[index].emoji = selected;
    }
  });
}

  Widget _buildChipGroup({
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);

        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => onToggle(option),
          selectedColor: AppColors.chip(context),
          checkmarkColor: AppColors.primaryText(context),
          backgroundColor: AppColors.surface(context),
          labelStyle: TextStyle(
            color: isSelected
                ? AppColors.primaryText(context)
                : AppColors.secondaryText(context),
            fontWeight: FontWeight.w500,
          ),
          side: BorderSide(color: AppColors.border(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }).toList(),
    );
  }

Widget _buildCustomActionFields({
  required List<_CustomActionDraft> items,
  required bool isHelpful,
}) {
  if (items.isEmpty) return const SizedBox.shrink();

  final errorText = isHelpful ? _helpfulError : _avoidError;

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: items[i].controller,
                  maxLength: 20,
                  style: TextStyle(color: AppColors.primaryText(context)),
                  decoration: _decoration(
                    'Свой вариант ${i + 1}',
                    errorText: i == items.length - 1 ? errorText : null,
                  ),
                  onChanged: (_) {
                    setState(() {
                      if (isHelpful) {
                        _helpfulError = null;
                      } else {
                        _avoidError = null;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _pickEmoji(
                  isHelpful: isHelpful,
                  index: i,
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    items[i].emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    final removed = items.removeAt(i);
                    removed.controller.dispose();

                    if (isHelpful) {
                      _helpfulError = null;
                    } else {
                      _avoidError = null;
                    }
                  });
                },
                icon: Icon(
                  Icons.close,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
          ),
          if (i != items.length - 1) const SizedBox(height: 8),
        ],

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                final selectedCount = isHelpful
                    ? _selectedHelpful.length
                    : _selectedAvoid.length;

                final totalCount = selectedCount + items.length;

                if (totalCount >= 3) {
                  if (isHelpful) {
                    _helpfulError = 'Можно выбрать максимум 3 варианта';
                  } else {
                    _avoidError = 'Можно выбрать максимум 3 варианта';
                  }
                  return;
                }

                items.add(
                  _CustomActionDraft(
                    controller: TextEditingController(),
                    emoji: isHelpful ? '✨' : '⚠️',
                  ),
                );
              });
            },
            icon: Icon(
              Icons.add,
              size: 18,
              color: AppColors.secondaryText(context),
            ),
            label: Text(
              'Добавить ещё',
              style: TextStyle(
                color: AppColors.secondaryText(context),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void _toggleHelpful(String value) {
  if (value == 'Другое') {
    setState(() {
      final totalCount = _selectedHelpful.length + _customHelpfulActions.length;

      if (totalCount >= 3) {
        _helpfulError = 'Можно выбрать максимум 3 варианта';
        return;
      }

      _customHelpfulActions.add(
        _CustomActionDraft(
          controller: TextEditingController(),
          emoji: '✨',
        ),
      );

      _helpfulError = null;
    });
    return;
  }

  setState(() {
    final isSelected = _selectedHelpful.contains(value);

    if (isSelected) {
      _selectedHelpful.remove(value);
    } else {
      final totalCount = _selectedHelpful.length + _customHelpfulActions.length;

      if (totalCount >= 3) {
        _helpfulError = 'Можно выбрать максимум 3 варианта';
        return;
      }

      _selectedHelpful.add(value);
    }

    _helpfulError = null;
  });
}

void _toggleAvoid(String value) {
  if (value == 'Другое') {
    setState(() {
      final totalCount = _selectedAvoid.length + _customAvoidActions.length;

      if (totalCount >= 3) {
        _avoidError = 'Можно выбрать максимум 3 варианта';
        return;
      }

      _customAvoidActions.add(
        _CustomActionDraft(
          controller: TextEditingController(),
          emoji: '⚠️',
        ),
      );

      _avoidError = null;
    });
    return;
  }

  setState(() {
    final isSelected = _selectedAvoid.contains(value);

    if (isSelected) {
      _selectedAvoid.remove(value);
    } else {
      final totalCount = _selectedAvoid.length + _customAvoidActions.length;

      if (totalCount >= 3) {
        _avoidError = 'Можно выбрать максимум 3 варианта';
        return;
      }

      _selectedAvoid.add(value);
    }

    _avoidError = null;
  });
}

List<String> _buildHelpfulActions() {
  final values = _selectedHelpful.where((e) => e != 'Другое').toList();

  for (final item in _customHelpfulActions) {
    final custom = _normalizeText(item.controller.text);
    if (custom.isNotEmpty) {
      values.add(
        _buildStoredEmojiAction(
          emoji: item.emoji,
          text: custom,
        ),
      );
    }
  }

  return values.take(3).toList();
}

List<String> _buildAvoidActions() {
  final values = _selectedAvoid.where((e) => e != 'Другое').toList();

  for (final item in _customAvoidActions) {
    final custom = _normalizeText(item.controller.text);
    if (custom.isNotEmpty) {
      values.add(
        _buildStoredEmojiAction(
          emoji: item.emoji,
          text: custom,
        ),
      );
    }
  }

  return values.take(3).toList();
}

  void _saveStage() {
    final title = _normalizeText(_titleController.text);
    final helpful = _buildHelpfulActions();
    final avoid = _buildAvoidActions();

final hasEmptyHelpfulCustom = _customHelpfulActions.any(
  (item) => _normalizeText(item.controller.text).isEmpty,
);

final hasEmptyAvoidCustom = _customAvoidActions.any(
  (item) => _normalizeText(item.controller.text).isEmpty,
);

    setState(() {
      _helpfulError = helpful.isEmpty || hasEmptyHelpfulCustom
          ? 'Выбери хотя бы один вариант'
          : null;
      _avoidError = avoid.isEmpty || hasEmptyAvoidCustom
          ? 'Выбери хотя бы один вариант'
          : null;
    });

    if (helpful.isEmpty ||
      avoid.isEmpty ||
      hasEmptyHelpfulCustom ||
      hasEmptyAvoidCustom) {
      return;
    }

    Navigator.of(context).pop(
      CycleStage(
        title: title,
        mood: _selectedMood,
        durationDays: _durationDays,
        helpfulActions: helpful,
        avoidActions: avoid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          56,
          16,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initialStage == null
                        ? 'Новый этап'
                        : 'Редактировать этап',
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saveStage,
                  child: Text(
                    'Сохранить',
                    style: TextStyle(color: AppColors.primaryText(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              maxLength: 20,
              style: TextStyle(color: AppColors.primaryText(context)),
              decoration: _decoration('Название этапа'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MoodType>(
              value: _selectedMood,
              dropdownColor: AppColors.surface(context),
              style: TextStyle(color: AppColors.primaryText(context)),
              decoration: _decoration('Настрой этапа'),
              items: MoodType.values.map((mood) {
                return DropdownMenuItem(
                  value: mood,
                  child: Text(
                    _moodLabel(mood),
                    style: TextStyle(color: AppColors.primaryText(context)),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMood = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Длительность этапа',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _durationDays > 1
                      ? () => setState(() => _durationDays--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primaryText(context),
                ),
                Text(
                  '$_durationDays дн.',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _durationDays++),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primaryText(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Что помогает',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildChipGroup(
              options: _helpfulOptions,
              selectedValues: _selectedHelpful,
              onToggle: _toggleHelpful,
            ),
            _buildCustomActionFields(
              items: _customHelpfulActions,
              isHelpful: true,
            ),
            if (_helpfulError != null && _customHelpfulActions.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _helpfulError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Что лучше не делать',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildChipGroup(
              options: _avoidOptions,
              selectedValues: _selectedAvoid,
              onToggle: _toggleAvoid,
            ),
            _buildCustomActionFields(
              items: _customAvoidActions,
              isHelpful: false,
            ),
            if (_avoidError != null && _customAvoidActions.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _avoidError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParsedEmojiAction {
  final String emoji;
  final String text;

  const _ParsedEmojiAction({
    required this.emoji,
    required this.text,
  });
}

class _CustomActionDraft {
  final TextEditingController controller;
  String emoji;

  _CustomActionDraft({
    required this.controller,
    required this.emoji,
  });
}