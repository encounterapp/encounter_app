import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/home_page.dart';
import 'package:encounter_app/l10n/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _customGenderController = TextEditingController();
  File? _avatarImageFile;
  File? _bannerImageFile;
  String? _avatarUrl;
  String? _bannerUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;
  
  // Gender selection
  List<String> _genderOptions = [];
  String _selectedGender = 'None';
  bool _showCustomGenderField = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.profile['username'] ?? '';
    _bioController.text = widget.profile['bio'] ?? '';
    _avatarUrl = widget.profile['avatar_url'];
    _bannerUrl = widget.profile['banner_url'];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize gender options with localized strings
    _genderOptions = [
      AppLocalizations.of(context).male,
      AppLocalizations.of(context).female,
      AppLocalizations.of(context).other,
      AppLocalizations.of(context).none
    ];
    
    // Set selected gender if it exists in profile
    if (widget.profile['gender'] != null) {
      // Convert the stored gender to the localized version if possible
      final storedGender = widget.profile['gender'];
      // Check if gender matches one of our standard options (accounting for possible language differences)
      bool foundMatch = false;
      
      // This is a bit complex because we're trying to match potentially non-localized 
      // stored values with localized UI values
      if (storedGender.toLowerCase() == 'male' || 
          storedGender == AppLocalizations.of(context).male) {
        _selectedGender = AppLocalizations.of(context).male;
        foundMatch = true;
      } else if (storedGender.toLowerCase() == 'female' || 
                 storedGender == AppLocalizations.of(context).female) {
        _selectedGender = AppLocalizations.of(context).female;
        foundMatch = true;
      } else if (storedGender.toLowerCase() == 'other' || 
                 storedGender == AppLocalizations.of(context).other) {
        _selectedGender = AppLocalizations.of(context).other;
        _showCustomGenderField = true;
        foundMatch = true;
      } else if (storedGender.toLowerCase() == 'none' || 
                 storedGender == AppLocalizations.of(context).none) {
        _selectedGender = AppLocalizations.of(context).none;
        foundMatch = true;
      }
      
      // If gender doesn't match standard options, it's a custom gender
      if (!foundMatch) {
        _selectedGender = AppLocalizations.of(context).other;
        _customGenderController.text = storedGender;
        _showCustomGenderField = true;
      }
    }
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

    // Ensure path follows the pattern: userId/filename
    final fileExt = _avatarImageFile!.path.split('.').last;
    final fileName = 'avatars.$fileExt';
    final filePath = '$userId/$fileName';

    try {
      debugPrint('Uploading avatar to path: $filePath for user: $userId');
      
      final bytes = await _avatarImageFile!.readAsBytes();
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);
      debugPrint('Successfully uploaded avatar, URL: $imageUrl');

      setState(() {
        _avatarUrl = imageUrl;
        _isUploadingAvatar = false;
      });

      // Update avatar URL in database
      await Supabase.instance.client.from('profiles').update({'avatar_url': _avatarUrl}).eq('id', userId);
    } catch (e) {
      debugPrint('Avatar upload error: $e');
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
    final fileName = 'banners.$fileExt';
    final filePath = '$userId/$fileName';

    try {
      final bytes = await _bannerImageFile!.readAsBytes();
      await Supabase.instance.client.storage.from('banners').uploadBinary(
            filePath,
            bytes,
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

  /// Update profile (username, bio, gender)
  Future<void> _updateProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Build the update map
    final Map<String, dynamic> updateMap = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
    };

    // Convert the UI localized gender to a standard storage value
    // for consistent database storage across languages
    String standardGenderValue = 'none';
    
    // Add gender field only if it's not 'None'
    if (_selectedGender != AppLocalizations.of(context).none) {
      if (_selectedGender == AppLocalizations.of(context).male) {
        standardGenderValue = 'male';
      } else if (_selectedGender == AppLocalizations.of(context).female) {
        standardGenderValue = 'female';
      } else if (_selectedGender == AppLocalizations.of(context).other) {
        // Use custom gender text if available
        if (_customGenderController.text.isNotEmpty) {
          standardGenderValue = _customGenderController.text.trim();
        } else {
          standardGenderValue = 'other';
        }
      }
      updateMap['gender'] = standardGenderValue;
    } else {
      // If 'None' is selected, set gender to null to remove it from the profile
      updateMap['gender'] = null;
    }

    await Supabase.instance.client.from('profiles').update(updateMap).eq('id', userId);

    // Use a localized success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).saveChanges))
    );

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
    // Get localized strings
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(localizations.editProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(localizations.close),
            
            const SizedBox(height: 20),

            // Profile Avatar
            Center(
              child: GestureDetector(
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
            ),
            const SizedBox(height: 10),
            Center(child: Text(localizations.editProfile)),

            const SizedBox(height: 20),
            
            // Profile Form
            TextField(
              controller: _usernameController, 
              decoration: InputDecoration(
                labelText: localizations.username,
                border: const OutlineInputBorder(),
              )
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _bioController, 
              decoration: InputDecoration(
                labelText: localizations.bio,
                border: const OutlineInputBorder(),
              ), 
              maxLines: 3
            ),
            
            const SizedBox(height: 16),

            // Gender Selection
            Text(
              localizations.gender,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _genderOptions.map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                  _showCustomGenderField = value == localizations.other;
                });
              },
            ),
            
            // Custom Gender Field (shown only when "Other" is selected)
            if (_showCustomGenderField) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customGenderController,
                decoration: InputDecoration(
                  labelText: localizations.gender,
                  border: const OutlineInputBorder(),
                  hintText: localizations.other,
                ),
              ),
            ],
            
            const SizedBox(height: 24),

            // Save and Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _cancelEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(localizations.cancel, style: const TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(localizations.saveChanges, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}