import 'package:flutter/material.dart';
import 'package:encounter_app/pages/edit_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/subscription_service.dart';

class SettingsMenu extends StatefulWidget {
  const SettingsMenu({super.key});

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  SubscriptionTier _subscriptionTier = SubscriptionTier.free;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchSubscriptionTier();
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

  Future<void> _fetchSubscriptionTier() async {
    try {
      final subscriptionService = SubscriptionService();
      final tier = await subscriptionService.getCurrentTier();
      
      if (mounted) {
        setState(() {
          _subscriptionTier = tier;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription tier: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
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
              onTap: () {
                if (_profile != null) {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(profile: _profile!),
                    ),
                  ).then((_) => _fetchUserProfile()); // Refresh profile on return
                }
              }
            ),
            
            // Premium Tile with badge for the current tier
            ListTile(
              leading: Icon(
                Icons.workspace_premium,
                color: _subscriptionTier == SubscriptionTier.free ? Colors.grey : Colors.amber,
              ),
              title: const Text("Premium"),
              subtitle: _isLoadingSubscription
                  ? const Text("Loading subscription info...")
                  : Text(
                      "Current: ${SubscriptionService.tierNames[_subscriptionTier] ?? 'Free'}",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _subscriptionTier == SubscriptionTier.free
                            ? Colors.grey[600]
                            : Colors.amber[700],
                      ),
                    ),
              trailing: _subscriptionTier != SubscriptionTier.free
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Active",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context); // Close drawer first
                Navigator.pushNamed(context, '/premium');
              },
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