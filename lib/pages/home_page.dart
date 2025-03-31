import 'package:encounter_app/pages/new_post.dart';
import 'package:encounter_app/pages/feed.dart';
import 'package:encounter_app/pages/filter_page.dart';
import 'package:encounter_app/pages/sign_in.dart';
import 'package:encounter_app/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/message_page.dart';
import 'package:encounter_app/utils/location_permission_utils.dart';
import 'package:encounter_app/utils/post_location_filter.dart';

class HomePage extends StatefulWidget {
  final int selectedIndex;
  final String? selectedUserId;

  const HomePage({super.key, this.selectedIndex = 0, this.selectedUserId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  late int _selectedIndex;
  late List<Widget> _screens;
  late String? selectedUserId; // Track the selected user's profile
  bool _locationPermissionChecked = false;
  bool _locationAvailable = false; // Track if location is available

  @override
  void initState() {
    super.initState();
    _selectedIndex = (widget.selectedIndex >= 0 && widget.selectedIndex < 3) 
        ? widget.selectedIndex 
        : 0;
    selectedUserId = widget.selectedUserId; // Store selected user ID

    _screens = [
      FeedScreen(), 
      MessagesPage(), 
      ProfilePage(userId: selectedUserId ?? Supabase.instance.client.auth.currentUser!.id),
    ];
    
    // Check location permissions after widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
  }

  // Check and request location permission
  Future<void> _checkLocationPermission() async {
    if (_locationPermissionChecked) return;
    
    // Check if location is available
    final locationAvailable = await PostLocationFilter.isLocationAvailable();
    setState(() {
      _locationAvailable = locationAvailable;
    });
    
    // If no location, show a snackbar to guide the user
    if (!locationAvailable && _selectedIndex == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location services disabled. Enable to see nearby posts.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Enable',
              onPressed: () async {
                await _requestLocationPermission();
              },
            ),
          ),
        );
      }
    }
    
    bool shouldRequest = await LocationPermissionUtils.shouldRequestLocationPermission();
    if (shouldRequest) {
      await _requestLocationPermission();
    } else if (locationAvailable) {
      // If we already have permission, just update location
      _updateUserLocation();
    }
    
    setState(() {
      _locationPermissionChecked = true;
    });
  }
  
  // Request location permission
  Future<void> _requestLocationPermission() async {
    final permissionGranted = await LocationPermissionUtils.requestLocationPermission(context);
    
    if (permissionGranted) {
      setState(() {
        _locationAvailable = true;
      });
      await _updateUserLocation();
      
      // Refresh the current screen if it's the feed
      if (_selectedIndex == 0 && mounted) {
        setState(() {}); // Trigger a rebuild
      }
    }
  }
  
  // Update user location in the database
  Future<void> _updateUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );
      
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'last_location_update': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }
    } catch (e) {
      // Handle errors silently to not interrupt the user experience
      debugPrint('Error updating location: $e');
    }
  }

  void _navigateToNewPost() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPost()));
  }

  void _onNavBarTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      
      // Check location if navigating to feed
      if (index == 0 && !_locationAvailable) {
        _checkLocationPermission();
      }
    }
  }

  void _openFilterPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FilterPage()));
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SignInPage(onTap: () {})),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0 
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterPage,
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Encounter', style: TextStyle(fontWeight: FontWeight.bold)),
                  // Show location indicator
                  if (!_locationAvailable)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: GestureDetector(
                        onTap: _requestLocationPermission,
                        child: const Icon(
                          Icons.location_disabled,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              actions: [
                // Location toggle button
                if (_selectedIndex == 0)
                  IconButton(
                    icon: Icon(
                      _locationAvailable ? Icons.location_on : Icons.location_off,
                      color: _locationAvailable ? Colors.green : Colors.red,
                    ),
                    onPressed: _requestLocationPermission,
                  ),
                IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
              ],
            )
          : null,
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _navigateToNewPost,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}