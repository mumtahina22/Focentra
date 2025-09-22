import 'package:flutter/material.dart';
import 'package:zenstudy/pages/leaderboard.dart';
import 'package:zenstudy/pages/maindashboard.dart';
import 'package:zenstudy/pages/pomodoropage.dart';
import 'package:zenstudy/pages/profilepage.dart';
import 'package:zenstudy/pages/tasknhabitpage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeftPanel extends StatefulWidget {
  final String? currentPage; // Optional parameter to highlight current page

  const LeftPanel({super.key, this.currentPage});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  // Fetch user name
  Future<void> _fetchUserName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      setState(() {
        userName = user.userMetadata!['full_name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.25,
      color: colorScheme.surfaceVariant,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                  child: const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/profile-icon-9.png'),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
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
                          MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _dashboardTile(
                    icon: Icons.phone_iphone_outlined,
                    label: 'Screen-Free',
                    isSelected: widget.currentPage == 'Screen-Free',
                    onTap: () {
                      // Add navigation when screen-free page is created
                    },
                  ),
                ],
              ),
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
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 10,
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
