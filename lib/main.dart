import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'app_theme_controller.dart';
import 'screens/home_screen.dart';
import 'screens/link_person_preview_screen.dart';
import 'utils/person_link.dart';
import 'data/people_repository.dart';
import 'screens/person_screen.dart';
import 'models/person.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'widgets/auth_gate.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const NastroiApp());
}

class NastroiApp extends StatefulWidget {
  const NastroiApp({super.key});

  @override
  State<NastroiApp> createState() => _NastroiAppState();
}

class _NastroiAppState extends State<NastroiApp> {
  final AppLinks _appLinks = AppLinks();

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
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _openIncomingLink(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _openIncomingLink(uri);
      },
      onError: (_) {},
    );
  }

  Future<void> _openIncomingLink(Uri uri) async {
    if (uri.scheme == 'nastroi' && uri.host == 'person') {
      final publicId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (publicId == null) return;

      final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final repository = PeopleRepository(userId: user.id);
      final people = await repository.loadPeople();

      Person? person;
      for (final item in people) {
        if (item.publicId == publicId) {
          person = item;
          break;
        }
      }

      if (person == null) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => PersonScreen(
            person: person!,
            onPersonUpdated: (_) {},
            isEditable: false,
            isMyProfile: false,
            onPersonDeleted: null,
            onTogglePin: null,
          ),
        ),
      );

      return;
    }

    final personFromLink = tryParsePersonFromUri(uri);
    if (personFromLink == null) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => LinkPersonPreviewScreen(
          personFromLink: personFromLink,
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9C6BFF),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F1EA),
      colorScheme: scheme.copyWith(
        primary: const Color(0xFF7C5CFF),
        secondary: const Color(0xFFFFA6C9),
        surface: const Color(0xFFFFFBF5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F1EA),
        foregroundColor: Color(0xFF241B18),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF241B18)),
        actionsIconTheme: IconThemeData(color: Color(0xFF241B18)),
        titleTextStyle: TextStyle(
          color: Color(0xFF241B18),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF241B18),
            displayColor: const Color(0xFF241B18),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFBF5),
        labelStyle: const TextStyle(color: Color(0xFF665650)),
        hintStyle: const TextStyle(color: Color(0xFF9A8177)),
        counterStyle: const TextStyle(color: Color(0xFF9A8177)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF241B18),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFBF5),
        modalBackgroundColor: Color(0xFFFFFBF5),
      ),
    );
  }

  ThemeData _darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A2A33),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0B0F),
      colorScheme: scheme.copyWith(
        primary: const Color(0xFFB8D3FF),
        secondary: const Color(0xFFFF8CC8),
        surface: const Color(0xFF17171C),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0B0F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1A1A1F),
        modalBackgroundColor: Color(0xFF1A1A1F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const AuthGate(),
        );
      },
    );
  }
}