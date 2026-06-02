import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/person.dart';
import '../services/remote_people_service.dart';
import '../utils/person_link.dart';

class ImportPersonScreen extends StatefulWidget {
  const ImportPersonScreen({super.key});

  @override
  State<ImportPersonScreen> createState() => _ImportPersonScreenState();
}

class _ImportPersonScreenState extends State<ImportPersonScreen> {
  final TextEditingController _codeController = TextEditingController();

  String? errorText;
  bool isLoading = false;

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
    required VoidCallback? onPressed,
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
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _import() async {
    final raw = _codeController.text.trim();

    if (raw.isEmpty) {
      setState(() {
        errorText = 'Вставь ссылку или код';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final publicId = tryParsePublicIdFromRaw(raw);

      if (publicId != null) {
        final person =
            await RemotePeopleService.findPublicPersonByPublicId(publicId);

        if (!mounted) return;

        if (person == null) {
          setState(() {
            errorText = 'Профиль не найден';
            isLoading = false;
          });
          return;
        }

        Navigator.pop(context, person);
        return;
      }

      final person = tryParsePersonFromRaw(raw);

      if (!mounted) return;

      if (person == null) {
        setState(() {
          errorText = 'Ссылка или код не распознаны';
          isLoading = false;
        });
        return;
      }

      Navigator.pop(context, person);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorText = 'Не удалось импортировать профиль';
        isLoading = false;
      });
    }
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
            onPressed: isLoading ? null : _import,
          ),
        ],
      ),
    );
  }
}