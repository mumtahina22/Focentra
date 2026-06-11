import 'dart:convert';
import 'package:http/http.dart' as http;

class MLService {
  static const String _baseUrl =
      'https://web-production-5b14b9.up.railway.app';

  // ─── FETCH CURRENT ARCHETYPE PROFILE ─────────────────────────────
  // Called on boot and after each work session
  static Future<Map<String, dynamic>?> fetchMLProfile(String uid) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/predict/$uid'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('MLService.fetchMLProfile error: $e');
      return null;
    }
  }

  // ─── SUBMIT ONBOARDING ANSWERS ────────────────────────────────────
  // Called once after registration
  static Future<Map<String, dynamic>?> submitOnboarding({
    required String uid,
    required int answerC,
    required int answerN,
    required int answerO,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/onboarding/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'answer_c': answerC,
              'answer_n': answerN,
              'answer_o': answerO,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('MLService.submitOnboarding error: $e');
      return null;
    }
  }

  // ─── CHECK ONBOARDING STATUS ──────────────────────────────────────
static Future<bool> isOnboardingComplete(String uid) async {
  try {
    final response = await http
        .get(Uri.parse('$_baseUrl/onboarding/$uid'))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['completed'] == true;
    }
    // If server error — assume complete to prevent loop
    return true;
  } catch (e) {
    print('MLService.isOnboardingComplete error: $e');
    // On timeout or any error — assume complete to prevent onboarding loop
    // The user will just get population defaults until ML reconnects
    return true;
  }
}

  // ─── TRIGGER PREDICTION AFTER SESSION ────────────────────────────
  // Called after addWorkSession() completes
  static Future<void> triggerPrediction(String uid) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/predict/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'trigger': 'session_complete',
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      // Silent fail — prediction is non-critical
      print('MLService.triggerPrediction error: $e');
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────

  /// Extracts Pomodoro settings from ML profile response
  /// Falls back to standard values if ML unavailable
  static Map<String, int> getPomodoroSettings(
      Map<String, dynamic>? mlProfile) {
    try {
      final pomodoro =
          mlProfile?['recommendations']?['pomodoro'] as Map<String, dynamic>?;
      return {
        'work_min': (pomodoro?['work_min'] as num?)?.toInt() ?? 25,
        'short_break_min':
            (pomodoro?['short_break_min'] as num?)?.toInt() ?? 5,
        'long_break_min': (pomodoro?['long_break_min'] as num?)?.toInt() ?? 20,
      };
    } catch (_) {
      return {
        'work_min': 25,
        'short_break_min': 5,
        'long_break_min': 20,
      };
    }
  }

  /// Returns archetype label, empty string if unavailable
  static String getArchetype(Map<String, dynamic>? mlProfile) {
    return mlProfile?['archetype'] as String? ?? '';
  }

  /// Returns true if prediction is still provisional (cold start)
  static bool isProvisional(Map<String, dynamic>? mlProfile) {
    return mlProfile?['is_provisional'] as bool? ?? true;
  }

  /// Returns notification message for archetype
  static String getNotificationMessage(Map<String, dynamic>? mlProfile) {
    try {
      return mlProfile?['recommendations']?['notification']?['message']
              as String? ??
          'Time to focus! 🔥';
    } catch (_) {
      return 'Time to focus! 🔥';
    }
  }

  /// Returns archetype emoji for UI display
  static String getArchetypeEmoji(String archetype) {
    switch (archetype) {
      case 'Consistent Achiever':
        return '🏆';
      case 'Night Owl Performer':
        return '🌙';
      case 'Easily Distracted User':
        return '⚡';
      case 'Last-Minute Performer':
        return '💪';
      case 'Burnout-Prone User':
        return '🌱';
      default:
        return '🤖';
    }
  }

  /// Returns archetype color for UI display
  static int getArchetypeColor(String archetype) {
    switch (archetype) {
      case 'Consistent Achiever':
        return 0xFFFFB300; // amber
      case 'Night Owl Performer':
        return 0xFF5C6BC0; // indigo
      case 'Easily Distracted User':
        return 0xFFEF5350; // red
      case 'Last-Minute Performer':
        return 0xFF26A69A; // teal
      case 'Burnout-Prone User':
        return 0xFF66BB6A; // green
      default:
        return 0xFF9E9E9E; // grey
    }
  }

  // ─── DYNAMIC POINTS WEIGHT ───────────────────────────────────────
static Future<int> getAdjustedPoints({
  required String uid,
  required int basePoints,
  required String taskInterval,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/predict/points_weight'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': uid,
            'base_points': basePoints,
            'task_interval': taskInterval,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['adjusted_points'] as num).toInt();
    }
    return basePoints; // fallback
  } catch (e) {
    return basePoints; // always fallback — never block task completion
  }
}

// ─── TASK SUGGESTION ─────────────────────────────────────────────
static Future<Map<String, dynamic>?> getTaskSuggestion(String uid) async {
  try {
    final response = await http
        .get(Uri.parse('$_baseUrl/predict/suggest/$uid'))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    return null;
  }
}

// ─── PREDICTION HISTORY ──────────────────────────────────────────
static Future<Map<String, dynamic>?> getPredictionHistory(
    String uid) async {
  try {
    final response = await http
        .get(Uri.parse('$_baseUrl/predict/history/$uid'))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    return null;
  }
}

// ─── ARCHETYPE TRANSITION MESSAGE ────────────────────────────────
static String getTransitionMessage(
    String fromArchetype, String toArchetype) {
  final positive = {
    'Easily Distracted User',
    'Burnout-Prone User',
    'Last-Minute Performer',
  };
  final isImprovement = positive.contains(fromArchetype) &&
      !positive.contains(toArchetype);

  if (isImprovement) {
    return 'You shifted from $fromArchetype to $toArchetype — great progress! 🎉';
  }
  return 'Your productivity pattern has evolved to $toArchetype.';
}
}