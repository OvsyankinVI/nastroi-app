import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoginMode = true;
  bool isLoading = false;
  String? errorText;

String _authErrorMessage(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('email not confirmed')) {
    return 'Подтверди email по ссылке из письма или отключи подтверждение email в Supabase';
  }

  if (text.contains('user already registered') ||
      text.contains('already registered') ||
      text.contains('user already exists')) {
    return 'Аккаунт с таким email уже существует';
  }

  if (text.contains('invalid login credentials')) {
    return 'Неверный email или пароль';
  }

  if (text.contains('signup disabled')) {
    return 'Регистрация сейчас отключена';
  }

  if (text.contains('password')) {
    return 'Пароль должен быть длиннее';
  }

  if (text.contains('invalid email') ||
      text.contains('email address')) {
    return 'Проверь формат email';
  }

  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('connection')) {
    return 'Нет соединения с интернетом';
  }

  return 'Что-то пошло не так. Попробуй ещё раз';
}

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      if (isLoginMode) {
        await AuthService.signIn(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        await AuthService.signUp(
          email: emailController.text,
          password: passwordController.text,
        );
      }
    } catch (error) {
        setState(() {
            errorText = _authErrorMessage(error);
        });
        } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Настрой',
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLoginMode
                        ? 'Войди, чтобы синхронизировать близких'
                        : 'Создай аккаунт, чтобы делиться настроем',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.primaryText(context)),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.primaryText(context)),
                    decoration: const InputDecoration(labelText: 'Пароль'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isLoginMode ? 'Войти' : 'Зарегистрироваться'),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              isLoginMode = !isLoginMode;
                              errorText = null;
                            });
                          },
                    child: Text(
                      isLoginMode
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
    );
  }
}