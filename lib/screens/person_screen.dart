import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_colors.dart';
import '../models/person.dart';
import '../utils/person_link.dart';
import '../widgets/person_avatar.dart';
import 'edit_person_screen.dart' as edit_screen;

import '../services/auth_service.dart';

enum ReactionType {
  warm,
  communication,
  calm,
  negative,
  toxic,
}

class PersonScreen extends StatefulWidget {
  final Person person;
  final ValueChanged<Person> onPersonUpdated;
  final Future<void> Function()? onPersonDeleted;
  final Future<void> Function()? onTogglePin;
  final bool isEditable;
  final bool isMyProfile;

  const PersonScreen({
    super.key,
    required this.person,
    required this.onPersonUpdated,
    required this.isEditable,
    required this.isMyProfile,
    this.onPersonDeleted,
    this.onTogglePin,
  });

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _FlyingReactionEmoji {
  final String emoji;
  final double angle;
  final double distance;
  final double size;
  final String id;

  const _FlyingReactionEmoji({
    required this.emoji,
    required this.angle,
    required this.distance,
    required this.size,
    required this.id,
  });
}

class _PersonScreenState extends State<PersonScreen>
    with TickerProviderStateMixin {
  late Person currentPerson;
  late final ScrollController _cycleDaysController;

  double _reactionScale = 1.0;
  double _reactionRotation = 0.0;
  double _reactionVerticalOffset = 0.0;
  double _shakeX = 0.0;

  bool isFabMenuOpen = false;

    void _toggleFabMenu() {
    setState(() {
      isFabMenuOpen = !isFabMenuOpen;
    });
  }

  void _closeFabMenu() {
    if (!isFabMenuOpen) return;
    setState(() => isFabMenuOpen = false);
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
  final actions = <Widget>[];

  if (widget.isEditable) {
    actions.add(
      _buildMiniActionButton(
        heroTag: 'person_edit_action',
        icon: Icons.edit_outlined,
        onTap: () {
          _closeFabMenu();
          _openEditScreen();
        },
      ),
    );
  }

  actions.add(
    _buildMiniActionButton(
      heroTag: 'person_share_action',
      icon: Icons.share,
      onTap: () {
        _closeFabMenu();
        _showShareDialog();
      },
    ),
  );

  if (widget.onPersonDeleted != null) {
    actions.add(
      _buildMiniActionButton(
        heroTag: 'person_delete_action',
        icon: Icons.delete_outline,
        onTap: () {
          _closeFabMenu();
          _confirmDelete();
        },
      ),
    );
  }

  if (widget.isMyProfile) {
    actions.add(
      _buildMiniActionButton(
        heroTag: 'person_logout_action',
        icon: Icons.logout_rounded,
        onTap: () {
          _closeFabMenu();
          _confirmLogout();
        },
      ),
    );
  }

  const radius = 78.0;
  const startAngle = -90.0;
  const endAngle = -180.0;

  return SizedBox(
    width: 190,
    height: 190,
    child: Stack(
      alignment: Alignment.bottomRight,
      children: [
        for (int i = 0; i < actions.length; i++)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            right: isFabMenuOpen
                ? _fabOffsetX(
                    index: i,
                    count: actions.length,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                  )
                : 0,
            bottom: isFabMenuOpen
                ? _fabOffsetY(
                    index: i,
                    count: actions.length,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                  )
                : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isFabMenuOpen ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isFabMenuOpen,
                child: actions[i],
              ),
            ),
          ),
        FloatingActionButton(
          heroTag: 'person_main_actions',
          backgroundColor: AppColors.chip(context),
          elevation: 0,
          onPressed: _toggleFabMenu,
          child: Icon(
            isFabMenuOpen ? Icons.close : Icons.add,
            color: AppColors.primaryText(context),
          ),
        ),
      ],
    ),
  );
}

double _fabOffsetX({
  required int index,
  required int count,
  required double radius,
  required double startAngle,
  required double endAngle,
}) {
  if (count == 1) return 0;

  final angle = startAngle + (endAngle - startAngle) * (index / (count - 1));
  final radians = angle * math.pi / 180;

  return -math.cos(radians) * radius;
}

  double _fabOffsetY({
    required int index,
    required int count,
    required double radius,
    required double startAngle,
    required double endAngle,
  }) {
    if (count == 1) return radius;

    final angle = startAngle + (endAngle - startAngle) * (index / (count - 1));
    final radians = angle * math.pi / 180;

    return -math.sin(radians) * radius;
  }

  Color? _reactionOverlayColor;
  String? _activeRecommendationKey;

  late final AnimationController _floatController;
  late final AnimationController _shakeController;

  List<_FlyingReactionEmoji> _flyingEmojis = [];

