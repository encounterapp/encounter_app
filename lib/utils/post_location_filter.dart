import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/location_manager.dart';
import 'package:geolocator/geolocator.dart';

/// Result from the location filtering operation
class LocationFilterResult {
  final List<Map<String, dynamic>> posts;
  final bool locationServicesAvailable;

  LocationFilterResult({
    required this.posts,
    required this.locationServicesAvailable,
  });
}

/// A utility class to filter posts based on user's location
class PostLocationFilter {
  static final LocationManager _locationManager = LocationManager();
  static const double _DEFAULT_MAX_DISTANCE = 5.0; // Default 5 miles
  
  /// Checks if location services are available
  static Future<bool> isLocationAvailable() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      return false;
    }
    
    try {
      // Try to get current position as final check
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3)
        )
      );
      return position != null;
    } catch (e) {
      debugPrint('Error checking location availability: $e');
      return false;
    }
  }
  
  /// Filters a list of posts by distance from the current user
  /// Returns posts from users within the specified maxDistance (in miles)
  /// Also indicates if location services are available
  static Future<LocationFilterResult> filterPostsByDistance(
    List<Map<String, dynamic>> posts, 
    {double maxDistance = _DEFAULT_MAX_DISTANCE}
  ) async {
    // Check if location services are available
    final bool locationAvailable = await isLocationAvailable();
    if (!locationAvailable) {
      // Return empty posts list with locationServicesAvailable = false
      return LocationFilterResult(
        posts: [],
        locationServicesAvailable: false,
      );
    }
    
    // Initialize location manager
    final bool initialized = await _locationManager.initialize();
    if (!initialized) {
      return LocationFilterResult(
        posts: [],
        locationServicesAvailable: false,
      );
    }
    
    // Get current user location
    final currentPosition = await _locationManager.getCurrentPosition();
    
    // If location is not available, return empty list
    if (currentPosition == null) {
      return LocationFilterResult(
        posts: [],
        locationServicesAvailable: false,
      );
    }
    
    final filteredPosts = <Map<String, dynamic>>[];
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    
    // For each post, get the author's location and check the distance
    for (final post in posts) {
      final authorId = post['user_id'];
      
      // Always include the current user's own posts
      if (authorId == currentUserId) {
        filteredPosts.add(post);
        continue;
      }
      
      try {
        // Get author's profile with location data
        final authorProfile = await supabase
            .from('profiles')
            .select('latitude, longitude')
            .eq('id', authorId)
            .maybeSingle();
        
        // If author has no location data, skip this post
        if (authorProfile == null || 
            authorProfile['latitude'] == null || 
            authorProfile['longitude'] == null) {
          continue;
        }
        
        // Calculate distance between current user and post author
        final double authorLat = authorProfile['latitude'];
        final double authorLng = authorProfile['longitude'];
        
        final double distance = _locationManager.calculateDistance(
          currentPosition.latitude, 
          currentPosition.longitude,
          authorLat, 
          authorLng
        );
        
        // Convert to miles (the calculateDistance method returns kilometers)
        final distanceInMiles = distance * 0.621371;
        
        // Add distance info to the post for potential UI display
        final postWithDistance = Map<String, dynamic>.from(post);
        postWithDistance['distance_miles'] = distanceInMiles;
        
        // Include the post if it's within the specified distance
        if (distanceInMiles <= maxDistance) {
          filteredPosts.add(postWithDistance);
        }
      } catch (e) {
        debugPrint('Error filtering post by location: $e');
        // Skip this post on error
      }
    }
    
    return LocationFilterResult(
      posts: filteredPosts,
      locationServicesAvailable: true,
    );
  }
}