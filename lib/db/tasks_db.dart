import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ml_service.dart';
import '../auth/authservice.dart';

class tasksdb {
  final tasktable = Supabase.instance.client.from('Tasks');
  final userstable = Supabase.instance.client.from('Users');
  final authservice = Authservice();

  // Insert
  Future<void> inserttask(
    String content,
    String title,
    String choose,
    int points,
  ) async {
    final uid = authservice.getcurrentUseruid();
    await tasktable.insert({
      'title': title,
      'content': content,
      'choose': choose,
      'points': points,
      'uid': uid,
      'done': false, // default
    });
  }

  // Update
  Future<void> updatetask(
    dynamic taskid,
    String content,
    String title,
    String choose,
    int points,
  ) async {
    await tasktable
        .update({
          'title': title,
          'content': content,
          'choose': choose,
          'points': points,
        })
        .eq('id', taskid);
  }

  // Toggle "done"
Future<void> toggleDone(dynamic taskid, bool done, {
  String taskInterval = 'Daily',
  int basePoints = 0,
}) async {
  await tasktable.update({'done': done}).eq('id', taskid);
  if (done == true) {
    await calculateAndIncrementStreak();

    // Get ML-adjusted points if base points provided
    if (basePoints > 0) {
      final uid = authservice.getcurrentUseruid();
      if (uid != null) {
        final adjustedPoints = await MLService.getAdjustedPoints(
          uid: uid,
          basePoints: basePoints,
          taskInterval: taskInterval,
        );
        await addPointsLog(taskid, adjustedPoints);
        return;
      }
    }
    // Fallback — log base points directly
    if (basePoints > 0) {
      await addPointsLog(taskid, basePoints);
    }
  }
}

  // Delete
  Future<void> deletetask(dynamic taskid) async {
    await tasktable.delete().eq('id', taskid);
    
  }

  Future<void> resetTasks(String category) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;
    await tasktable
        .update({'done': false})
        .eq('choose', category)
        .eq('uid', uid);
  }

  // Add points to PointsLog and update user stats
  Future<void> addPointsLog(dynamic taskId, int points) async {
    final uid = authservice.getcurrentUseruid();
    await Supabase.instance.client.from('PointsLog').insert({
      'uid': uid,
      'task_id': taskId,
      'points': points,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update user stats
    await updateUserTotalPoints(points);
    await updateUserMonthlyPoints(points);
  }

  Future<int> getPointsForToday() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return 0;

    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final data = await Supabase.instance.client
        .from('PointsLog')
        .select('points')
        .eq('uid', uid)
        .gte('created_at', startOfDay.toIso8601String());

    if (data == null || data.isEmpty) return 0;

    // Sum up all points
    return data.fold<int>(0, (sum, item) => sum + (item['points'] as int));
  }

  Future<int> getPointsForThisWeek() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return 0;

    // Find last Friday midnight
    final now = DateTime.now();
    final daysSinceFriday = (now.weekday >= DateTime.friday)
        ? now.weekday - DateTime.friday
        : 7 - (DateTime.friday - now.weekday);
    final lastFriday = DateTime(
      now.year,
      now.month,
      now.day - daysSinceFriday,
    );

    final data = await Supabase.instance.client
        .from('PointsLog')
        .select('points')
        .eq('uid', uid)
        .gte('created_at', lastFriday.toIso8601String());

    if (data == null || data.isEmpty) return 0;

    return data.fold<int>(0, (sum, item) => sum + (item['points'] as int));
  }

  Future<int> getPointsForThisMonth() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return 0;

    // Start of the current month
    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    final data = await Supabase.instance.client
        .from('PointsLog')
        .select('points')
        .eq('uid', uid)
        .gte('created_at', startOfMonth.toIso8601String());

    if (data == null || data.isEmpty) return 0;

    return data.fold<int>(0, (sum, item) => sum + (item['points'] as int));
  }

  // Add a work session
  Future<void> addWorkSession() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    await Supabase.instance.client.from('WorkSessions').insert({
      'uid': uid,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Get number of sessions today
  Future<int> getWorkSessionsToday() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return 0;

    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final data = await Supabase.instance.client
        .from('WorkSessions')
        .select('id')
        .eq('uid', uid)
        .gte('timestamp', startOfDay.toIso8601String());

    if (data == null || data.isEmpty) return 0;

    return data.length;
  }

  // Helper method to upsert reset log
  Future<void> updateResetLog(String resetType) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    await Supabase.instance.client.from('ResetLog').upsert({
      'uid': uid,
      'reset_type': resetType,
      'last_reset_date': DateTime.now().toIso8601String(),
    }, onConflict: 'uid,reset_type');
  }

  // Helper method to get last reset date for a type
  Future<DateTime?> getLastResetDate(String resetType) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return null;

    final data = await Supabase.instance.client
        .from('ResetLog')
        .select('last_reset_date')
        .eq('uid', uid)
        .eq('reset_type', resetType)
        .maybeSingle();

    if (data == null) return null;
    return DateTime.parse(data['last_reset_date']);
  }

  // Main safety check method - call this on app start
