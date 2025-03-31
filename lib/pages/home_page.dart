import 'package:flutter/material.dart';
import 'package:encounter_app/utils/location_service_helper.dart';
import 'package:encounter_app/utils/enhanced_location_utils.dart';
import 'package:encounter_app/components/location_status_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/feed.dart';
import 'package:encounter_app/pages/filter_page.dart';
import 'package:encounter_app/pages/sign_in.dart';
import 'package:encounter_app/pages/profile_page.dart';
import 'package:encounter_app/pages/message_page.dart';
import 'package:encounter_app/pages/new_post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  final int selectedIndex;
  final String? selectedUserId;

  const HomePage({Key? key, this.selectedIndex = 0, this.selectedUserId}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  late int _selectedIndex;
  late List<Widget> _screens;
  late String? selectedUserId;
  
  // Location state
  final _locationService = LocationService.instance;
  bool _locationAvailable = false;
  bool _locationPermissionChecked = false;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = (widget.selectedIndex >= 0 && widget.selectedIndex < 3) 
        ? widget.selectedIndex 
        : 0;
    selectedUserId = widget.selectedUserId;

    _screens = [
      const FeedScreen(), 
      const MessagesPage(), 
      ProfilePage(userId: selectedUserId ?? Supabase.instance.client.auth.currentUser!.id),
    ];
    
    // Initialize location services after widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationServices();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we're returning to this page and reset location checking state
    if (_locationService.isCheckingLocation) {
      // Force a state refresh when returning to this page
      _locationService.refreshLocationState();
    }
  }
  
  // Initialize the location services
  Future<void> _initializeLocationServices() async {
    // Initialize the location service
    await _locationService.initialize();
    
    if (mounted) {
      setState(() {
        _locationAvailable = _locationService.isLocationAvailable;
      });
    }
    
    // Check if this is the first time asking for permission
    bool shouldRequest = await EnhancedLocationUtils.shouldRequestLocationPermission();
    
    if (shouldRequest && mounted) {
      // Show the permission dialog for the first time
      _showLocationPermissionDialog();
    } else if (!_locationAvailable && _selectedIndex == 0 && mounted) {
      // If we're on the feed screen and location is disabled, show snackbar
      _showLocationDisabledSnackbar();
    } else if (_locationAvailable) {
      // If location is available, update user location
      await _locationService.updateUserLocation();
    }
    
    if (mounted) {
      setState(() {
        _locationPermissionChecked = true;
      });
    }
  }
  
  // Show dialog to request location permission
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue[700]),
              const SizedBox(width: 10),
              const Text('Location Access'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encounter needs access to your location to:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.people, size: 20, color: Colors.blue[600]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Show you nearby users to connect with'),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.post_add, size: 20, color: Colors.blue[600]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Display relevant posts from people in your area'),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.event, size: 20, color: Colors.blue[600]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Find local events and activities'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.security, size: 20, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your exact location is never shared with other users without your explicit consent.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Mark that we've requested permission even if denied
                final prefs = SharedPreferences.getInstance();
                prefs.then((value) => value.setBool('has_requested_location', true));
              },
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestLocationPermission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Allow'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
  
  // Show snackbar when location is disabled
  void _showLocationDisabledSnackbar() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location services disabled. Enable to see nearby posts.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Enable',
          onPressed: _requestLocationPermission,
        ),
      ),
    );
  }
  
  // Request location permission
  Future<void> _requestLocationPermission() async {
    final permissionGranted = await _locationService.requestLocationPermission(context);
    
    if (mounted) {
      setState(() {
        _locationAvailable = permissionGranted;
      });
    }
    
    if (permissionGranted) {
      // Update location in database
      await _locationService.updateUserLocation();
      
      // Refresh the current screen if it's the feed
      if (_selectedIndex == 0 && mounted) {
        setState(() {}); // Trigger a rebuild
      }
    }
  }
  
  // Navigation bar tap handler
  void _onNavBarTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      
      // Check location if navigating to feed and location is disabled
      if (index == 0 && !_locationAvailable && _locationPermissionChecked) {
        _showLocationDisabledSnackbar();
      }
    }
  }
  
  // Open filter page
  void _openFilterPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FilterPage()));
  }
  
  // Sign out
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SignInPage(onTap: () {})),
      );
    }
  }
  
  // Navigate to new post
  void _navigateToNewPost() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPost()));
  }

  @override
  void dispose() {
    // Cancel any pending location operations
    if (_locationService.isCheckingLocation) {
      _locationService.cancelLocationChecks();
    }
    super.dispose();
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
                  const SizedBox(width: 8),
                  StreamBuilder<LocationState>(
                    stream: _locationService.locationStateStream,
                    initialData: LocationState(
                      isAvailable: _locationService.isLocationAvailable,
                      isChecking: _locationService.isCheckingLocation,
                      position: _locationService.lastKnownPosition,
                    ),
                    builder: (context, snapshot) {
                      final state = snapshot.data!;
                      
                      if (state.isChecking) {
                        return const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        );
                      }
                      
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isAvailable ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                // Location status widget with small icon
                StreamBuilder<LocationState>(
                  stream: _locationService.locationStateStream,
                  initialData: LocationState(
                    isAvailable: _locationService.isLocationAvailable,
                    isChecking: _locationService.isCheckingLocation,
                    position: _locationService.lastKnownPosition,
                  ),
                  builder: (context, snapshot) {
                    final state = snapshot.data!;
                    
                    return IconButton(
                      icon: state.isChecking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              state.isAvailable ? Icons.location_on : Icons.location_off,
                              color: state.isAvailable ? Colors.green : Colors.red,
                            ),
                      onPressed: state.isChecking ? null : _requestLocationPermission,
                    );
                  },
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                ),
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