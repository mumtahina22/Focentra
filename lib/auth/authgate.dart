import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/tasks_db.dart';
import '../pages/homepage.dart';
import '../pages/maindashboard.dart';

class Authgate extends StatefulWidget {
  const Authgate({super.key});

  @override
  State<Authgate> createState() => _AuthgateState();
}

class _AuthgateState extends State<Authgate> {
  bool _resetDone = false;

  Future<void> _runResetIfNeeded() async {
    if (_resetDone) return;
    _resetDone = true;
    try {
      final tasksDb = tasksdb();
      await tasksDb.checkAndPerformResets();
      print("Reset check completed after auth confirmed.");
    } catch (e) {
      print("Error checking resets after auth: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (Supabase.instance.client.auth.currentUser != null) {
          // Auth confirmed — safe to run resets now
          _runResetIfNeeded();
          return const MainDashboard();
        }

        return const HomePage();
      },
    );
  }
}