// Main safety check method - call this on app start
  Future<void> checkAndPerformResets() async {
    // 🌟 1. Look up user identity first to authorize the database query
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    final now = DateTime.now();

    // 🌟 2. STREAK BREAK SAFETY CHECK: 
    // If they missed a whole day without a completion, drop streak back to 0 instantly.
    try {
      final profile = await userstable
          .select('last_active_date')
          .eq('id', uid)
          .maybeSingle();

      if (profile != null && profile['last_active_date'] != null) {
        final lastActive = DateTime.parse(profile['last_active_date']);
        final today = DateTime(now.year, now.month, now.day); // Clean date (00:00)
        final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
        
        // If more than 1 day has passed since midnight of their last completion day...
        if (today.difference(lastActiveDay).inDays > 1) {
          await userstable.update({'currentstreak': 0}).eq('id', uid);
          print("User missed a consecutive day. Streak reset to 0.");
        }
      }
    } catch (e) {
      print("Error running background streak check: $e");
    }

    // ----------------------------------------------------
    // 3. TASK INTERVAL RESETS (Your existing code continues below)
    // ----------------------------------------------------

    // Check daily reset (only if it's a NEW DAY, not just 24 hours)
    final lastDailyReset = await getLastResetDate('Daily');
    final todayStart = DateTime(now.year, now.month, now.day);
    final lastResetDay = lastDailyReset != null
        ? DateTime(
            lastDailyReset.year, lastDailyReset.month, lastDailyReset.day)
        : DateTime(2000); // Very old date if null

    if (lastResetDay.isBefore(todayStart)) {
      await resetTasks("Daily");
      await updateResetLog('Daily');
      print("Daily tasks reset performed");
    }

    // Check weekly reset (if past Friday and haven't reset since last Friday)
    final lastWeeklyReset = await getLastResetDate('Weekly');
    final daysSinceFriday = (now.weekday >= DateTime.friday)
        ? now.weekday - DateTime.friday
        : 7 - (DateTime.friday - now.weekday);
    final lastFridayMidnight =
        DateTime(now.year, now.month, now.day - daysSinceFriday);

    if (lastWeeklyReset == null ||
        lastWeeklyReset.isBefore(lastFridayMidnight)) {
      await resetTasks("Weekly");
      await updateResetLog('Weekly');
      print("Weekly tasks reset performed");
    }

    // Check monthly reset (if past 1st of month and haven't reset since last 1st)
    final lastMonthlyReset = await getLastResetDate('Monthly');
    final startOfCurrentMonth = DateTime(now.year, now.month, 1);
    final lastResetMonth = lastMonthlyReset != null
        ? DateTime(lastMonthlyReset.year, lastMonthlyReset.month, 1)
        : DateTime(2000);

    if (lastResetMonth.isBefore(startOfCurrentMonth)) {
      await resetTasks("Monthly");
      await updateResetLog('Monthly');
      print("Monthly tasks and points reset performed");
    }
  }

  // ========== USER TABLE METHODS ==========

