import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/people_repository.dart';
import '../models/person.dart';
import 'person_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/remote_friends_service.dart';

class LinkPersonPreviewScreen extends StatefulWidget {
  final Person personFromLink;

  const LinkPersonPreviewScreen({super.key, required this.personFromLink});

  @override
  State<LinkPersonPreviewScreen> createState() =>
      _LinkPersonPreviewScreenState();
}

class _LinkPersonPreviewScreenState extends State<LinkPersonPreviewScreen> {
  late final PeopleRepository _repository;

  bool _isLoading = true;
  Person? _existingPerson;

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated');
    }

    _repository = PeopleRepository(userId: user.id);
    _loadExistingPerson();
  }

  Future<void> _loadExistingPerson() async {
    final people = await _repository.loadPeople();

    Person? existing;
    for (final person in people) {
      if (person.publicId == widget.personFromLink.publicId) {
        existing = person;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _existingPerson = existing;
      _isLoading = false;
    });
  }

  Future<void> _addPerson() async {
    try {
      await RemoteFriendsService.addFriendByPublicId(
        widget.personFromLink.publicId,
      );

      final people = await _repository.loadPeople();

      final alreadyExists = people.any(
        (person) => person.publicId == widget.personFromLink.publicId,
      );

      if (!alreadyExists) {
        people.add(widget.personFromLink);
        await _repository.savePeople(people);
      }

      if (!mounted) return;

      setState(() {
        _existingPerson = widget.personFromLink;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Человек добавлен')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendErrorMessage(error))));
    }
  }

  String _friendErrorMessage(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('самого себя')) {
      return 'Нельзя добавить самого себя';
    }

    if (text.contains('не найден')) {
      return 'Профиль не найден';
    }

    return 'Не удалось добавить человека';
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

  String _emoji(MoodType mood) {
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

  Widget _primaryButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.chip(context),
          foregroundColor: AppColors.primaryText(context),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.secondaryText(context),
          ),
        ),
      );
    }

    if (_existingPerson != null) {
      return PersonScreen(
        person: _existingPerson!,
        onPersonUpdated: (_) {},
        isEditable: false,
        isMyProfile: false,
        onPersonDeleted: null,
        onTogglePin: null,
      );
    }

    final person = widget.personFromLink;
    final glowColor = _glowColor(person.mood);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          'Профиль по ссылке',
          style: TextStyle(color: AppColors.primaryText(context)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 220,
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.avatarGlow(glowColor, context),
                    AppColors.avatarGlowSoft(glowColor, context),
                    Colors.transparent,
                  ],
                  stops: const [0.25, 0.55, 1.0],
                ),
              ),
              child: Text(
                _emoji(person.mood),
                style: const TextStyle(fontSize: 96),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              person.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _relationLabel(person.relationType),
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 15,
              ),
            ),
            const Spacer(),
            _primaryButton(title: 'Добавить', onPressed: _addPerson),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
