import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ml_service.dart';
import '../db/tasks_db.dart';
import '../widgets/left_panel.dart';
import 'loginpage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final taskdatabase = tasksdb();
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  Map<String, dynamic>? _mlProfile;

  final List<String> avatarOptions = [
    'assets/profile-icon-9.png',
    'assets/avatar-1.png',
    'assets/avatar-2.png',
    'assets/avatar-3.png',
    'assets/avatar-4.png',
    'assets/avatar-5.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadMLProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;

      if (authUser == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final profile = await taskdatabase.getUserProfile();

      if (profile == null) {
        await taskdatabase.createOrUpdateUser(
          uid: authUser.id,
          email: authUser.email!,
          fullname: authUser.userMetadata?['full_name'] ?? 'User',
        );
        final newProfile = await taskdatabase.getUserProfile();
        if (mounted) {
          setState(() {
            userProfile = newProfile;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userProfile = profile;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMLProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final profile = await MLService.fetchMLProfile(uid);
    if (mounted) {
      setState(() => _mlProfile = profile);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Change Password",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPassController,
                        obscureText: !isPasswordVisible,
                        decoration: const InputDecoration(
                          labelText: "Current Password",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPassController,
                        obscureText: !isPasswordVisible,
                        decoration: const InputDecoration(
                          labelText: "New Password",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPassController,
                        obscureText: !isPasswordVisible,
                        decoration: const InputDecoration(
                          labelText: "Confirm New Password",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != newPassController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                            icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18),
                            label:
                                Text(isPasswordVisible ? "Hide" : "Show"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isUpdating = true);
                            try {
                              final supabase = Supabase.instance.client;
                              final user = supabase.auth.currentUser;
                              if (user == null || user.email == null) return;

                              final authResponse =
                                  await supabase.auth.signInWithPassword(
                                email: user.email!,
                                password: currentPassController.text,
                              );

                              if (authResponse.user != null) {
                                await supabase.auth.updateUser(
                                  UserAttributes(
                                      password: newPassController.text),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Password updated successfully!"),
                                      backgroundColor: colorScheme.primary,
                                    ),
                                  );
                                }
                              }
                            } on AuthException catch (e) {
                              setState(() => isUpdating = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed: ${e.message}"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() => isUpdating = false);
                              print(e);
                            }
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  ImageProvider _getAvatarImage(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/profile-icon-9.png');
    }
    if (path.startsWith('http') || path.startsWith('https')) {
      return NetworkImage(path);
    }
    return AssetImage(path);
  }

  Future<void> _handleAvatarChange() async {
    final String? selectedPath = await _showAvatarSelectionDialog();
    if (selectedPath != null) {
      try {
        setState(() => isLoading = true);
        await taskdatabase.updateUserProfile(avatarUrl: selectedPath);
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated!")),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Error: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<String?> _showAvatarSelectionDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Avatar"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: avatarOptions.length,
              itemBuilder: (context, index) {
                final avatarPath = avatarOptions[index];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, avatarPath),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.3)),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(avatarPath),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditProfileDialog() async {
    final displayNameController = TextEditingController(
      text: userProfile?['displayname'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: InputDecoration(
                  labelText: "Display Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (displayNameController.text.isNotEmpty) {
                  try {
                    await taskdatabase.updateUserProfile(
                      displayname: displayNameController.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                    _loadUserProfile();
                  } catch (e) {
                    print(e);
                  }
                }
              },
              child: const Text("Save"),
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
    final screenSize = MediaQuery.of(context).size;

    if (isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: SizedBox(
          width: screenSize.width * 0.5,
          child: LeftPanel(),
        ),
      ),
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'Focentra - Profile',
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
                      Center(
                        child: Text(
                          'My Profile',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onBackground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Profile Card ────────────────────────────────
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
                                GestureDetector(
                                  onTap: _handleAvatarChange,
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.primary,
                                            width: 3,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 60,
                                          backgroundImage: _getAvatarImage(
                                              userProfile?['avatar_url']),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
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
                                if (userProfile?['displayname'] !=
                                    userProfile?['fullname'])
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
                                Text(
                                  authUser?.email ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Stats Row ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: 'Total Points',
                              value:
                                  '${userProfile?['totalpoints'] ?? 0}',
                              icon: Icons.star,
                              color: Colors.amber,
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              title: 'Monthly Points',
                              value:
                                  '${userProfile?['monthlypoints'] ?? 0}',
                              icon: Icons.calendar_month,
                              color: Colors.blue,
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              title: 'Current Streak',
                              value:
                                  '${userProfile?['currentstreak'] ?? 0}',
                              icon: Icons.local_fire_department,
                              color: Colors.orange,
                              colorScheme: colorScheme,
                            ),
                          ),
                        ],
                      ),

                      // ── ML Archetype Card ───────────────────────────
                      if (_mlProfile != null) ...[
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          final archetype =
                              MLService.getArchetype(_mlProfile);
                          final emoji =
                              MLService.getArchetypeEmoji(archetype);
                          final color = Color(
                              MLService.getArchetypeColor(archetype));
                          final isProvisional =
                              MLService.isProvisional(_mlProfile);
                          final daysActive =
                              ((_mlProfile!['days_active'] as num?) ?? 0)
                                  .toInt();
                          final alpha =
                              ((_mlProfile!['alpha'] as num?) ?? 1.0)
                                  .toDouble();
                          final confidence =
                              ((_mlProfile!['confidence'] as num?) ?? 0.0)
                                  .toDouble();

                          return Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color:
                                              color.withOpacity(0.15),
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
                                              'Productivity Archetype',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 12,
                                                color: colorScheme
                                                    .onSurface
                                                    .withOpacity(0.5),
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isProvisional
                                                  ? 'Learning your patterns...'
                                                  : archetype,
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 15,
                                                color: isProvisional
                                                    ? colorScheme
                                                        .onSurface
                                                        .withOpacity(0.4)
                                                    : color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Confidence bar
                                  Row(
                                    children: [
                                      Text(
                                        'Confidence',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: confidence,
                                            minHeight: 8,
                                            backgroundColor: colorScheme
                                                .onSurface
                                                .withOpacity(0.1),
                                            color: isProvisional
                                                ? Colors.grey
                                                : color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(confidence * 100).toInt()}%',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Days active + personalisation level
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _mlInfoChip(
                                        '$daysActive days active',
                                        Icons.calendar_today,
                                        colorScheme,
                                      ),
                                      _mlInfoChip(
                                        '${((1 - alpha) * 100).toInt()}% personalised',
                                        Icons.tune,
                                        colorScheme,
                                      ),
                                      _mlInfoChip(
                                        isProvisional
                                            ? 'Provisional'
                                            : 'Confirmed',
                                        isProvisional
                                            ? Icons.hourglass_top
                                            : Icons.check_circle,
                                        colorScheme,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 32),

                      // ── Action Buttons ──────────────────────────────
                      _profileTile(
                        icon: Icons.edit,
                        label: 'Edit Details',
                        colorScheme: colorScheme,
                        onTap: _showEditProfileDialog,
                      ),

                      _profileTile(
                        icon: Icons.settings,
                        label: 'Settings',
                        colorScheme: colorScheme,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: colorScheme.surface,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (context) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Settings",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ListTile(
                                      leading: Icon(Icons.lock_outline,
                                          color: colorScheme.primary),
                                      title: const Text(
                                          "Change Password"),
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showChangePasswordDialog();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
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
                              title: const Text("Confirm Logout"),
                              content: const Text(
                                  "Are you sure you want to logout?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await Supabase.instance.client.auth
                                        .signOut();
                                    if (context.mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LoginPage()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text("Logout"),
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

  // ── ML info chip helper ─────────────────────────────────────────────
  Widget _mlInfoChip(
      String label, IconData icon, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12, color: colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat card ───────────────────────────────────────────────────────
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
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

  // ── Profile tile ────────────────────────────────────────────────────
  Widget _profileTile({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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