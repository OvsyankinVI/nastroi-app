import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_service.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    final user = response.user;

    if (user != null) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email.trim(),
        'display_name': '',
      });
      await PushService.registerCurrentToken().catchError((_) {});
    }
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await PushService.registerCurrentToken().catchError((_) {});
  }

  static Future<void> signOut() async {
    await PushService.removeCurrentToken().catchError((_) {});
    await _client.auth.signOut();
  }
}
