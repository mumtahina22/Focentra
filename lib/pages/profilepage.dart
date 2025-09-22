import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenstudy/pages/loginpage.dart';
import 'package:zenstudy/db/tasks_db.dart';
import 'package:zenstudy/widgets/left_panel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final taskdatabase = tasksdb();
  Map<String, dynamic>? userProfile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await taskdatabase.getUserProfile();
      final authUser = Supabase.instance.client.auth.currentUser;
      
      // If no profile exists, create one
      if (profile == null && authUser != null) {
        await taskdatabase.createOrUpdateUser(
          email: authUser.email!,
          fullname: authUser.userMetadata?['full_name'] ?? 'User',
        );
        // Load the newly created profile
        final newProfile = await taskdatabase.getUserProfile();
        setState(() {
          userProfile = newProfile;
          isLoading = false;
        });
      } else {
        setState(() {
          userProfile = profile;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _showEditProfileDialog() async {
    final displayNameController = TextEditingController(
      text: userProfile?['displayname'] ?? '',
    );
    String? selectedAvatarUrl = userProfile?['avatar_url'];

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Edit Profile",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Picture Section
                Text(
                  "Profile Picture",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showAvatarSelectionDialog(setDialogState),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: selectedAvatarUrl != null
                        ? NetworkImage(selectedAvatarUrl!)
                        : const AssetImage('assets/profile-icon-9.png') as ImageProvider,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Display Name Field
                TextField(
                  controller: displayNameController,
                  decoration: InputDecoration(
                    labelText: "Display Name (shown on leaderboard)",
                    labelStyle: TextStyle(fontFamily: 'Montserrat'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (displayNameController.text.isNotEmpty) {
                    try {
                      await taskdatabase.updateUserProfile(
                        displayname: displayNameController.text,
                        avatarUrl: selectedAvatarUrl,
                      );
                      Navigator.pop(context);
                      _loadUserProfile(); // Reload profile data
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Profile updated successfully!"),
                          backgroundColor: colorScheme.primary,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error updating profile: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAvatarSelectionDialog(StateSetter setDialogState) {
    final List<String> avatarOptions = [
      'assets/profile-icon-9.png',
      'assets/avatar-1.png',
      'assets/avatar-2.png',
      'assets/avatar-3.png',
      'assets/avatar-4.png',
      'assets/avatar-5.png',
    
    ];

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text("Choose Avatar"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: avatarOptions.length,
              itemBuilder: (context, index) {
                final avatarPath = avatarOptions[index];
                return GestureDetector(
                  onTap: () {
                    setDialogState(() {
                      // For local assets, we'll store the path
                      // In a real app, you'd upload to Supabase Storage
                      // selectedAvatarUrl = avatarPath;
                    });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage(avatarPath),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authUser = Supabase.instance.client.auth.currentUser;

    if (isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          title: Text(
            'ZenStudy - Profile',
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'ZenStudy - Profile',
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
            // LEFT PANEL
            const LeftPanel(currentPage: 'Profile'),
            
            // RIGHT PANEL (Profile content)
            Expanded(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(24),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Title
                      Text(
                        'My Profile',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Profile Card
                      Center(
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                // Profile Image
                                CircleAvatar(
                                  radius: 60,
                                  backgroundImage: userProfile?['avatar_url'] != null
                                      ? NetworkImage(userProfile!['avatar_url'])
                                      : AssetImage('assets/profile-icon-9.png') as ImageProvider,
                                ),
                                const SizedBox(height: 24),

                                // Full Name
                                Text(
                                  userProfile?['fullname'] ?? 'User',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Display Name
                                if (userProfile?['displayname'] != userProfile?['fullname'])
                                  Text(
                                    '@${userProfile?['displayname'] ?? 'user'}',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 8),

                                // Email
                                Text(
                                  authUser?.email ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: 'Total Points',
                              value: '${userProfile?['totalpoints'] ?? 0}',
                              icon: Icons.star,
                              color: Colors.amber,
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              title: 'Monthly Points',
                              value: '${userProfile?['monthlypoints'] ?? 0}',
                              icon: Icons.calendar_month,
                              color: Colors.blue,
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              title: 'Current Streak',
                              value: '${userProfile?['currentstreak'] ?? 0}',
                              icon: Icons.local_fire_department,
                              color: Colors.orange,
                              colorScheme: colorScheme,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      _profileTile(
                        icon: Icons.edit,
                        label: 'Edit Profile',
                        colorScheme: colorScheme,
                        onTap: _showEditProfileDialog,
                      ),
                      _profileTile(
                        icon: Icons.settings,
                        label: 'Settings',
                        colorScheme: colorScheme,
                        onTap: () {
                          // TODO: Implement settings page
                        },
                      ),
                      _profileTile(
                        icon: Icons.logout,
                        label: 'Logout',
                        colorScheme: colorScheme,
                        onTap: () async {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("Confirm Logout"),
                              content: Text("Are you sure you want to logout?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await Supabase.instance.client.auth.signOut();
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                      (route) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: Text("Logout"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
