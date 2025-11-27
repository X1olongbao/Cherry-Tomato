import 'package:flutter/material.dart';
import 'package:tomatonator/services/auth_service.dart';
import 'package:tomatonator/landingpage/landing_page.dart';
import 'package:tomatonator/homepage/privacy_security_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tomatonator/homepage/edit_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tomatonator/services/profile_service.dart';

const tomatoRed = Color(0xFFE53935);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    ProfileService.instance.displayName.addListener(_onProfileNameChanged);
    // Ensure latest name is fetched for current user
    ProfileService.instance.refreshCurrentUserProfile();
  }

  void _onProfileNameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAvatar() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        if (mounted) setState(() => _avatarUrl = null);
        return;
      }
      final row = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      String? url;
      if (row is Map && row['avatar_url'] is String) {
        final s = (row['avatar_url'] as String).trim();
        if (s.isNotEmpty) url = s;
      }
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {}
  }

  @override
  void dispose() {
    ProfileService.instance.displayName.removeListener(_onProfileNameChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // ✅ Prevent overlap
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back Button & Title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _handleBack(context),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Profile",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Profile Picture
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.black12,
                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? NetworkImage(_avatarUrl!)
                        : const AssetImage('assets/profile/profile_pic.png')
                            as ImageProvider,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Builder(builder: (context) {
                final user = AuthService.instance.currentUser;
                final displayName = ProfileService.instance.displayName.value ??
                    (user?.email?.split('@').first ?? 'Cherry');
                final displayEmail = user?.email ?? 'Not logged in';
                return Column(
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      displayEmail,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 36),

              // Profile Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Profile",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildListTile(Icons.person_outline, "Edit Profile", onTap: () async {
                final user = AuthService.instance.currentUser;
                final result = await Connectivity().checkConnectivity();
                final offline = result == ConnectivityResult.none;
                if (user == null || offline) {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Please sign in first'),
                      content: const Text('This action requires an online signed-in session.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                      ],
                    ),
                  );
                  return;
                }
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const EditProfilePage()))
                    .then((updated) async {
                  if (updated == true) {
                    await _loadAvatar();
                    ProfileService.instance.refreshCurrentUserProfile();
                  }
                });
              }),
              const SizedBox(height: 8),
              _buildListTile(Icons.lock_outline, "Privacy"),

              const SizedBox(height: 40), // ✅ extra space before logout

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // Capture Navigator and Messenger before the async gap
                    final navigator = Navigator.of(context);
                    try {
                      await AuthService.instance.signOut();
                      if (!mounted) return;
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LandingPage()),
                        (route) => false,
                      );
                    } catch (e) {
                      if (!mounted) return;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tomatoRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    "Log Out",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // ✅ bottom safe padding
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildListTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap ?? () {
          if (title == 'Privacy') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
            );
          }
        },
      ),
    );
  }
}
