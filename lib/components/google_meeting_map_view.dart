import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleMeetingMapView extends StatefulWidget {
  final String currentUserId;
  final String recipientId;
  final String recipientUsername;

  const GoogleMeetingMapView({
    Key? key,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientUsername,
  }) : super(key: key);

  @override
  State<GoogleMeetingMapView> createState() => _GoogleMeetingMapViewState();
}

class _GoogleMeetingMapViewState extends State<GoogleMeetingMapView> {
  // Google Maps controller
  final Completer<GoogleMapController> _controller = Completer();
  
  // Locations
  LatLng? _currentUserLocation;
  LatLng? _recipientLocation;
  
  // Markers and polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;
  
  // Timers for location updates
  Timer? _locationUpdateTimer;
  Timer? _locationFetchTimer;
  
  // Custom marker icons
  BitmapDescriptor? _userMarkerIcon;
  BitmapDescriptor? _recipientMarkerIcon;
  
  @override
  void initState() {
    super.initState();
    _initializeIcons().then((_) => _initializeMap());
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _locationFetchTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeIcons() async {
    try {
      // Load custom marker icons
      _userMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/user_marker.png',
      ).catchError((error) {
        // Fallback to default marker if asset not found
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      });
      
      _recipientMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/recipient_marker.png',
      ).catchError((error) {
        // Fallback to default marker if asset not found
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      });
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
    }
    
    // Set default markers if loading custom ones failed
    _userMarkerIcon ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _recipientMarkerIcon ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }
  
  Future<void> _initializeMap() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location services are disabled. Please enable to view the map.';
        });
        return;
      }
      
      // Check if we have location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location permission denied. Please allow location access to view the map.';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location permissions permanently denied. Please enable in settings.';
        });
        return;
      }
      
      // Get initial locations
      await _getCurrentUserLocation();
      await _getRecipientLocation();
      
      // If we have both locations, setup timers
      if (_currentUserLocation != null && _recipientLocation != null) {
        // Update our location every 5 seconds
        _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _updateCurrentUserLocation();
        });
        
        // Fetch recipient location every 3 seconds
        _locationFetchTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _getRecipientLocation();
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing map: $e';
      });
    }
  }
  
  Future<void> _getCurrentUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high
        )
      );
      
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Update markers and polylines
      _updateMapElements();
      
      // Save our location to the database
      await _saveCurrentUserLocation(position.latitude, position.longitude);
      
      // Center map on our position initially if recipient location is not available
      if (_recipientLocation == null) {
        if (_currentUserLocation != null) {
          _animateToPosition(_currentUserLocation!);
        }
      } else if (_currentUserLocation != null && _recipientLocation != null) {
        _centerMapOnBothUsers();
      }
    } catch (e) {
      debugPrint('Error getting current user location: $e');
    }
  }
  
  Future<void> _updateCurrentUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high
        )
      );
      
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Update markers and polylines
      _updateMapElements();
      
      // Save our location to the database
      await _saveCurrentUserLocation(position.latitude, position.longitude);
      
      // Recenter the map when locations update
      if (_currentUserLocation != null && _recipientLocation != null) {
        _centerMapOnBothUsers();
      }
    } catch (e) {
      debugPrint('Error updating current user location: $e');
    }
  }
  
  Future<void> _saveCurrentUserLocation(double latitude, double longitude) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'latitude': latitude,
        'longitude': longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', widget.currentUserId);
    } catch (e) {
      debugPrint('Error saving current user location: $e');
    }
  }
  
  Future<void> _getRecipientLocation() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('latitude, longitude, last_location_update')
          .eq('id', widget.recipientId)
          .single();
      
      if (response != null && 
          response['latitude'] != null && 
          response['longitude'] != null) {
        
        setState(() {
          _recipientLocation = LatLng(
            response['latitude'], 
            response['longitude']
          );
        });
        
        // Update markers and polylines
        _updateMapElements();
        
        // Center map on both users if we have both locations
        if (_currentUserLocation != null && _recipientLocation != null) {
          _centerMapOnBothUsers();
        }
      }
    } catch (e) {
      debugPrint('Error getting recipient location: $e');
    }
  }
  
  void _updateMapElements() {
    Set<Marker> markers = {};
    Set<Polyline> polylines = {};
    
    // Add current user marker
    if (_currentUserLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_user'),
          position: _currentUserLocation!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    
    // Add recipient marker
    if (_recipientLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('recipient'),
          position: _recipientLocation!,
          infoWindow: InfoWindow(title: widget.recipientUsername),
          icon: _recipientMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    
    // Add polyline between users
    if (_currentUserLocation != null && _recipientLocation != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_currentUserLocation!, _recipientLocation!],
          color: Colors.blue,
          width: 5,
        ),
      );
    }
    
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
      _polylines.clear();
      _polylines.addAll(polylines);
    });
  }
  
  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }
  
  void _centerMapOnBothUsers() async {
    if (_currentUserLocation == null || _recipientLocation == null) return;
    
    try {
      final GoogleMapController controller = await _controller.future;
      
      // Create bounds that include both positions
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentUserLocation!.latitude < _recipientLocation!.latitude
              ? _currentUserLocation!.latitude
              : _recipientLocation!.latitude,
          _currentUserLocation!.longitude < _recipientLocation!.longitude
              ? _currentUserLocation!.longitude
              : _recipientLocation!.longitude,
        ),
        northeast: LatLng(
          _currentUserLocation!.latitude > _recipientLocation!.latitude
              ? _currentUserLocation!.latitude
              : _recipientLocation!.latitude,
          _currentUserLocation!.longitude > _recipientLocation!.longitude
              ? _currentUserLocation!.longitude
              : _recipientLocation!.longitude,
        ),
      );
      
      // Add some padding
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
  }
  
  double _calculateDistance() {
    if (_currentUserLocation == null || _recipientLocation == null) return 0;
    
    // Calculate the distance between users using the Haversine formula
    return Geolocator.distanceBetween(
      _currentUserLocation!.latitude,
      _currentUserLocation!.longitude,
      _recipientLocation!.latitude,
      _recipientLocation!.longitude,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _initializeMap(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_currentUserLocation == null) {
      return const Center(
        child: Text('Waiting for your location...'),
      );
    }
    
    // Calculate the distance between users
    final double distanceInMeters = _calculateDistance();
    
    // Calculate estimated walking time (assuming 1.4 m/s walking speed)
    final double walkingTimeMinutes = distanceInMeters / (1.4 * 60);
    
    return Column(
      children: [
        // Map container with flexible height
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentUserLocation!,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              if (_currentUserLocation != null && _recipientLocation != null) {
                _centerMapOnBothUsers();
              }
            },
          ),
        ),
        
        // Distance and time information
        if (_recipientLocation != null) // Only show info if we have both locations
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Distance information
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      distanceInMeters >= 1000
                          ? '${(distanceInMeters / 1000).toStringAsFixed(2)} km away'
                          : '${distanceInMeters.toStringAsFixed(0)} meters away',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Estimated time
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      walkingTimeMinutes >= 60
                          ? '${(walkingTimeMinutes / 60).toStringAsFixed(1)} hours walking'
                          : '${walkingTimeMinutes.toStringAsFixed(0)} minutes walking',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Safety reminder
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Remember to meet in a public place and let someone know where you are going.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}