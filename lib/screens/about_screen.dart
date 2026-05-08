import 'package:flutter/material.dart';

import '../app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.primaryText(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.secondaryText(context),
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '• ',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          'Как пользоваться',
          style: TextStyle(
            color: AppColors.primaryText(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _paragraph(
            context,
            'Настрой помогает хранить профили близких людей, видеть их текущее состояние и быстро понимать — что сейчас лучше сделать, а чего лучше избегать.',
          ),

          _sectionTitle(context, 'С чего начать'),

          _bullet(
            context,
            'Нажми на свой аватар в правом верхнем углу, чтобы открыть свой профиль и изменить своё состояние.',
          ),

          _bullet(
            context,
            'Добавь человека вручную или импортируй его по ссылке / QR-коду.',
          ),

          _bullet(
            context,
            'Нажми на карточку человека, чтобы открыть его профиль.',
          ),

          _sectionTitle(context, 'Что можно делать'),

          _bullet(
            context,
            'Тапать на рекомендации вокруг персонажа и смотреть живые реакции.',
          ),

          _bullet(
            context,
            'Редактировать профили людей.',
          ),

          _bullet(
            context,
            'Настраивать циклы жизни: например 3 дня "спокойно", потом 2 дня "устал".',
          ),

          _bullet(
            context,
            'Менять активный день цикла вручную.',
          ),

          _bullet(
            context,
            'Делиться профилем через ссылку или QR.',
          ),

          _bullet(
            context,
            'Импортировать чужой профиль.',
          ),

          _sectionTitle(context, 'Важно'),

          _paragraph(
            context,
            'Это ранняя версия продукта. Сейчас все данные хранятся локально на устройстве.',
          ),

          _paragraph(
            context,
            'Дальше появятся: синхронизация, уведомления, совместные профили и более глубокая кастомизация персонажей.',
          ),
        ],
      ),
    );
  }
}