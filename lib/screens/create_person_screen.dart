import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/person.dart';
import '../widgets/person_avatar.dart';

class CreatePersonScreen extends StatefulWidget {
  const CreatePersonScreen({super.key});

  @override
  State<CreatePersonScreen> createState() => _CreatePersonScreenState();
}

class _CreatePersonScreenState extends State<CreatePersonScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customRelationController =
      TextEditingController();
final List<_CustomActionDraft> _customHelpfulActions = [];
final List<_CustomActionDraft> _customAvoidActions = [];

  MoodType _selectedMood = MoodType.calm;
  RelationType _selectedRelation = RelationType.friend;
  GenderType _selectedGender = GenderType.male;
  int _selectedAvatarVariant = 0;

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

  String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _moodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Радостный';
      case MoodType.calm:
        return 'Спокойный';
      case MoodType.sad:
        return 'Грустный';
      case MoodType.irritated:
        return 'Раздражённый';
      case MoodType.tired:
        return 'Уставший';
      case MoodType.needsCare:
        return 'Нужна забота';
    }
  }

  String _relationLabel(RelationType relation) {
    switch (relation) {
      case RelationType.partner:
        return 'Партнер';
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
      case RelationType.me:
        return 'Я';
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primaryText(context),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chip(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent(context)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.primaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

List<String> _buildHelpfulActions() {
    final values = _selectedHelpful.where((e) => e != 'Другое').toList();

    for (final item in _customHelpfulActions) {
      final custom = _normalize(item.controller.text);
      if (custom.isNotEmpty) {
        values.add('emoji::${item.emoji}::$custom');
      }
    }

    return values.take(3).toList();
  }

  List<String> _buildAvoidActions() {
    final values = _selectedAvoid.where((e) => e != 'Другое').toList();

    for (final item in _customAvoidActions) {
      final custom = _normalize(item.controller.text);
      if (custom.isNotEmpty) {
        values.add('emoji::${item.emoji}::$custom');
      }
    }

    return values.take(3).toList();
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
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Свой вариант ${i + 1}',
                    errorText: i == items.length - 1 ? errorText : null,
                    filled: true,
                    fillColor: AppColors.surface(context),
                    labelStyle: TextStyle(
                      color: AppColors.secondaryText(context),
                    ),
                    counterStyle: TextStyle(
                      color: AppColors.subtleText(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
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
        if (_selectedHelpful.length + _customHelpfulActions.length < 3 &&
            isHelpful)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _customHelpfulActions.add(
                    _CustomActionDraft(
                      controller: TextEditingController(),
                      emoji: '✨',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить ещё'),
            ),
          ),
        if (_selectedAvoid.length + _customAvoidActions.length < 3 &&
            !isHelpful)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _customAvoidActions.add(
                    _CustomActionDraft(
                      controller: TextEditingController(),
                      emoji: '⚠️',
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить ещё'),
            ),
          ),
      ],
    ),
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

  void _save() {
    final name = _nameController.text.trim();

    final helpful = _buildHelpfulActions();
    final avoid = _buildAvoidActions();

    setState(() {
      _nameError = name.isEmpty ? 'Введите имя' : null;
      _helpfulError =
          helpful.isEmpty ? 'Выберите хотя бы 1 вариант' : null;
      _avoidError =
          avoid.isEmpty ? 'Выберите хотя бы 1 вариант' : null;
    });

    if (_nameError != null ||
        _helpfulError != null ||
        _avoidError != null) {
      return;
    }

    final person = Person(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      publicId: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      gender: _selectedGender,
      avatarVariant: _selectedAvatarVariant,
      mood: _selectedMood,
      helpfulActions: helpful,
      avoidActions: avoid,
      relationType: _selectedRelation,
      sourceType: SourceType.local,
      customRelationLabel:
          _selectedRelation == RelationType.other
              ? _normalize(_customRelationController.text)
              : null,
    );

    Navigator.pop(context, person);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          'Новый человек',
          style: TextStyle(
            color: AppColors.primaryText(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Сохранить',
              style: TextStyle(
                color: AppColors.accent(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: PersonAvatar(
              mood: _selectedMood,
              gender: _selectedGender,
              avatarVariant: _selectedAvatarVariant,
              size: 170,
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            style: TextStyle(
              color: AppColors.primaryText(context),
            ),
            decoration: InputDecoration(
              hintText: 'Имя',
              errorText: _nameError,
            ),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Пол'),

          Wrap(
            spacing: 10,
            children: [
              _chip(
                'Мужчина',
                _selectedGender == GenderType.male,
                () {
                  setState(() {
                    _selectedGender = GenderType.male;
                  });
                },
              ),
              _chip(
                'Женщина',
                _selectedGender == GenderType.female,
                () {
                  setState(() {
                    _selectedGender = GenderType.female;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          _sectionTitle('Настрой'),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MoodType.values.map((mood) {
              return _chip(
                _moodLabel(mood),
                _selectedMood == mood,
                () {
                  setState(() {
                    _selectedMood = mood;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Внешность'),

          Row(
            children: List.generate(3, (index) {
              final selected =
                  _selectedAvatarVariant == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarVariant = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index == 2 ? 0 : 10,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent(context)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: PersonAvatar(
                      mood: _selectedMood,
                      gender: _selectedGender,
                      avatarVariant: index,
                      size: 70,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Что помогает'),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _helpfulOptions.map((item) {
              final selected = _selectedHelpful.contains(item);

              return _chip(
                item,
                selected,
                () {
                  setState(() {
                    if (item == 'Другое') {
                      final total = _selectedHelpful.length + _customHelpfulActions.length;

                      if (total < 3) {
                        _customHelpfulActions.add(
                          _CustomActionDraft(
                            controller: TextEditingController(),
                            emoji: '✨',
                          ),
                        );
                        _helpfulError = null;
                      } else {
                        _helpfulError = 'Можно выбрать максимум 3 варианта';
                      }

                      return;
                    }

                    if (selected) {
                      _selectedHelpful.remove(item);
                    } else if (_selectedHelpful.length + _customHelpfulActions.length < 3) {
                      _selectedHelpful.add(item);
                      _helpfulError = null;
                    } else {
                      _helpfulError = 'Можно выбрать максимум 3 варианта';
                    }
                  });
                },
              );
            }).toList(),
          ),

          _buildCustomActionFields(
            items: _customHelpfulActions,
            isHelpful: true,
          ),

          if (_helpfulError != null) ...[
            const SizedBox(height: 8),
            Text(
              _helpfulError!,
              style: const TextStyle(
                color: Colors.red,
              ),
            )
          ],

          const SizedBox(height: 28),

          _sectionTitle('Что лучше не делать'),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _avoidOptions.map((item) {
              final selected = _selectedAvoid.contains(item);

              return _chip(
                item,
                selected,
                () {
                  setState(() {
                    if (item == 'Другое') {
                      final total = _selectedAvoid.length + _customAvoidActions.length;

                      if (total < 3) {
                        _customAvoidActions.add(
                          _CustomActionDraft(
                            controller: TextEditingController(),
                            emoji: '⚠️',
                          ),
                        );
                        _avoidError = null;
                      } else {
                        _avoidError = 'Можно выбрать максимум 3 варианта';
                      }

                      return;
                    }

                    if (selected) {
                      _selectedAvoid.remove(item);
                    } else if (_selectedAvoid.length + _customAvoidActions.length < 3) {
                      _selectedAvoid.add(item);
                      _avoidError = null;
                    } else {
                      _avoidError = 'Можно выбрать максимум 3 варианта';
                    }
                  });
                },
              );
            }).toList(),
          ),

          _buildCustomActionFields(
            items: _customAvoidActions,
            isHelpful: false,
          ),

          if (_avoidError != null) ...[
            const SizedBox(height: 8),
            Text(
              _avoidError!,
              style: const TextStyle(
                color: Colors.red,
              ),
            )
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
class _CustomActionDraft {
  final TextEditingController controller;
  String emoji;

  _CustomActionDraft({
    required this.controller,
    required this.emoji,
  });
}