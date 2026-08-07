import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme_controller.dart';
import 'data/people_repository.dart';
import 'firebase_options.dart';
import 'screens/link_person_preview_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/person_screen.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'supabase_config.dart';
import 'utils/deep_link_guard.dart';
import 'utils/person_link.dart';
import 'widgets/auth_gate.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  try {
    await NotificationService.initialize().timeout(const Duration(seconds: 8));
    await PushService.initialize(
      onOpen: _routeChatPush,
      isChatOpen: (threadId) => activeChatThreadId.value == threadId,
      showForeground: (message) => NotificationService.showChatNotification(
        title: message.notification?.title ?? 'Новое сообщение',
        body: message.notification?.body ?? 'Открой «Настрой», чтобы прочитать',
      ),
    );
  } catch (error, stack) {
    unawaited(FirebaseCrashlytics.instance.recordError(error, stack));
  }
  runApp(const NastroiApp());
}

void _routeChatPush(RemoteMessage message) {
  if (message.data['type'] != 'chat_message') return;
  final threadId = message.data['thread_id']?.toString();
  if (threadId == null) return;
  homeTabIndex.value = 1;
  pendingChatThreadId.value = threadId;
  unawaited(FirebaseAnalytics.instance.logEvent(name: 'chat_push_opened'));
}

class NastroiApp extends StatefulWidget {
  const NastroiApp({super.key});

  @override
  State<NastroiApp> createState() => _NastroiAppState();
}

class _NastroiAppState extends State<NastroiApp> {
  final AppLinks _appLinks = AppLinks();
  final DeepLinkGuard _deepLinkGuard = DeepLinkGuard();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupDeepLinks() async {
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _openIncomingLink,
      onError: (Object error, StackTrace stack) =>
          FirebaseCrashlytics.instance.recordError(error, stack),
    );
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _openIncomingLink(initialUri);
    } catch (error, stack) {
      await FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }

  Future<void> _openIncomingLink(Uri uri) async {
    if (!_deepLinkGuard.tryBegin(uri)) return;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (uri.scheme == 'nastroi' && uri.host == 'person') {
        homeTabIndex.value = 0;
        final publicId = uri.pathSegments.firstOrNull;
        final user = Supabase.instance.client.auth.currentUser;
        if (publicId == null || user == null) return;
        final people = await PeopleRepository(userId: user.id).loadPeople();
        final person = people
            .where((item) => item.publicId == publicId)
            .firstOrNull;
        if (person == null) return;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PersonScreen(
              person: person,
              onPersonUpdated: (_) {},
              isEditable: false,
              isMyProfile: false,
            ),
          ),
        );
        return;
      }

      final personFromLink = tryParsePersonFromUri(uri);
      if (personFromLink != null) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                LinkPersonPreviewScreen(personFromLink: personFromLink),
          ),
        );
      }
    } finally {
      _deepLinkGuard.finish();
    }
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0B0B0F)
          : const Color(0xFFF7F1EA),
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF9C6BFF),
            brightness: brightness,
          ).copyWith(
            primary: dark ? const Color(0xFFB8D3FF) : const Color(0xFF7C5CFF),
            secondary: const Color(0xFFFF8CC8),
            surface: dark ? const Color(0xFF17171C) : const Color(0xFFFFFBF5),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: dark ? Colors.white : const Color(0xFF241B18),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, child) => MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const AuthGate(),
      ),
    );
  }
}
