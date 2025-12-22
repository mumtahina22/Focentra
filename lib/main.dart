import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth/authgate.dart';
import 'db/tasks_db.dart';
import 'notification.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';




Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

 await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await Supabase.initialize(
    url: 'https://ikhlblfxfbmfzhlzazio.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlraGxibGZ4ZmJtZnpobHphemlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcxNjk4MjgsImV4cCI6MjA3Mjc0NTgyOH0.sGfqi6ok7LjYb9V28RSPENZxiPkKDlgqTDrX8gAl2gU',
  );

  try {
    final tasksDb = tasksdb();
    await tasksDb.checkAndPerformResets();
  } catch (e) {
    print("Error checking resets on app start: $e");
  }
  
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
