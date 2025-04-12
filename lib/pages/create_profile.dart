import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/l10n/app_localizations.dart';
import 'home_page.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _imageFile;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false; // Loading state
  DateTime? _selectedBirthdate; // Selected birthdate

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _avatarUrl = null; // Clear previous avatar URL
      });
      await _uploadImage(_imageFile!);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final fileExt = imageFile.path.split('.').last;
    final fileName = '$userId/avatar.$fileExt';
    final filePath = 'avatars/$fileName';

    setState(() {
      _isUploading = true; // Show loading
    });

    try {
      final bytes = await imageFile.readAsBytes(); // Read file as bytes
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);

      setState(() {
        _avatarUrl = imageUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false; // Hide loading
      });
    }
  }

  Future<void> _saveProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    if (_selectedBirthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthdate')),
      );
      return;
    }

    // Calculate age
    final DateTime today = DateTime.now();
    int age = today.year - _selectedBirthdate!.year;
    if (today.month < _selectedBirthdate!.month ||
        (today.month == _selectedBirthdate!.month && today.day < _selectedBirthdate!.day)) {
      age--; // Adjust if birthday hasn't occurred yet this year
    }

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'birthdate': _selectedBirthdate!.toIso8601String(), // Save full birthdate
        'age': age, // Save calculated age
        'avatar_url': _avatarUrl ?? '',
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile save failed: $e')),
      );
    }
  }

  Future<void> _pickBirthdate() async {
    DateTime initialDate = _selectedBirthdate ?? DateTime.now().subtract(const Duration(days: 365 * 18)); // Default to 18 years ago
    DateTime firstDate = DateTime(1900);
    DateTime lastDate = DateTime.now();

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        _selectedBirthdate = pickedDate;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.camera_alt, size: 40) : SizedBox.shrink(),
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
            const SizedBox(height: 10),

            // Birthdate Picker
            ListTile(
              title: Text(
                _selectedBirthdate == null
                    ? 'Select Birthdate'
                    : 'Birthdate: ${_selectedBirthdate!.toLocal()}'.split(' ')[0],
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickBirthdate,
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
