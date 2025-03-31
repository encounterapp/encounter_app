import 'package:encounter_app/components/post_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/edit_profile.dart';
// Import the new file

class ProfilePage extends StatefulWidget {
  final String? userId; // If viewing another user's profile
  const ProfilePage({super.key, this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
    Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isCurrentUser = false;

  Future<void> _fetchProfile() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final profileId = widget.userId ?? currentUser?.id;

    if (profileId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _isCurrentUser = profileId == currentUser?.id;

    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', profileId)
        .single();

    setState(() {
      _profile = response;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return const Center(child: Text("Profile not found."));
    }

    return Scaffold(
      body: Column(
        children: [
          // Profile Banner
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                color: Colors.blueGrey, // Default banner color
                child: Image.network(
                  _profile!['banner_url'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey),
                ),
              ),
              // Profile Picture (Circular Avatar)
              Positioned(
                bottom: -40,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: _profile!['avatar_url'] != null
                      ? NetworkImage(_profile!['avatar_url'])
                      : null,
                  child: _profile!['avatar_url'] == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          
          // Username & Bio
          Text(
            _profile!['username'] ?? 'No username',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          
          // Display User Age
          if (_profile!['age'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 5),
              child: Text(
                'Age: ${_profile!['age']}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
          Text(
            _profile!['bio'] ?? 'No bio available',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),

          // Edit Profile Button (Only for Current User)
          if (_isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(profile: _profile!),
                    ),
                  ).then((_) => _fetchProfile()); // Refresh profile on return
                },
                child: const Text('Edit Profile'),
              ),
            ),

          const SizedBox(height: 20),

          // Tab Bar for Posts - Now in a separate file
          Expanded(
            child: PostsTabBar(userId: _profile!['id'],), // Use the imported widget
          ),
        ],
      ),
    );
  }
}