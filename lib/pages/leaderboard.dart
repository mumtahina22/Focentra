import 'package:flutter/material.dart';

import '../db/tasks_db.dart';
import '../widgets/left_panel.dart';


class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final taskdatabase = tasksdb();
  List<Map<String, dynamic>> leaderboardData = [];
  Map<String, dynamic>? currentUserProfile;
  int currentUserRank = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load leaderboard and user profile concurrently
      final futures = await Future.wait([
        taskdatabase.getMonthlyLeaderboard(limit: 50),
        taskdatabase.getUserProfile(),
        taskdatabase.getUserMonthlyRank(),
      ]);

      setState(() {
        leaderboardData = futures[0] as List<Map<String, dynamic>>;
        currentUserProfile = futures[1] as Map<String, dynamic>?;
        currentUserRank = futures[2] as int;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading leaderboard: $e');
      setState(() {
        isLoading = false;
      });
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
          'Focentra - Leaderboard',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
            onPressed: _loadLeaderboardData,
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT PANEL
            //const LeftPanel(currentPage: 'Leaderboard'),
            
            // RIGHT PANEL (Leaderboard content)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.3),
                      colorScheme.secondaryContainer.withOpacity(0.2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Title
                      Center(
                        child: Text(
                          'Monthly Leaderboard',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onBackground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'See how you rank among other ZenStudy users this month!',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          color: colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (isLoading)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        // Current User Rank Card
                        if (currentUserProfile != null)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            color: colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: colorScheme.primary,
                                    child: Text(
                                      '#$currentUserRank',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your Rank',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 14,
                                            color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentUserProfile!['displayname'] ?? 'You',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${currentUserProfile!['monthlypoints'] ?? 0} pts',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Leaderboard List
                        Expanded(
                          child: leaderboardData.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.leaderboard,
                                        size: 64,
                                        color: colorScheme.onBackground.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No leaderboard data yet',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 18,
                                          color: colorScheme.onBackground.withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Complete some tasks to see rankings!',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          color: colorScheme.onBackground.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: leaderboardData.length,
                                  itemBuilder: (context, index) {
                                    final user = leaderboardData[index];
                                    final rank = index + 1;
                                    final points = user['monthlypoints'] ?? 0;
                                    final displayName = user['displayname'] ?? 'User';
                                    final avatarUrl = user['avatar_url'];

                                    return _buildLeaderboardTile(
                                      rank: rank,
                                      displayName: displayName,
                                      points: points,
                                      avatarUrl: avatarUrl,
                                      colorScheme: colorScheme,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile({
    required int rank,
    required String displayName,
    required int points,
    String? avatarUrl,
    required ColorScheme colorScheme,
  }) {
    // Special styling for top 3
    Color? rankColor;
    IconData? rankIcon;
    
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400];
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown[400];
      rankIcon = Icons.emoji_events;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: rank <= 3 ? 4 : 2,
      color: rank <= 3 ? rankColor?.withOpacity(0.1) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rank <= 3 && rankIcon != null) ...[
              Icon(
                rankIcon,
                color: rankColor,
                size: 24,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.w600,
                fontSize: rank <= 3 ? 18 : 16,
                color: rank <= 3 ? rankColor : colorScheme.onSurface,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: avatarUrl != null 
                  ? NetworkImage(avatarUrl)
                  : const AssetImage('assets/profile-icon-9.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: rank <= 3 ? rankColor : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$points pts',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? Colors.white : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}