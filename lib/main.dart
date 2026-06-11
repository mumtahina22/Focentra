import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth/authgate.dart';
import 'db/tasks_db.dart';
import 'notification.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:http/http.dart' as http;


Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

 await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await Supabase.initialize(
    url: 'https://chaeutterjwmcuvjbbrn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNoYWV1dHRlcmp3bWN1dmpiYnJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NzY4ODYsImV4cCI6MjA5NTU1Mjg4Nn0.OCa0ubJOpub1fbWT2ig2jNEHbWw3RoXWhWIP7Ju8M3s',
  );

  // Wake up Railway ML service in background
Future.delayed(Duration.zero, () async {
  try {
    await http.get(
      Uri.parse('https://web-production-5b14b9.up.railway.app/health'),
    ).timeout(const Duration(seconds: 30));
  } catch (_) {}
});

  
  LocalNotifications.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Focentra',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const Authgate(),
    );
  }
}
