import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/tasks_db.dart';
import '../pages/leaderboard.dart';
import '../pages/maindashboard.dart';
import '../pages/pomodoropage.dart';
import '../pages/profilepage.dart';
import '../pages/tasknhabitpage.dart';
// Import your tasks_db

class LeftPanel extends StatefulWidget {
  final String? currentPage; // Optional parameter to highlight current page

  const LeftPanel({super.key, this.currentPage});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  String userName = 'User';
  String? avatarUrl; // Add a variable to store the avatar URL
  final taskdatabase = tasksdb(); // Instance of your database service

  @override
  void initState() {
    super.initState();
    _fetchUserProfile(); // Call the new method to fetch profile data
  }



  // Fetch user profile data (name and avatar)
  Future<void> _fetchUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 1. Try to get profile from your custom 'Users' table first
        final profile = await taskdatabase.getUserProfile();

        if (profile != null) {
          if (mounted) {
            setState(() {
              // Use display name if available, otherwise full name
              userName = profile['displayname'] ?? profile['fullname'] ?? 'User';
              avatarUrl = profile['avatar_url'];
            });
          }
        } else if (user.userMetadata != null) {
          // 2. Fallback to auth metadata if no custom profile exists yet
          if (mounted) {
            setState(() {
              userName = user.userMetadata!['full_name'] ?? 'User';
              // Auth metadata might not have avatar_url unless set on signup
              avatarUrl = user.userMetadata!['avatar_url'];
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching user profile for left panel: $e');
    }
  }

  // Helper function to get the correct image provider
  ImageProvider _getAvatarImage(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/profile-icon-9.png');
    }
    if (path.startsWith('http') || path.startsWith('https')) {
      return NetworkImage(path);
    }
    // Assuming other paths are local assets (like from your avatar selection dialog)
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.25,
      color: colorScheme.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    // Wait for the ProfilePage to pop, then refresh data
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                    // Refresh profile data when returning from ProfilePage
                    _fetchUserProfile();
                  },
                  child: CircleAvatar(
                    radius: 40,
                    // Use the helper function here
                    backgroundImage: _getAvatarImage(avatarUrl),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userName,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.currentPage ?? 'Dashboard',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade400),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dashboardTile(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isSelected: widget.currentPage == 'Dashboard',
                  onTap: () {
                    if (widget.currentPage != 'Dashboard') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainDashboard(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                _dashboardTile(
                  icon: Icons.timer,
                  label: 'Pomodoro',
                  isSelected: widget.currentPage == 'Pomodoro',
                  onTap: () {
                    if (widget.currentPage != 'Pomodoro') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const Pomodoro()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                _dashboardTile(
                  icon: Icons.check_circle_outline,
                  label: 'Tasks',
                  isSelected: widget.currentPage == 'Tasks',
                  onTap: () {
                    if (widget.currentPage != 'Tasks') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const TaskPage()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                _dashboardTile(
                  icon: Icons.leaderboard,
                  label: 'Leaderboard',
                  isSelected: widget.currentPage == 'Leaderboard',
                  onTap: () {
                    if (widget.currentPage != 'Leaderboard') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LeaderboardPage()),
                      );
                    }
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        height: 80,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Row(
          //mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                //softWrap: false,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}