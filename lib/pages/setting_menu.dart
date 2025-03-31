import 'package:flutter/material.dart';
import 'package:encounter_app/pages/edit_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SettingsMenu extends StatefulWidget {
  const SettingsMenu({super.key});

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    if (mounted) {
      setState(() {
        _profile = response;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            // Profile Section
            const SizedBox(height: 20),

            // Menu Items
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Edit Profile"),
              onTap: ()
               {
                if (_profile != null) {
                Navigator.pushReplacement(context, 
                MaterialPageRoute(builder: (context) => EditProfilePage(profile: _profile!,)
                ),
                ).then((_) => _fetchUserProfile()); // Refresh profile on return
                }
               }
            ),
            ListTile(
              leading: const Icon(Icons.verified),
              title: const Text("Premium"),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              title: const Text("Settings and privacy"),
              onTap: () {},
            ),
            ListTile(
              title: const Text("Help Center"),
              onTap: () {},
            ),

            // Discord Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: Image.asset("assets/icons/discord.png"), // Replace with Discord icon asset
                iconSize: 40,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
