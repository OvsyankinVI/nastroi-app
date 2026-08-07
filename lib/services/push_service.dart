import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenSubscription;

  static Future<void> initialize({
    required void Function(RemoteMessage) onOpen,
    required bool Function(String) isChatOpen,
    required Future<void> Function(RemoteMessage) showForeground,
  }) async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _tokenSubscription ??= _messaging.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen((message) {
        final threadId = message.data['thread_id']?.toString();
        if (threadId == null || !isChatOpen(threadId)) {
          unawaited(showForeground(message));
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen(onOpen);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) onOpen(initial);

      try {
        await _saveToken(await _messaging.getToken());
      } catch (error, stack) {
        // Push delivery can still be handled while a migration or token write is
        // temporarily unavailable.
        await FirebaseCrashlytics.instance.recordError(error, stack);
      }
    } catch (error, stack) {
      await FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }

  static Future<void> _saveToken(String? token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (token == null || user == null) return;
    await Supabase.instance.client
        .from('user_push_tokens')
        .upsert({
          'user_id': user.id,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'token')
        .timeout(const Duration(seconds: 12));
  }

  static Future<void> removeCurrentToken() async {
    final token = await _messaging.getToken();
    final user = Supabase.instance.client.auth.currentUser;
    if (token != null && user != null) {
      await Supabase.instance.client
          .from('user_push_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token)
          .timeout(const Duration(seconds: 10));
    }
  }

  static Future<void> registerCurrentToken() async {
    await _saveToken(await _messaging.getToken());
  }
}
