import 'package:supabase_flutter/supabase_flutter.dart';

class Authservice {
  final SupabaseClient _supabase = Supabase.instance.client;

  //sign in
  Future<AuthResponse> signinWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,

      password: password,
    );
  }

  //sign up
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  //sign out
  Future<void> signOut() async {
    return await _supabase.auth.signOut();
  }

  //get current user email
  String? getcurrentUseremail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }


  String? getcurrentUseruid() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.id;
  }
}
