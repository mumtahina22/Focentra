import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/homepage.dart';
import '../pages/maindashboard.dart';


class Authgate extends StatelessWidget {
  const Authgate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 👇 Add the centered loading spinner here
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If logged in, go to dashboard
        if (Supabase.instance.client.auth.currentUser != null) {
          return const MainDashboard();
        }

        // Otherwise, go to starting
        return const HomePage();
      },
    );
  }
}