// Create or update user profile
  Future<void> createOrUpdateUser({
    required String uid, // <--- ADD THIS
    required String email,
    required String fullname,
    String? displayname,
    String? avatarUrl,
  }) async {
    // REMOVE: final uid = authservice.getcurrentUseruid(); 
    // We trust the ID passed from the registration page
    
    final firstName = fullname.split(' ').first;

    await userstable.upsert({
      'id': uid, // Use the passed uid
      'email': email,
      'fullname': fullname,
      'displayname': displayname ?? firstName,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
      'totalpoints': 0, // Initialize defaults if this is a new user
      'monthlypoints': 0,
      'currentstreak': 0,
    }, onConflict: 'id');
  }
  // Update total points (call this whenever points are added)
  Future<void> updateUserTotalPoints(int pointsToAdd) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    // Get current total points
    final userData = await userstable
        .select('totalpoints')
        .eq('id', uid)
        .maybeSingle();

    final currentTotal = userData?['totalpoints'] ?? 0;
    final newTotal = currentTotal + pointsToAdd;

    await userstable
        .update({'totalpoints': newTotal})
        .eq('id', uid);
  }

  // Update monthly points (call this whenever points are added)
  Future<void> updateUserMonthlyPoints(int pointsToAdd) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    final userData = await userstable
        .select('monthlypoints')
        .eq('id', uid)
        .maybeSingle();

    final currentMonthly = userData?['monthlypoints'] ?? 0;
    final newMonthly = currentMonthly + pointsToAdd;

    await userstable
        .update({'monthlypoints': newMonthly})
        .eq('id', uid);
  }


  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return null;

    return await userstable
        .select()
        .eq('id', uid)
        .maybeSingle();
  }

  // Update user streak
Future<void> calculateAndIncrementStreak() async {
  final uid = authservice.getcurrentUseruid();
  if (uid == null) return;

  try {
    // 1. Fetch current streak data
    final userProfile = await userstable
        .select('currentstreak, last_active_date')
        .eq('id', uid)
        .maybeSingle();

    if (userProfile == null) return;

    int currentStreak = userProfile['currentstreak'] ?? 0;
    String? lastActiveStr = userProfile['last_active_date'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // Strip time, keep date

    if (lastActiveStr != null) {
      final lastActiveDate = DateTime.parse(lastActiveStr);
      final lastActiveDay = DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);

      // Calculate days difference between today and last completion day
      final difference = today.difference(lastActiveDay).inDays;

      if (difference == 1) {
        // Converted: They did work yesterday! Streak grows.
        currentStreak += 1;
      } else if (difference > 1) {
        // Broken: They missed a day or more. Reset streak to 1.
        currentStreak = 1;
      }
      // Note: If difference == 0, they already did a task today. Keep current streak without adding.
    } else {
      // First time starting a streak
      currentStreak = 1;
    }

    // 2. Save calculated figures back to Supabase
    await userstable.update({
      'currentstreak': currentStreak,
      'last_active_date': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('id', uid);

  } catch (e) {
    print("Error calculating streak updates: $e");
  }
}

  // Get monthly leaderboard
  Future<List<Map<String, dynamic>>> getMonthlyLeaderboard({int limit = 10}) async {
    return await userstable
        .select('displayname, monthlypoints, avatar_url')
        .order('monthlypoints', ascending: false)
        .limit(limit);
  }

  // Get user's rank in monthly leaderboard
  Future<int> getUserMonthlyRank() async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return 0;

    final userPoints = await userstable
        .select('monthlypoints')
        .eq('id', uid)
        .maybeSingle();

    if (userPoints == null) return 0;

    final myPoints = userPoints['monthlypoints'] ?? 0;

    // Count how many users have more points than current user
    final higherRanked = await userstable
        .select('id')
        .gt('monthlypoints', myPoints);

    return higherRanked.length+ 1; // +1 because rank starts from 1
  }

  // Update user profile (for profile page)
  Future<void> updateUserProfile({
    String? fullname,
    String? displayname,
    String? avatarUrl,
  }) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (fullname != null) {
      updates['fullname'] = fullname;
      // If displayname not provided, update it to first name
      if (displayname == null) {
        updates['displayname'] = fullname.split(' ').first;
      }
    }
    
    if (displayname != null) updates['displayname'] = displayname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await userstable
        .update(updates)
        .eq('id', uid);
  }
}
