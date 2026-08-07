import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/person.dart';
import '../widgets/person_avatar.dart';
import 'life_cycle_screen.dart' as cycle_screen;

class EditPersonScreen extends StatefulWidget {
  final Person person;

  const EditPersonScreen({super.key, required this.person});

  @override
  State<EditPersonScreen> createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends State<EditPersonScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _customRelationController =
      TextEditingController();

  late MoodType _selectedMood;
  late RelationType _selectedRelation;
  late GenderType _selectedGender;
  late int _selectedAvatarVariant;

  late bool _lifeCycleEnabled;
  late List<CycleStage> _cycleStages;
  late String? _cycleStartDateIso;

  String? _nameError;
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
  final List<_CustomActionDraft> _customHelpfulActions = [];
  final List<_CustomActionDraft> _customAvoidActions = [];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.person.name);

    _selectedMood = widget.person.mood;
    _selectedRelation = widget.person.relationType;
    _selectedGender = widget.person.gender;
    _selectedAvatarVariant = widget.person.avatarVariant;

    _lifeCycleEnabled = widget.person.lifeCycleEnabled;
    _cycleStages = List<CycleStage>.from(widget.person.cycleStages);
    _cycleStartDateIso = widget.person.cycleStartDateIso;

    _customRelationController.text = widget.person.customRelationLabel ?? '';

    for (final item in widget.person.helpfulActions) {
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

    for (final item in widget.person.avoidActions) {
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

  @override
  void dispose() {
    _nameController.dispose();
    _customRelationController.dispose();
    for (final item in _customHelpfulActions) {
      item.controller.dispose();
    }

    for (final item in _customAvoidActions) {
      item.controller.dispose();
    }
    super.dispose();
  }

  bool get _isMyProfile => widget.person.relationType == RelationType.me;

  String _normalizeText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final lower = trimmed.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
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

    return _ParsedEmojiAction(emoji: defaultEmoji, text: trimmed);
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

  String _relationLabel(RelationType relation) {
    switch (relation) {
      case RelationType.me:
        return 'Я';
      case RelationType.partner:
        return 'Партнёр';
      case RelationType.friend:
        return 'Друг';
      case RelationType.parent:
        return 'Родитель';
      case RelationType.child:
        return 'Ребёнок';
      case RelationType.colleague:
        return 'Коллега';
      case RelationType.other:
        return 'Другое';
    }
  }

  InputDecoration _decoration(
    BuildContext context,
    String label, {
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.secondaryText(context)),
      errorText: errorText,
      filled: true,
      fillColor: AppColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primaryText(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _toggleHelpful(String value) {
    if (value == 'Другое') {
      setState(() {
        final totalCount =
            _selectedHelpful.where((e) => e != 'Другое').length +
            _customHelpfulActions.length;

        if (totalCount >= 3) {
          _helpfulError = 'Максимум 3 варианта';
          return;
        }

        _customHelpfulActions.add(
          _CustomActionDraft(controller: TextEditingController(), emoji: '✨'),
        );

        _helpfulError = null;
      });
      return;
    }

    setState(() {
      if (_selectedHelpful.contains(value)) {
        _selectedHelpful.remove(value);
      } else {
        final totalCount =
            _selectedHelpful.where((e) => e != 'Другое').length +
            _customHelpfulActions.length;

        if (totalCount >= 3) {
          _helpfulError = 'Максимум 3 варианта';
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
        final totalCount =
            _selectedAvoid.where((e) => e != 'Другое').length +
            _customAvoidActions.length;

        if (totalCount >= 3) {
          _avoidError = 'Максимум 3 варианта';
          return;
        }

        _customAvoidActions.add(
          _CustomActionDraft(controller: TextEditingController(), emoji: '⚠️'),
        );

        _avoidError = null;
      });
      return;
    }

    setState(() {
      if (_selectedAvoid.contains(value)) {
        _selectedAvoid.remove(value);
      } else {
        final totalCount =
            _selectedAvoid.where((e) => e != 'Другое').length +
            _customAvoidActions.length;

        if (totalCount >= 3) {
          _avoidError = 'Максимум 3 варианта';
          return;
        }

        _selectedAvoid.add(value);
      }

      _avoidError = null;
    });
  }

  Widget _buildChipGroup({
    required BuildContext context,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = selectedValues.contains(option);

        return FilterChip(
          label: Text(option),
          selected: selected,
          onSelected: (_) => onToggle(option),
          selectedColor: AppColors.accent(context),
          backgroundColor: AppColors.surface(context),
          side: BorderSide.none,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.primaryText(context),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatarVariants(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final selected = _selectedAvatarVariant == index;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedAvatarVariant = index;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AppColors.accent(context)
                      : AppColors.border(context),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  PersonAvatar(
                    mood: _selectedMood,
                    gender: _selectedGender,
                    avatarVariant: index,
                    size: 74,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Вариант ${index + 1}',
                    style: TextStyle(color: AppColors.primaryText(context)),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _openLifeCycleScreen() async {
    final updated = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => cycle_screen.LifeCycleScreen(
          person: widget.person.copyWith(
            name: _nameController.text.trim(),
            mood: _selectedMood,
            gender: _selectedGender,
            avatarVariant: _selectedAvatarVariant,
          ),
        ),
      ),
    );

    if (updated == null) return;

    setState(() {
      _lifeCycleEnabled = updated.lifeCycleEnabled;
      _cycleStages = updated.cycleStages;
      _cycleStartDateIso = updated.cycleStartDateIso;
    });
  }

  List<String> _buildHelpfulActions() {
    final values = _selectedHelpful.toList();

    for (final item in _customHelpfulActions) {
      final custom = _normalizeText(item.controller.text);

      if (custom.isNotEmpty) {
        values.add(_buildStoredEmojiAction(emoji: item.emoji, text: custom));
      }
    }

    return values.take(3).toList();
  }

  List<String> _buildAvoidActions() {
    final values = _selectedAvoid.toList();

    for (final item in _customAvoidActions) {
      final custom = _normalizeText(item.controller.text);

      if (custom.isNotEmpty) {
        values.add(_buildStoredEmojiAction(emoji: item.emoji, text: custom));
      }
    }

    return values.take(3).toList();
  }

  Future<void> _pickEmoji({required bool isHelpful, required int index}) async {
    final emojis = isHelpful
        ? [
            '✨',
            '🤗',
            '💬',
            '📞',
            '🎁',
            '🍬',
            '🚶',
            '🤫',
            '🫶',
            '🌷',
            '☕️',
            '🎧',
          ]
        : ['⚠️', '🔊', '⚡', '🧱', '🚫', '⏩', '❗', '🙄', '⛔', '😤', '💢', '🛑'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card(context),
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
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
                      context,
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
                  onTap: () => _pickEmoji(isHelpful: isHelpful, index: i),
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
                const SizedBox(width: 6),
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
                      _helpfulError = 'Максимум 3 варианта';
                    } else {
                      _avoidError = 'Максимум 3 варианта';
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
                color: AppColors.secondaryText(context),
                size: 18,
              ),
              label: Text(
                'Добавить ещё',
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _normalizeText(_nameController.text);

    final helpfulActions = _buildHelpfulActions();
    final avoidActions = _buildAvoidActions();

    final hasEmptyHelpfulCustom = _customHelpfulActions.any(
      (item) => _normalizeText(item.controller.text).isEmpty,
    );

    final hasEmptyAvoidCustom = _customAvoidActions.any(
      (item) => _normalizeText(item.controller.text).isEmpty,
    );

    setState(() {
      _nameError = name.isEmpty ? 'Введите имя' : null;

      _helpfulError = helpfulActions.isEmpty || hasEmptyHelpfulCustom
          ? 'Заполни выбранные варианты'
          : null;

      _avoidError = avoidActions.isEmpty || hasEmptyAvoidCustom
          ? 'Заполни выбранные варианты'
          : null;
    });

    if (name.isEmpty ||
        helpfulActions.isEmpty ||
        avoidActions.isEmpty ||
        hasEmptyHelpfulCustom ||
        hasEmptyAvoidCustom) {
      return;
    }

    final updated = widget.person.copyWith(
      name: name,
      mood: _selectedMood,
      relationType: _isMyProfile ? RelationType.me : _selectedRelation,
      customRelationLabel: _selectedRelation == RelationType.other
          ? _normalizeText(_customRelationController.text)
          : null,
      gender: _selectedGender,
      avatarVariant: _selectedAvatarVariant,
      helpfulActions: helpfulActions,
      avoidActions: avoidActions,
      lifeCycleEnabled: _lifeCycleEnabled,
      cycleStages: _cycleStages,
      cycleStartDateIso: _cycleStartDateIso,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final showCustomRelation =
        !_isMyProfile && _selectedRelation == RelationType.other;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          'Редактировать',
          style: TextStyle(color: AppColors.primaryText(context)),
        ),
        actions: [
          if (widget.person.sourceType == SourceType.local)
            IconButton(
              onPressed: _openLifeCycleScreen,
              icon: Icon(
                Icons.autorenew_rounded,
                color: AppColors.primaryText(context),
              ),
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              'Сохранить',
              style: TextStyle(color: AppColors.primaryText(context)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PersonAvatar(
              mood: _selectedMood,
              gender: _selectedGender,
              avatarVariant: _selectedAvatarVariant,
              size: 270,
            ),
          ),

          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _decoration(context, 'Имя', errorText: _nameError),
          ),

          const SizedBox(height: 24),

          _sectionTitle(context, 'Пол'),

          DropdownButtonFormField<GenderType>(
            initialValue: _selectedGender,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _decoration(context, 'Пол'),
            items: GenderType.values.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(
                  gender == GenderType.male ? 'Мужчина' : 'Женщина',
                  style: TextStyle(color: AppColors.primaryText(context)),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedGender = value;
              });
            },
          ),

          const SizedBox(height: 24),

          _sectionTitle(context, 'Аватар'),
          _buildAvatarVariants(context),

          const SizedBox(height: 24),

          DropdownButtonFormField<MoodType>(
            initialValue: _selectedMood,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _decoration(context, 'Настрой'),
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
              if (value == null) return;
              setState(() {
                _selectedMood = value;
              });
            },
          ),

          if (!_isMyProfile) ...[
            const SizedBox(height: 24),

            DropdownButtonFormField<RelationType>(
              initialValue: _selectedRelation,
              dropdownColor: AppColors.surface(context),
              style: TextStyle(color: AppColors.primaryText(context)),
              decoration: _decoration(context, 'Кто это тебе'),
              items: RelationType.values.where((r) => r != RelationType.me).map(
                (relation) {
                  return DropdownMenuItem(
                    value: relation,
                    child: Text(
                      _relationLabel(relation),
                      style: TextStyle(color: AppColors.primaryText(context)),
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRelation = value;
                  if (_selectedRelation != RelationType.other) {
                    _customRelationController.clear();
                  }
                });
              },
            ),
          ],

          if (showCustomRelation) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customRelationController,
              style: TextStyle(color: AppColors.primaryText(context)),
              decoration: _decoration(context, 'Своя категория'),
            ),
          ],

          const SizedBox(height: 28),

          _sectionTitle(context, 'Что помогает'),
          _buildChipGroup(
            context: context,
            options: _helpfulOptions,
            selectedValues: _selectedHelpful,
            onToggle: _toggleHelpful,
          ),
          _buildCustomActionFields(
            items: _customHelpfulActions,
            isHelpful: true,
          ),

          if (_helpfulError != null) ...[
            const SizedBox(height: 8),
            Text(
              _helpfulError!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],

          const SizedBox(height: 28),

          _sectionTitle(context, 'Что лучше не делать'),
          _buildChipGroup(
            context: context,
            options: _avoidOptions,
            selectedValues: _selectedAvoid,
            onToggle: _toggleAvoid,
          ),
          _buildCustomActionFields(
            items: _customAvoidActions,
            isHelpful: false,
          ),

          if (_avoidError != null) ...[
            const SizedBox(height: 8),
            Text(_avoidError!, style: const TextStyle(color: Colors.redAccent)),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ParsedEmojiAction {
  final String emoji;
  final String text;

  const _ParsedEmojiAction({required this.emoji, required this.text});
}

class _CustomActionDraft {
  final TextEditingController controller;
  String emoji;

  _CustomActionDraft({required this.controller, required this.emoji});
}
