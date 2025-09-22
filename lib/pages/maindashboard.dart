
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenstudy/db/tasks_db.dart';
import 'package:zenstudy/widgets/left_panel.dart'; // Import the new left panel

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String userName = 'User';
  final tasksDatabase = tasksdb();

  int todayPoints = 0;
  int weekPoints = 0;
  int monthPoints = 0;
  int workSessionsDone = 0;

  final int maxDailyPoints = 100;
  final int maxWeeklyPoints = 700;
  final int maxMonthlyPoints = 3000;

  late final Stream<dynamic> _taskStream;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadPoints();

    // Listen to task changes in real-time
    final uid = tasksDatabase.authservice.getcurrentUseruid();
    if (uid != null) {
      _taskStream = tasksDatabase.tasktable
          .stream(primaryKey: ['id'])
          .eq('uid', uid);
      _taskStream.listen((_) {
        if (mounted) _loadPoints(); // Update points whenever task changes
      });
    }
  }

  

// Fetch user name from Users table
Future<void> _fetchUserName() async {
  try {
    final userProfile = await tasksDatabase.getUserProfile();
    if (userProfile != null) {
      setState(() {
        userName = userProfile['displayname'] ?? 'User';
      });
    } else {
      // Fallback to auth metadata if no profile exists yet
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final fullName = user.userMetadata!['full_name'] ?? 'User';
        setState(() {
          userName = fullName.split(' ').first; // Use first name as fallback
        });
      }
    }
  } catch (e) {
    print('Error fetching user name: $e');
    // Fallback to auth metadata on error
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      final fullName = user.userMetadata!['full_name'] ?? 'User';
      setState(() {
        userName = fullName.split(' ').first; // Use first name as fallback
      });
    }
  }
}

  // Load points dynamically
  Future<void> _loadPoints() async {
    final t = await tasksDatabase.getPointsForToday();
    final w = await tasksDatabase.getPointsForThisWeek();
    final m = await tasksDatabase.getPointsForThisMonth();
    final s = await tasksDatabase.getWorkSessionsToday();
    if (mounted) {
      setState(() {
        todayPoints = t;
        weekPoints = w;
        monthPoints = m;
        workSessionsDone = s;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'ZenStudy',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Use the new LeftPanel widget
            const LeftPanel(currentPage: 'Dashboard'),
            
            // RIGHT PANEL (Dashboard content)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back, $userName!',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Productivity',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildProgressBar(
                              label: "Today",
                              points: todayPoints,
                              maxPoints: maxDailyPoints,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 12),
                            _buildProgressBar(
                              label: "This Week",
                              points: weekPoints,
                              maxPoints: maxWeeklyPoints,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 12),
                            _buildProgressBar(
                              label: "This Month",
                              points: monthPoints,
                              maxPoints: maxMonthlyPoints,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Work Sessions Done Today',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: workSessionsDone / 10,
                                minHeight: 16,
                                backgroundColor: Colors.grey.shade300,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$workSessionsDone / 5 sessions',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.onBackground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int points,
    required int maxPoints,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $points / $maxPoints pts',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: points / maxPoints,
            minHeight: 16,
            backgroundColor: Colors.grey.shade300,
            color: color,
          ),
        ),
      ],
    );
  }
}
