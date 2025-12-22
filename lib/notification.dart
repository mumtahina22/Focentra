/*
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifications {

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static final onClickNotification = BehaviorSubject<String>();

  static void onNotificationTap(NotificationResponse notificationResponse) {
    onClickNotification.add(notificationResponse.payload!);
  }

  bool _isRequestingPermission = false;

  Future<void> requestExactAlarmPermissionSafe() async {
    if (_isRequestingPermission) return; // Prevent double calls

    _isRequestingPermission = true;

    try {
      final platform = FlutterLocalNotificationsPlugin();

      await platform
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } finally {
      _isRequestingPermission = false;
    }
  }



  static Future init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);

    await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: onNotificationTap);

    // 1. Load the database of timezones
    tz.initializeTimeZones();

    try {
      // 2. Get the device's timezone string
      final dynamic locationData = await FlutterTimezone.getLocalTimezone();
      String timeZoneName = (locationData is String) ? locationData : locationData.name;

      // 3. Sync the local location with the database
      // This is the core fix for the "Gap"
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      print("✅ Notifications synced to local time: $timeZoneName");
    } catch (e) {
      print("Could not get local timezone, falling back to UTC: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }



  static Future showScheduleNotification({
    required int duration,
    required String title,
    required String body,
    required String payload,
  }) async {
    // Use a fixed ID for "Almost Done" alerts if you want to prevent spam,
    // or dynamic IDs to ensure they don't overwrite each other.
    int id = DateTime.now().millisecond;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Timer',
        importance: Importance.max,
        priority: Priority.high,
        // Helps notification show up even if the screen is locked
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(),
    );

    if (duration <= 0) {
      await _flutterLocalNotificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
    } else {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(Duration(seconds: duration)),
        notificationDetails,
        // Use exactAllowWhileIdle to wake the phone up from sleep
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }


  static Future cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
*/

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static final onClickNotification = BehaviorSubject<String>();

  static bool _isInitialized = false;
  static bool _isRequestingPermission = false;

  static void onNotificationTap(NotificationResponse notificationResponse) {
    onClickNotification.add(notificationResponse.payload!);
  }

  static Future<void> requestExactAlarmPermissionSafe() async {
    if (_isRequestingPermission) return;

    _isRequestingPermission = true;

    try {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } finally {
      _isRequestingPermission = false;
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
    InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);

    await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: onNotificationTap);


    tz.initializeTimeZones();

    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();

      String timeZoneString = timeZoneInfo.toString();
      String timeZoneName = timeZoneString.split(',')[0].replaceAll('TimezoneInfo(', '').trim();

      tz.setLocalLocation(tz.getLocation(timeZoneName));

      print("Notifications synced to local time: $timeZoneName");
    } catch (e) {
      print("Could not get local timezone, falling back to UTC: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _isInitialized = true;
  }

  static Future<void> showScheduleNotification({
    required int duration,
    required String title,
    required String body,
    required String payload,
  }) async {

    if (!_isInitialized) {
      await init();
    }

    int id = DateTime.now().millisecondsSinceEpoch % 100000 + payload.hashCode % 1000;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Timer',
        channelDescription: 'Notifications for Pomodoro timer sessions',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    if (duration <= 0) {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } else {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: duration));

      print("Scheduling notification:");
      print("Title: $title");
      print("Duration: $duration seconds");
      print("Current time: ${tz.TZDateTime.now(tz.local)}");
      print("Scheduled for: $scheduledDate");

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  static Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}