Future<void> _confirmLogout() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Выйти из аккаунта?',
          style: TextStyle(
            color: AppColors.primaryText(context),
          ),
        ),
        content: Text(
          'Ты точно хочешь выйти?',
          style: TextStyle(
            color: AppColors.secondaryText(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ок'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await AuthService.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

  @override
  void initState() {
    _cycleDaysController = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCycleDaysToActive();
      });
    super.initState();
    currentPerson = widget.person;

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _shakeController.addListener(() {
      final value = _shakeController.value;
      final wave = math.sin(value * math.pi * 8);
      final fade = 1.0 - value;

      if (mounted) {
        setState(() {
          _shakeX = wave * 10 * fade;
        });
      }
    });

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _shakeX = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shakeController.dispose();
    super.dispose();
    _cycleDaysController.dispose();
  }
  void _scrollCycleDaysToActive() {
  if (!_cycleDaysController.hasClients) return;

  final totalDays = _totalCycleDays;
  if (totalDays <= 0) return;

  final activeIndex = _activeCycleDay - 1;
  const itemWidth = 40.0;
  const separatorWidth = 7.0;
  final screenWidth = MediaQuery.of(context).size.width;

  final targetOffset =
      activeIndex * (itemWidth + separatorWidth) - screenWidth / 2 + itemWidth / 2;

  final maxOffset = _cycleDaysController.position.maxScrollExtent;

  _cycleDaysController.jumpTo(
    targetOffset.clamp(0.0, maxOffset),
  );
}

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int get _totalCycleDays {
    return currentPerson.cycleStages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationDays,
    );
  }

