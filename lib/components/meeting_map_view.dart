import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeetingMapView extends StatefulWidget {
  final String currentUserId;
  final String recipientId;
  final String recipientUsername;

  const MeetingMapView({
    Key? key,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientUsername,
  }) : super(key: key);

  @override
  State<MeetingMapView> createState() => _MeetingMapViewState();
}

class _MeetingMapViewState extends State<MeetingMapView> {
  // Map controller
  final MapController _mapController = MapController();
  
  // Locations
  LatLng? _currentUserLocation;
  LatLng? _recipientLocation;
  
  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;
  
  // Timers for location updates
  Timer? _locationUpdateTimer;
  Timer? _locationFetchTimer;
  
  // Animation values for "moving" effect
  double _animationProgress = 0.0;
  Timer? _animationTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeMap();
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _locationFetchTimer?.cancel();
    _animationTimer?.cancel();
    super.dispose();
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
        
        // Animation timer for "moving" effect
        _animationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          setState(() {
            _animationProgress += 0.02;
            if (_animationProgress > 1.0) {
              _animationProgress = 0.0;
            }
          });
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
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Save our location to the database
      await _saveCurrentUserLocation(position.latitude, position.longitude);
      
      // Center map on our position initially if recipient location is not available
      if (_recipientLocation == null && _mapController.ready) {
        _mapController.move(_currentUserLocation!, 15.0);
      } else if (_currentUserLocation != null && _recipientLocation != null && _mapController.ready) {
        _centerMapOnBothUsers();
      }
    } catch (e) {
      debugPrint('Error getting current user location: $e');
    }
  }
  
  Future<void> _updateCurrentUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Save our location to the database
      await _saveCurrentUserLocation(position.latitude, position.longitude);
      
      // Recenter the map when locations update
      if (_currentUserLocation != null && _recipientLocation != null && _mapController.ready) {
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
        
        // Center map on both users if we have both locations
        if (_currentUserLocation != null && _recipientLocation != null && _mapController.ready) {
          _centerMapOnBothUsers();
        }
      }
    } catch (e) {
      debugPrint('Error getting recipient location: $e');
    }
  }
  
  void _centerMapOnBothUsers() {
    if (_currentUserLocation == null || _recipientLocation == null) return;
    
    try {
      // Calculate the bounds to include both positions with some padding
      final bounds = LatLngBounds.fromPoints([
        _currentUserLocation!,
        _recipientLocation!,
      ]);
      
      // Center the map on the bounds with some padding
      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(
          padding: EdgeInsets.all(50.0),
        ),
      );
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
  }
  
  LatLng _getAnimatedPosition(LatLng start, LatLng end, double progress) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * progress,
      start.longitude + (end.longitude - start.longitude) * progress,
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
    
    if (_currentUserLocation == null || _recipientLocation == null) {
      return const Center(
        child: Text('Waiting for location data...'),
      );
    }
    
    // Calculate the distance between users
    final Distance distance = Distance();
    final double distanceInMeters = distance.distance(
      _currentUserLocation!,
      _recipientLocation!,
    );
    
    // Calculate estimated walking time (assuming 1.4 m/s walking speed)
    final double walkingTimeMinutes = distanceInMeters / (1.4 * 60);
    
    return Column(
      children: [
        // Map container with fixed height
        Container(
          height: 300,
          width: double.infinity,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentUserLocation!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.encounter_app',
              ),
              MarkerLayer(
                markers: [
                  // User marker
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: _currentUserLocation!,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const Text(
                          'You',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Recipient marker
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: _recipientLocation!,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Text(
                          widget.recipientUsername,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Animated dots showing movement between users
                  ...List.generate(5, (index) {
                    // Calculate a different progress for each dot
                    double dotProgress = (_animationProgress + index * 0.2) % 1.0;
                    
                    // Get the position for this dot
                    LatLng dotPosition = _getAnimatedPosition(
                      _currentUserLocation!,
                      _recipientLocation!,
                      dotProgress,
                    );
                    
                    // Make dots more visible when they're at their progress point
                    double opacity = 1.0 - (2 * (dotProgress - 0.5).abs());
                    
                    return Marker(
                      width: 10.0,
                      height: 10.0,
                      point: dotPosition,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_currentUserLocation!, _recipientLocation!],
                    color: Colors.blue,
                    strokeWidth: 3.0,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Distance and time information
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
                  border: Border.all(color: Colors.orange),
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