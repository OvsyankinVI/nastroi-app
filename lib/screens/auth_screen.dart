import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String _authErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('email not confirmed')) {
      return 'Подтверди email по ссылке из письма';
    }
    if (text.contains('already registered') ||
        text.contains('already exists')) {
      return 'Аккаунт с таким email уже существует';
    }
    if (text.contains('invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (text.contains('signup disabled')) return 'Регистрация сейчас отключена';
    if (text.contains('timeout') ||
        text.contains('network') ||
        text.contains('socket')) {
      return 'Нет соединения с интернетом. Попробуй ещё раз';
    }
    return 'Что-то пошло не так. Попробуй ещё раз';
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await AuthService.signIn(
          email: _email.text,
          password: _password.text,
        ).timeout(const Duration(seconds: 15));
        await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      } else {
        await AuthService.signUp(
          email: _email.text,
          password: _password.text,
        ).timeout(const Duration(seconds: 15));
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          const Positioned(
            top: -90,
            left: -70,
            child: _BlurBlob(color: Color(0xFFFF8CC8)),
          ),
          const Positioned(
            top: 150,
            right: -100,
            child: _BlurBlob(color: Color(0xFF8DCBFF)),
          ),
          const Positioned(
            bottom: -120,
            left: 60,
            child: _BlurBlob(color: Color(0xFF9C6BFF)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 82,
                              height: 82,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Настрой',
                            style: TextStyle(
                              color: AppColors.primaryText(context),
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Будь ближе к тем, кто важен',
                            style: TextStyle(
                              color: AppColors.secondaryText(context),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _email,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) =>
                                value != null &&
                                    RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                    ).hasMatch(value.trim())
                                ? null
                                : 'Введи корректный email',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            enabled: !_loading,
                            obscureText: _obscurePassword,
                            autofillHints: [
                              _isLogin
                                  ? AutofillHints.password
                                  : AutofillHints.newPassword,
                            ],
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onFieldSubmitted: _isLogin
                                ? (_) => _submit()
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 6
                                ? null
                                : 'Минимум 6 символов',
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmation,
                              enabled: !_loading,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Повтори пароль',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                              ),
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'Пароли не совпадают',
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Войти' : 'Зарегистрироваться',
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                    _isLogin = !_isLogin;
                                    _error = null;
                                  }),
                            child: Text(
                              _isLogin
                                  ? 'Нет аккаунта? Зарегистрироваться'
                                  : 'Уже есть аккаунт? Войти',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
    child: Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.22),
      ),
    ),
  );
}