CycleStage? get _activeCycleStage {
  if (!currentPerson.lifeCycleEnabled ||
      currentPerson.cycleStages.isEmpty) {
    return null;
  }

  final activeDay = _activeCycleDay;
  int passed = 0;

  for (final stage in currentPerson.cycleStages) {
    passed += stage.durationDays;

    if (activeDay <= passed) {
      return stage;
    }
  }

  return null;
}

  int get _activeCycleDay {
    final totalDays = _totalCycleDays;
    if (totalDays <= 0) return 1;

    final startDate = currentPerson.cycleStartDateIso != null
        ? DateTime.tryParse(currentPerson.cycleStartDateIso!)
        : null;

    final normalizedStart = _dateOnly(startDate ?? DateTime.now());
    final normalizedToday = _dateOnly(DateTime.now());

    final diff = normalizedToday.difference(normalizedStart).inDays;
    final safeDiff = diff < 0 ? 0 : diff;
    final dayIndex = safeDiff % totalDays;

    return dayIndex + 1;
  }

  Color _cycleDayColor(int dayNumber) {
    int passed = 0;

    for (final stage in currentPerson.cycleStages) {
      passed += stage.durationDays;
      if (dayNumber <= passed) {
        return _glowColor(stage.mood);
      }
    }

    return _glowColor(currentPerson.mood);
  }

  Widget _buildCycleDays() {
    if (!currentPerson.lifeCycleEnabled || currentPerson.cycleStages.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalDays = _totalCycleDays;
    if (totalDays <= 0) return const SizedBox.shrink();

    final activeDay = _activeCycleDay;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          controller: _cycleDaysController,
          scrollDirection: Axis.horizontal,
          itemCount: totalDays,
          separatorBuilder: (context, index) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final dayNumber = index + 1;
            final isActive = dayNumber == activeDay;
            final color = _cycleDayColor(dayNumber);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 40 : 34,
              height: isActive ? 40 : 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isActive ? 0.90 : 0.55),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isActive
                      ? AppColors.primaryText(context)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.32),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: isActive ? 16 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveCycleStageLabel() {
  final stage = _activeCycleStage;

  if (stage == null) {
    return const SizedBox.shrink();
  }

  final accent = _glowColor(stage.mood);

  final title = stage.title.trim().isNotEmpty
      ? stage.title
      : _moodTitle(stage.mood);

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Сейчас этап: ',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  _ParsedEmojiAction _parseEmojiAction(
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

  String _visibleActionText(String value) {
    if (value.trim().startsWith('emoji::')) {
      return _parseEmojiAction(value, defaultEmoji: '✨').text;
    }
    return value;
  }

  ReactionType _getReactionType(String text, bool isPositive) {
    final value = _visibleActionText(text).toLowerCase();

    if (!isPositive) {
      if (value.contains('игнор') || value.contains('критик')) {
        return ReactionType.toxic;
      }
      return ReactionType.negative;
    }

    if (value.contains('обнять') ||
        value.contains('поддерж') ||
        value.contains('подар')) {
      return ReactionType.warm;
    }

    if (value.contains('позвон') || value.contains('напис')) {
      return ReactionType.communication;
    }

    if (value.contains('тиш') || value.contains('прогул')) {
      return ReactionType.calm;
    }

    return ReactionType.warm;
  }

  void _spawnFlyingEmojis() {
    final random = math.Random();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (currentPerson.gender == GenderType.male) {
      final thumbs = List.generate(20, (index) {
        return _FlyingReactionEmoji(
          emoji: '👍',
          angle: (-160 + random.nextInt(320)).toDouble(),
          distance: 75 + random.nextInt(95).toDouble(),
          size: 24 + random.nextInt(14).toDouble(),
          id: '${now}_$index',
        );
      });

      setState(() {
        _flyingEmojis = thumbs;
      });
    } else {
      final heartsPool = ['❤️', '🩷', '🧡', '💛'];

      final hearts = List.generate(25, (index) {
        return _FlyingReactionEmoji(
          emoji: heartsPool[random.nextInt(heartsPool.length)],
          angle: (-160 + random.nextInt(320)).toDouble(),
          distance: 80 + random.nextInt(100).toDouble(),
          size: 22 + random.nextInt(18).toDouble(),
          id: '${now}_$index',
        );
      });

      setState(() {
        _flyingEmojis = hearts;
      });
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _flyingEmojis.clear();
      });
    });
  }

  Future<void> _playReaction({
    required ReactionType type,
    required String key,
  }) async {
    if (type == ReactionType.negative || type == ReactionType.toxic) {
      await HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    }

    final isPositive = type == ReactionType.warm ||
        type == ReactionType.communication ||
        type == ReactionType.calm;

    if (isPositive) {
      _spawnFlyingEmojis();
    }

    setState(() {
      _activeRecommendationKey = key;

      switch (type) {
        case ReactionType.warm:
          _reactionScale = 1.14;
          _reactionRotation = -0.010;
          _reactionVerticalOffset = -4;
          _reactionOverlayColor =
              const Color(0xFFFF7EB6).withValues(alpha: 0.28);
          break;

        case ReactionType.communication:
          _reactionScale = 1.10;
          _reactionRotation = 0.0;
          _reactionVerticalOffset = -2;
          _reactionOverlayColor =
              const Color(0xFF67B7FF).withValues(alpha: 0.22);
          break;

        case ReactionType.calm:
          _reactionScale = 1.06;
          _reactionRotation = 0.0;
          _reactionVerticalOffset = -1;
          _reactionOverlayColor =
              const Color(0xFF6FCF97).withValues(alpha: 0.18);
          break;

        case ReactionType.negative:
          _reactionScale = 1.04;
          _reactionRotation = 0.018;
          _reactionVerticalOffset = 2;
          _reactionOverlayColor =
              const Color(0xFFFF6B6B).withValues(alpha: 0.24);
          break;

        case ReactionType.toxic:
          _reactionScale = 1.02;
          _reactionRotation = 0.026;
          _reactionVerticalOffset = 4;
          _reactionOverlayColor =
              const Color(0xFFFF3B30).withValues(alpha: 0.34);
          break;
      }
    });

    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() {
        _reactionScale = 1.0;
        _reactionRotation = 0.0;
        _reactionVerticalOffset = 0.0;
        _reactionOverlayColor = null;
        _activeRecommendationKey = null;
      });
    });
  }

