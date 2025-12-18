import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenstudy/auth/authservice.dart';

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
  Future<void> toggleDone(dynamic taskid, bool done) async {
    await tasktable.update({'done': done}).eq('id', taskid);
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
  Future<void> checkAndPerformResets() async {
    final now = DateTime.now();

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
      await resetAllUsersMonthlyPoints(); // Reset monthly points for all users
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

  // Reset monthly points for all users (call at start of new month)
  Future<void> resetAllUsersMonthlyPoints() async {
    await userstable.update({'monthlypoints': 0});
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
  Future<void> updateUserStreak(int newStreak) async {
    final uid = authservice.getcurrentUseruid();
    if (uid == null) return;

    await userstable
        .update({'currentstreak': newStreak})
        .eq('id', uid);
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
