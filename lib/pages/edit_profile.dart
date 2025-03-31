import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/home_page.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _avatarImageFile;
  File? _bannerImageFile;
  String? _avatarUrl;
  String? _bannerUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.profile['username'] ?? '';
    _bioController.text = widget.profile['bio'] ?? '';
    _avatarUrl = widget.profile['avatar_url'];
    _bannerUrl = widget.profile['banner_url'];
  }

  /// Pick and upload profile avatar
  Future<void> _pickAvatarImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _avatarImageFile = File(pickedFile.path));
      await _uploadAvatarImage();
    }
  }

  /// Pick and upload banner image
  Future<void> _pickBannerImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _bannerImageFile = File(pickedFile.path));
      await _uploadBannerImage();
    }
  }

  /// Upload avatar image to Supabase
  Future<void> _uploadAvatarImage() async {
    setState(() => _isUploadingAvatar = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final fileExt = _avatarImageFile!.path.split('.').last;
    final fileName = '$userId/avatars.$fileExt';
    final filePath = 'avatars/$fileName';

    try {
      await Supabase.instance.client.storage.from('avatars').upload(
            filePath,
            _avatarImageFile!,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);

      setState(() {
        _avatarUrl = imageUrl;
        _isUploadingAvatar = false;
      });

      // Update avatar URL in database
      await Supabase.instance.client.from('profiles').update({'avatar_url': _avatarUrl}).eq('id', userId);
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    }
  }

  /// Upload banner image to Supabase
  Future<void> _uploadBannerImage() async {
    setState(() => _isUploadingBanner = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final fileExt = _bannerImageFile!.path.split('.').last;
    final fileName = '$userId/banners.$fileExt';
    final filePath = 'banners/$fileName';

    try {
      await Supabase.instance.client.storage.from('banners').upload(
            filePath,
            _bannerImageFile!,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage.from('banners').getPublicUrl(filePath);

      setState(() {
        _bannerUrl = imageUrl;
        _isUploadingBanner = false;
      });

      // Update banner URL in database
      await Supabase.instance.client.from('profiles').update({'banner_url': _bannerUrl}).eq('id', userId);
    } catch (e) {
      setState(() => _isUploadingBanner = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banner upload failed: $e')));
    }
  }

  /// Update profile (username & bio)
  Future<void> _updateProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('profiles').update({
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
    }).eq('id', userId);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));

        // Navigate back to Profile Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage(selectedIndex: 2)),
    );
  }

  /// Cancel editing and return to the Profile Page
  void _cancelEdit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage(selectedIndex: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Banner Image
            GestureDetector(
              onTap: _pickBannerImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.blueGrey,
                    child: _bannerUrl != null
                        ? Image.network(_bannerUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 50, color: Colors.white),
                  ),
                  if (_isUploadingBanner) const CircularProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap banner to change"),
            
            const SizedBox(height: 20),

            // Profile Avatar
            GestureDetector(
              onTap: _pickAvatarImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                  if (_isUploadingAvatar) const CircularProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap profile picture to change"),

            const SizedBox(height: 20),
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
            const SizedBox(height: 20),

            // Save and Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _cancelEdit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}