String _recommendationEmoji(String text, bool positive) {
  final parsed = _parseEmojiAction(
    text,
    defaultEmoji: positive ? '✨' : '⚠️',
  );

  if (text.trim().startsWith('emoji::')) {
    return parsed.emoji;
  }

  final value = parsed.text.trim();

  const map = {
    'Обнять': '🤗',
    'Написать': '💬',
    'Позвонить': '📞',
    'Подарок': '🎁',
    'Сладкое': '🍬',
    'Прогулка': '🚶',
    'Тишина': '🤫',
    'Поддержка': '🫶',

    'Спорить': '⚡',
    'Давить': '🧱',
    'Игнорировать': '🚫',
    'Шутить': '🙄',
    'Торопить': '⏩',
    'Критиковать': '❗',
    'Шуметь': '🔊',
    'Навязываться': '⛔',
  };

  return map[value] ?? (positive ? '✨' : '⚠️');
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

  String _moodTitle(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'В хорошем настроении';
      case MoodType.calm:
        return 'Спокойное состояние';
      case MoodType.sad:
        return 'Немного грустно';
      case MoodType.irritated:
        return 'Раздражённое состояние';
      case MoodType.tired:
        return 'Усталость';
      case MoodType.needsCare:
        return 'Нужна забота';
    }
  }

  String _moodHint(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Хороший момент для общения, шуток и совместных планов.';
      case MoodType.calm:
        return 'Можно общаться спокойно, без давления и перегруза.';
      case MoodType.sad:
        return 'Лучше проявить мягкость, внимание и не нагружать лишним.';
      case MoodType.irritated:
        return 'Сейчас лучше не спорить и не давить. Немного пространства поможет.';
      case MoodType.tired:
        return 'Лучше снизить нагрузку, помочь с делами или дать отдохнуть.';
      case MoodType.needsCare:
        return 'Хороший момент для тепла, поддержки, заботы или маленького жеста.';
    }
  }

  List<_RecommendationItemData> _buildAlternatingRecommendations() {
    final positives = currentPerson.helpfulActions.take(3).toList();
    final negatives = currentPerson.avoidActions.take(3).toList();

    final result = <_RecommendationItemData>[];
    final maxLen = math.max(positives.length, negatives.length);

    for (int i = 0; i < maxLen; i++) {
      if (i < positives.length) {
        result.add(
          _RecommendationItemData(
            text: positives[i],
            isPositive: true,
          ),
        );
      }

      if (i < negatives.length) {
        result.add(
          _RecommendationItemData(
            text: negatives[i],
            isPositive: false,
          ),
        );
      }
    }

    return result;
  }

  Offset _floatingOffset(int index) {
    final t = _floatController.value * 2 * math.pi;
    final phase = index * 0.85;

    final dx = math.sin(t + phase) * 0.9;
    final dy = math.cos((t * 0.9) + phase) * 1.4;

    return Offset(dx, dy);
  }

  List<Widget> _buildFlyingEmojiWidgets() {
    return _flyingEmojis.map((item) {
      final radians = item.angle * math.pi / 180;
      final dx = math.cos(radians) * item.distance;
      final dy = math.sin(radians) * item.distance;

      return TweenAnimationBuilder<double>(
        key: ValueKey(item.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Positioned(
            left: MediaQuery.of(context).size.width / 2 - 30 + dx * value,
            top: 210 + dy * value - (30 * value),
            child: Opacity(
              opacity: (1 - value).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + (value * 0.5),
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: item.size),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildRecommendationOrbit({
    required double centerYOffset,
  }) {
    final items = _buildAlternatingRecommendations();
    if (items.isEmpty) return const [];

    const startDeg = 180.0;
    const endDeg = 0.0;
    const radiusX = 180.0;
    const radiusY = 200.0;

    return List.generate(items.length, (index) {
      final item = items[index];
      final progress = items.length == 1 ? 0.5 : index / (items.length - 1);
      final angleDeg = startDeg + (endDeg - startDeg) * progress;
      final angleRad = angleDeg * math.pi / 180.0;

      final baseDx = math.cos(angleRad) * radiusX;
      final baseDy = -math.sin(angleRad) * radiusY;
      final drift = _floatingOffset(index);

      final key = '${item.isPositive ? 'p' : 'n'}_${index}_${item.text}';

      return Transform.translate(
        offset: Offset(
          baseDx + drift.dx,
          centerYOffset + baseDy + drift.dy,
        ),
        child: _RecommendationBubble(
          text: _visibleActionText(item.text),
          emoji: _recommendationEmoji(item.text, item.isPositive),
          isPositive: item.isPositive,
          isActive: _activeRecommendationKey == key,
          onTap: () {
            _playReaction(
              type: _getReactionType(item.text, item.isPositive),
              key: key,
            );
          },
        ),
      );
    });
  }

  Widget _primaryButton({
    required String title,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.accent(context),
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showShareDialog() async {
    final personLink = buildPersonLink(currentPerson);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Поделиться профилем',
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Поделись ссылкой или покажи QR-код. Сейчас ссылку можно вставить в импорт вручную, а следующим шагом мы подключим прямое открытие профиля по нажатию.',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: personLink,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ID: ${currentPerson.publicId}',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              _primaryButton(
                title: 'Скопировать ссылку',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: personLink));
                  if (!mounted) return;
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditScreen() async {
    final updated = await Navigator.push<Person>(
      context,
      MaterialPageRoute(
        builder: (_) => edit_screen.EditPersonScreen(person: currentPerson),
      ),
    );

    if (updated != null) {
      setState(() {
        currentPerson = updated;
      });
      widget.onPersonUpdated(updated);
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.onPersonDeleted == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card(context),
          title: Text(
            'Удалить человека?',
            style: TextStyle(
              color: AppColors.primaryText(context),
            ),
          ),
          content: Text(
            '“${currentPerson.name}” будет удалён из твоего списка.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.onPersonDeleted!.call();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _glowColor(currentPerson.mood);

    final backgroundColor = AppColors.background(context);
    final primaryText = AppColors.primaryText(context);
    final secondaryText = AppColors.secondaryText(context);
    final iconColor = AppColors.secondaryText(context);
    final accent = AppColors.accent(context);

WidgetsBinding.instance.addPostFrameCallback((_) {
  _scrollCycleDaysToActive();
});

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: _buildFabMenu(),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          currentPerson.name,
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_floatController, _shakeController]),
        builder: (context, child) {
          const characterCenterYOffset = 58.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 520,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      ..._buildRecommendationOrbit(
                        centerYOffset: characterCenterYOffset - 12,
                      ),
                      ..._buildFlyingEmojiWidgets(),
                      Transform.translate(
                        offset: Offset(
                          _shakeX,
                          characterCenterYOffset + _reactionVerticalOffset,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          width: 360,
                          height: 360,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _reactionOverlayColor,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.avatarGlow(glowColor, context),
                                AppColors.avatarGlowSoft(glowColor, context),
                                Colors.transparent,
                              ],
                              stops: const [0.24, 0.56, 1.0],
                            ),
                          ),
                          child: AnimatedScale(
                            scale: _reactionScale,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: AnimatedRotation(
                              turns: _reactionRotation,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: PersonAvatar(
                                mood: currentPerson.mood,
                                gender: currentPerson.gender,
                                avatarVariant: currentPerson.avatarVariant,
                                size: 300,
                                isMyProfile: widget.isMyProfile,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: _badge(
                    currentPerson.relationDisplayName,
                    accent.withValues(alpha: 0.15),
                    accent,
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 12),
                Text(
                  widget.isMyProfile
                      ? 'Мой настрой'
                      : _moodTitle(currentPerson.mood),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _moodHint(currentPerson.mood),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                _buildCycleDays(),
                _buildActiveCycleStageLabel(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecommendationItemData {
  final String text;
  final bool isPositive;

  const _RecommendationItemData({
    required this.text,
    required this.isPositive,
  });
}

class _ParsedEmojiAction {
  final String emoji;
  final String text;

  const _ParsedEmojiAction({
    required this.emoji,
    required this.text,
  });
}

class _RecommendationBubble extends StatelessWidget {
  final String text;
  final String emoji;
  final bool isPositive;
  final bool isActive;
  final VoidCallback onTap;

  const _RecommendationBubble({
    required this.text,
    required this.emoji,
    required this.isPositive,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isPositive ? const Color(0xFF6FCF97) : const Color(0xFFFF6B6B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: isActive ? 10 : 8,
                      sigmaY: isActive ? 10 : 8,
                    ),
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            accent.withValues(alpha: isActive ? 0.24 : 0.16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(
                              alpha: isActive ? 0.24 : 0.14,
                            ),
                            blurRadius: isActive ? 22 : 16,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 84,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

