import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../utils/person_link.dart';

class ImportPersonScreen extends StatefulWidget {
  const ImportPersonScreen({super.key});

  @override
  State<ImportPersonScreen> createState() => _ImportPersonScreenState();
}

class _ImportPersonScreenState extends State<ImportPersonScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _import() {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        errorText = 'Вставь ссылку или код';
      });
      return;
    }

    final person = tryParsePersonFromRaw(raw);

    if (person == null) {
      setState(() {
        errorText = 'Ссылка или код не распознаны';
      });
      return;
    }

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
          'Импорт по коду',
          style: TextStyle(color: AppColors.primaryText(context)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Вставь ссылку или код, который тебе прислали. Мы распознаем профиль и добавим человека в список.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            minLines: 6,
            maxLines: 10,
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _decoration('Ссылка или код профиля'),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            title: 'Импортировать',
            onPressed: _import,
          ),
        ],
      ),
    );
  }
}