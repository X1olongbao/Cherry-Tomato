import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tomatonator/services/auth_service.dart';
import 'package:tomatonator/services/profile_service.dart';
import 'package:tomatonator/services/notification_service.dart';
import 'package:tomatonator/models/app_notification.dart';
import 'package:uuid/uuid.dart';
import 'package:tomatonator/userloginforgot/email_otp_verification_page.dart';

const tomatoRed = Color(0xFFE53935);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _avatarUrl;
  File? _selectedImage;
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        // Load username and avatar URL from profiles table
        final supabase = Supabase.instance.client;
        final profile = await supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profile != null) {
          // Load username from profiles table (this matches what's displayed)
          if (profile['username'] != null) {
            _usernameController.text = (profile['username'] as String).trim();
            _originalUsername = _usernameController.text;
          } else {
            // Fallback to auth metadata if not in profiles table
            _usernameController.text = user.username ?? '';
            _originalUsername = _usernameController.text;
          }
          
          if (profile['avatar_url'] != null) {
            _avatarUrl = profile['avatar_url'] as String;
          }
        } else {
          // If no profile exists, use auth metadata
          _usernameController.text = user.username ?? '';
          _originalUsername = _usernameController.text;
        }
      }
    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {}
  }

  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      
      // Upload to Supabase storage (use Uint8List directly)
      await supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      
      // Get public URL
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);
      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final supabase = Supabase.instance.client;
      final username = _usernameController.text.trim();

      // Upload image if selected
      String? avatarUrl = _avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await _uploadImage(_selectedImage!, user.id);
      }

      // Update profile in profiles table
      final profileData = <String, dynamic>{
        'id': user.id,
      };
      
      if (username.isNotEmpty && username != user.username) {
        profileData['username'] = username;
      }
      
      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }
      
      if (profileData.length > 1) { // More than just id
        try {
          await supabase.from('profiles').update(profileData).eq('id', user.id);
        } catch (_) {
          await supabase.from('profiles').upsert(profileData);
        }
      }

      // Update user metadata with username
      await supabase.auth.updateUser(
        UserAttributes(data: {'username': username}),
      );

      // Refresh profile service
      await ProfileService.instance.refreshCurrentUserProfile();

      // Add notification if username was changed
      if (username.isNotEmpty && username != _originalUsername) {
        NotificationService.instance.add(
          AppNotification(
            id: const Uuid().v4(),
            title: 'Profile Updated',
            message: 'You successfully changed your username to "$username"',
            createdAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: tomatoRed,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.black12,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : const AssetImage('assets/profile/profile_pic.png')) as ImageProvider,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: tomatoRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
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
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Enter username',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Colors.black54,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AuthService.instance.currentUser?.email ?? 'No email',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tomatoRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

