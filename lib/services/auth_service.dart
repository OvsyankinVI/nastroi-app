import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}