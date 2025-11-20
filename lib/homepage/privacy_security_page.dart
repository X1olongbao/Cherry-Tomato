import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class _InstalledApp {
  final String name;
  final String package;
  const _InstalledApp(this.name, this.package);
}

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _oldVisible = false;
  bool _newVisible = false;

  bool notificationsEnabled = true;
  bool appBlockerEnabled = true;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedApps = <String>{};
  final Map<String, Uint8List> _appIcons = <String, Uint8List>{};
  bool _isScanning = false;
  List<_InstalledApp> _installedApps = [];
  static const MethodChannel _appsChannel = MethodChannel('com.example.tomatonator/installed_apps');
  static const MethodChannel _blockerChannel = MethodChannel('com.example.tomatonator/installed_apps');
  static const String _blockedKey = 'blocked_packages';

  bool get _isOAuthLogin {
    final fUser = fb.FirebaseAuth.instance.currentUser;
    if (fUser == null) return false;
    final providers = fUser.providerData.map((p) => p.providerId).toList();
    // Common OAuth providers; expand if you add more.
    return providers.contains('google.com') || providers.contains('github.com') || providers.contains('apple.com');
  }

  Future<void> _handleChangePassword() async {
    if (_isOAuthLogin) return;
    final messenger = ScaffoldMessenger.of(context);
    final oldPwd = _oldPwdCtrl.text.trim();
    final newPwd = _newPwdCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Enter both old and new password')));
      return;
    }
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null || email.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('No logged-in email found')));
        return;
      }
      // Basic verification: try signing in with old password (non-destructive)
      await AuthService.instance.signIn(email: email, password: oldPwd);
      // If successful, update current user password
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPwd));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      // Optional: pop after success
      // navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Password change failed: $e')));
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout from All Devices'),
        content: const Text('Are you sure you want to logout from all devices?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Supabase global signout; falls back if not supported
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.global);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Logged out from all devices')));
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Logged out on this device')));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  // Removed unused filtered list (local search handles filtering within the sheet).

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
  }

  Future<void> _scanApps() async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      messenger.showSnackBar(const SnackBar(content: Text('Scanning installed apps is available on Android only.')));
      return;
    }
    setState(() => _isScanning = true);
    try {
      final raw = await _appsChannel.invokeMethod<List<dynamic>>('getInstalledApps');
      final apps = (raw ?? const [])
          .map((e) {
            final m = (e as Map).cast<String, dynamic>();
            final name = (m['name'] ?? '').toString();
            final pkg = (m['package'] ?? '').toString();
            return _InstalledApp(name, pkg);
          })
          .where((a) => a.package.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _installedApps = apps;
      });
      if (apps.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No launchable user apps found.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to scan apps: $e')));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _loadBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedKey) ?? <String>[];
    setState(() {
      _selectedApps
        ..clear()
        ..addAll(list);
    });
    await _ensureIconsForSelected();
  }

  Future<void> _saveBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedKey, _selectedApps.toList());
    await _ensureIconsForSelected();
  }

  Future<void> _ensureIconsForSelected() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    for (final pkg in _selectedApps) {
      if (_appIcons.containsKey(pkg)) continue;
      final bytes = await _fetchAppIcon(pkg);
      if (bytes != null) {
        setState(() {
          _appIcons[pkg] = bytes;
        });
      }
    }
  }

  Future<Uint8List?> _fetchAppIcon(String package) async {
    try {
      final bytes = await _appsChannel.invokeMethod<Uint8List>('getAppIcon', {
        'package': package,
      });
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAppPicker() async {
    if (_installedApps.isEmpty) {
      await _scanApps();
    }
    if (!mounted) return;
    final localSearch = TextEditingController(text: _searchCtrl.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = localSearch.text.trim().toLowerCase();
            final items = (_installedApps.isEmpty ? const <_InstalledApp>[] : _installedApps)
                .where((a) => query.isEmpty || a.name.toLowerCase().contains(query) || a.package.toLowerCase().contains(query))
                .toList(growable: false);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Select Apps to Block', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isScanning ? null : () async {
                            await _scanApps();
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: localSearch,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search apps',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final app = items[index];
                          final selected = _selectedApps.contains(app.package);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedApps.add(app.package);
                                } else {
                                  _selectedApps.remove(app.package);
                                }
                              });
                              _saveBlockedApps();
                              setSheetState(() {});
                            },
                            title: Text(app.name),
                            subtitle: Text(app.package, style: const TextStyle(color: Colors.black54)),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    localSearch.dispose();
  }

  Future<void> _ensureInterceptionPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final messenger = ScaffoldMessenger.of(context);
    final usageGranted = await _blockerChannel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
    final overlayGranted = await _blockerChannel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
    if (!usageGranted) {
      await _blockerChannel.invokeMethod('openUsageAccessSettings');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Enable Usage Access for Cherry Tomato.')));
    }
    if (!overlayGranted) {
      await _blockerChannel.invokeMethod('openOverlaySettings');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Enable “Draw over other apps” permission.')));
    }
  }

  Future<void> _startInterception() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final messenger = ScaffoldMessenger.of(context);
    // Prompt for permissions if needed before starting
    final proceed = await _confirmPermissionsIfNeeded();
    if (!proceed) {
      setState(() => appBlockerEnabled = false);
      return;
    }
    await _ensureInterceptionPermissions();
    final pkgs = _selectedApps.toList();
    try {
      await _blockerChannel.invokeMethod('startAppBlocker', { 'packages': pkgs });
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('App interception started.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to start interception: $e')));
    }
  }

  Future<void> _stopInterception() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _blockerChannel.invokeMethod('stopAppBlocker');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('App interception stopped.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to stop interception: $e')));
    }
  }

  Future<bool> _confirmPermissionsIfNeeded() async {
    try {
      final usageGranted = await _blockerChannel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
      final overlayGranted = await _blockerChannel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
      if (usageGranted && overlayGranted) return true;
      if (!mounted) return false;
      return await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Permissions Required'),
                content: const Text(
                    'Cherry Tomato needs Usage Access and "Draw over other apps" permissions to block apps. Grant access now?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Grant')),
                ],
              );
            },
          ) ??
          false;
    } catch (_) {
      return true; // If check fails, attempt to proceed and handle in ensure
    }
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey.shade100;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Security'),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.lock_outline, 'Change Password'),
                const SizedBox(height: 12),
                IgnorePointer(
                  ignoring: _isOAuthLogin,
                  child: Opacity(
                    opacity: _isOAuthLogin ? 0.6 : 1.0,
                    child: Column(
                      children: [
                        _passwordField('Old Password', _oldPwdCtrl, _oldVisible, () {
                          setState(() => _oldVisible = !_oldVisible);
                        }),
                        const SizedBox(height: 12),
                        _passwordField('New Password', _newPwdCtrl, _newVisible, () {
                          setState(() => _newVisible = !_newVisible);
                        }),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isOAuthLogin ? null : _handleChangePassword,
                            child: const Text('Confirm Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isOAuthLogin) ...[
                  const SizedBox(height: 12),
                  _helpText(
                    'Password cannot be changed because you logged in using Google. '
                    'Manage your password via your Google account.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.logout, 'Logout from All Devices'),
                const SizedBox(height: 8),
                _helpText('Logs you out from all sessions on all devices.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _logoutAllDevices,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Logout Everywhere'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('App Blocker & Permissions'),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.notifications_none, 'Notification Toggle'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: notificationsEnabled,
                    onChanged: (val) => setState(() => notificationsEnabled = val),
                    activeThumbColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.block, 'App Blocker Toggle'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: appBlockerEnabled,
                    onChanged: (val) async {
                      setState(() => appBlockerEnabled = val);
                      if (val) {
                        await _startInterception();
                      } else {
                        await _stopInterception();
                      }
                    },
                    activeThumbColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.apps, 'App Selection'),
                const SizedBox(height: 8),
                _helpText('Select which apps to block during Pomodoro sessions. Applied to all sessions.'),
                const SizedBox(height: 12),

                // Add-style picker trigger (instead of Scan button)
                if (_installedApps.isEmpty) ...[
                  GestureDetector(
                    onTap: _showAppPicker,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                              ),
                              child: const Icon(Icons.add, size: 24, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _helpText('Tap the card to pick apps to block.'),
                ] else ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isScanning ? null : _scanApps,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Rescan'),
                      ),
                      const SizedBox(width: 8),
                      if (_isScanning) const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAppPicker,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Apps'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Removed inline search; search is available inside the picker
                const SizedBox(height: 4),
                // Card container shows currently blocked apps with icons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Plus button is the only clickable area to add apps
                      Positioned(
                        top: 6,
                        left: 6,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _showAppPicker,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                            ),
                            child: const Icon(Icons.add, size: 22, color: Colors.black87),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 52),
                        child: _selectedApps.isEmpty
                            ? Center(
                                child: Text(
                                  'No apps selected',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              )
                            : Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _selectedApps.map((pkg) {
                                  final info = _installedApps.firstWhere(
                                    (a) => a.package == pkg,
                                    orElse: () => _InstalledApp(pkg.split('.').last, pkg),
                                  );
                                  final iconBytes = _appIcons[pkg];
                                  return SizedBox(
                                    width: 96,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.white,
                                          backgroundImage: iconBytes != null ? MemoryImage(iconBytes) : null,
                                          child: iconBytes == null ? const Icon(Icons.apps, color: Colors.black54) : null,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          info.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );
  }

  Widget _tileHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _helpText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black54),
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl, bool visible, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // 2xl rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}