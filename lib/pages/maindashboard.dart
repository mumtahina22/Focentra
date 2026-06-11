import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import 'onboarding_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/tasks_db.dart';
import '../widgets/left_panel.dart';

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
  Map<String, dynamic>? _mlProfile;
  bool _mlLoaded = false;
  Map<String, dynamic>? _taskSuggestion;

  final int maxDailyPoints = 100;
  final int maxWeeklyPoints = 700;
  final int maxMonthlyPoints = 3000;

  late final Stream<dynamic> _taskStream;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadPoints();
    _initML();

    final uid = tasksDatabase.authservice.getcurrentUseruid();
    if (uid != null) {
      _taskStream = tasksDatabase.tasktable
          .stream(primaryKey: ['id']).eq('uid', uid);
      _taskStream.listen(
        (_) {
          if (mounted) _loadPoints();
        },
        onError: (error) {
          print('Stream error (non-fatal): $error');
        },
        cancelOnError: false,
      );
    }
  }

  Future<void> _fetchUserName() async {
    try {
      final userProfile = await tasksDatabase.getUserProfile();
      if (userProfile != null) {
        setState(() {
          userName = userProfile['displayname'] ?? 'User';
        });
      } else {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && user.userMetadata != null) {
          final fullName = user.userMetadata!['full_name'] ?? 'User';
          setState(() {
            userName = fullName.split(' ').first;
          });
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        final fullName = user.userMetadata!['full_name'] ?? 'User';
        setState(() {
          userName = fullName.split(' ').first;
        });
      }
    }
  }

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

Future<void> _initML() async {
  final uid = tasksDatabase.authservice.getcurrentUseruid();
  if (uid == null) return;

  bool done = true; // default to true — prevent loop on error
  try {
    done = await MLService.isOnboardingComplete(uid);
  } catch (e) {
    done = true; // safety fallback
  }

  if (!done && mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingPage()),
    );
    return;
  }

  final profile = await MLService.fetchMLProfile(uid);
  if (mounted) {
    setState(() {
      _mlProfile = profile;
      _mlLoaded = true;
    });
  }

  if (uid.isNotEmpty) _loadSuggestion(uid);
}

  Future<void> _loadSuggestion(String uid) async {
    final suggestion = await MLService.getTaskSuggestion(uid);
    if (mounted) {
      setState(() => _taskSuggestion = suggestion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      drawer: Drawer(
        child: SizedBox(
          width: size.width * 0.5,
          child: LeftPanel(),
        ),
      ),
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'Focentra',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Welcome ──────────────────────────────────
                    Center(
                      child: Text(
                        'Welcome Back, $userName!',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: colorScheme.onBackground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Productivity progress card ────────────────
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
                            Text(
                              'Your Productivity',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildProgressBar(
                              label: "Today",
                              points: todayPoints,
                              maxPoints: maxDailyPoints,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 14),
                            _buildProgressBar(
                              label: "This Week",
                              points: weekPoints,
                              maxPoints: maxWeeklyPoints,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 14),
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
                    const SizedBox(height: 20),

                    // ── Work sessions card ────────────────────────
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Work Sessions Today',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '$workSessionsDone / 5',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: workSessionsDone / 5,
                                minHeight: 14,
                                backgroundColor:
                                    Colors.purple.withOpacity(0.12),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.purple),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── ML Archetype Card ─────────────────────────
                    if (_mlLoaded && _mlProfile != null) ...[
                      Builder(builder: (context) {
                        final archetype =
                            MLService.getArchetype(_mlProfile);
                        final emoji =
                            MLService.getArchetypeEmoji(archetype);
                        final color = Color(
                            MLService.getArchetypeColor(archetype));
                        final isProvisional =
                            MLService.isProvisional(_mlProfile);
                        final pomodoro =
                            MLService.getPomodoroSettings(_mlProfile);
                        final confidence =
                            ((_mlProfile!['confidence'] as num?) ?? 0.0)
                                .toDouble();

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(
                                              fontSize: 24),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Your Productivity Type',
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 12,
                                              letterSpacing: 0.3,
                                              color: colorScheme
                                                  .onSurface
                                                  .withOpacity(0.55),
                                              fontWeight:
                                                  FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isProvisional
                                                ? 'Still learning your patterns...'
                                                : archetype,
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: isProvisional
                                                  ? colorScheme
                                                      .onSurface
                                                      .withOpacity(0.45)
                                                  : color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                if (!isProvisional) ...[
                                  const SizedBox(height: 18),

                                  // Confidence
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Model Confidence',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.55),
                                        ),
                                      ),
                                      Text(
                                        '${(confidence * 100).toInt()}%',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    child: LinearProgressIndicator(
                                      value: confidence,
                                      minHeight: 10,
                                      backgroundColor: colorScheme
                                          .onSurface
                                          .withOpacity(0.08),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              color),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Pomodoro stats
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.07),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _pomodoroStat(
                                          '${pomodoro['work_min']}m',
                                          'Focus',
                                          colorScheme,
                                          color,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 32,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.1),
                                        ),
                                        _pomodoroStat(
                                          '${pomodoro['short_break_min']}m',
                                          'Short Break',
                                          colorScheme,
                                          color,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 32,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.1),
                                        ),
                                        _pomodoroStat(
                                          '${pomodoro['long_break_min']}m',
                                          'Long Break',
                                          colorScheme,
                                          color,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // Loading state
                    if (!_mlLoaded) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary
                                    .withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading your AI profile...',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                color: colorScheme.onBackground
                                    .withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── AI Task Suggestion ────────────────────────
                    if (_taskSuggestion != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        color: colorScheme.primaryContainer
                            .withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('💡',
                                    style: TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Suggestion',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.5),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _taskSuggestion!['message'] ??
                                          '',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _taskSuggestion!['interval'] ??
                                      'Daily',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              '$points / $maxPoints pts',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: maxPoints > 0 ? points / maxPoints : 0,
            minHeight: 14,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _pomodoroStat(
    String value,
    String label,
    ColorScheme colorScheme,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}