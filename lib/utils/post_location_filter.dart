import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/location_manager.dart';
import 'package:geolocator/geolocator.dart';

/// Enhanced result from the filtering operation
class FilterResult {
  final List<Map<String, dynamic>> posts;
  final bool locationServicesAvailable;

  FilterResult({
    required this.posts,
    required this.locationServicesAvailable,
  });
}

/// A utility class to filter posts based on location, gender, and age
class PostLocationFilter {
  static final LocationManager _locationManager = LocationManager();
  static final SupabaseClient _supabase = Supabase.instance.client;
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
  
  /// Filters posts by distance, gender, and age
  static Future<FilterResult> filterPosts(
    List<Map<String, dynamic>> posts, {
    double maxDistance = _DEFAULT_MAX_DISTANCE,
    String genderFilter = "Everyone",
    required RangeValues ageRange,
    bool locationFilterEnabled = true,
  }) async {
    List<Map<String, dynamic>> filteredPosts = List.from(posts);
    bool locationAvailable = true;
    
    // Apply location filtering if enabled
    if (locationFilterEnabled) {
      // Check if location services are available
      locationAvailable = await isLocationAvailable();
      if (!locationAvailable) {
        return FilterResult(
          posts: [],
          locationServicesAvailable: false,
        );
      }
      
      // Initialize location manager
      final bool initialized = await _locationManager.initialize();
      if (!initialized) {
        return FilterResult(
          posts: [],
          locationServicesAvailable: false,
        );
      }
      
      // Get current user location
      final currentPosition = await _locationManager.getCurrentPosition();
      
      // If location is not available, return empty list
      if (currentPosition == null) {
        return FilterResult(
          posts: [],
          locationServicesAvailable: false,
        );
      }
      
      final locationFilteredPosts = <Map<String, dynamic>>[];
      final currentUserId = _supabase.auth.currentUser?.id;
      
      // For each post, get the author's location and check the distance
      for (final post in filteredPosts) {
        final authorId = post['user_id'];
        
        // Always include the current user's own posts
        if (authorId == currentUserId) {
          locationFilteredPosts.add(post);
          continue;
        }
        
        try {
          // Get author's profile with location data
          final authorProfile = await _supabase
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
            locationFilteredPosts.add(postWithDistance);
          }
        } catch (e) {
          debugPrint('Error filtering post by location: $e');
          // Skip this post on error
        }
      }
      
      filteredPosts = locationFilteredPosts;
    }
    
    // Apply gender filter if not "Everyone"
    if (genderFilter != "Everyone") {
      final genderFilteredPosts = <Map<String, dynamic>>[];
      final currentUserId = _supabase.auth.currentUser?.id;
      
      for (final post in filteredPosts) {
        final authorId = post['user_id'];
        
        // Always include current user's own posts
        if (authorId == currentUserId) {
          genderFilteredPosts.add(post);
          continue;
        }
        
        try {
          // Get author's profile with gender data
          final authorProfile = await _supabase
              .from('profiles')
              .select('gender')
              .eq('id', authorId)
              .maybeSingle();
          
          // If the author doesn't have a gender specified and we're filtering by gender, skip the post
          if (authorProfile == null || authorProfile['gender'] == null) {
            continue;
          }
          
          // If gender matches filter or the filter is "Everyone", include the post
          if (authorProfile['gender'] == genderFilter) {
            genderFilteredPosts.add(post);
          }
        } catch (e) {
          debugPrint('Error filtering post by gender: $e');
          // Skip this post on error
        }
      }
      
      filteredPosts = genderFilteredPosts;
    }
    
    // Apply age filter (could be implemented similarly to gender filter)
    if (ageRange.start > 18 || ageRange.end < 60) {
      final ageFilteredPosts = <Map<String, dynamic>>[];
      final currentUserId = _supabase.auth.currentUser?.id;
      
      for (final post in filteredPosts) {
        final authorId = post['user_id'];
        
        // Always include current user's own posts
        if (authorId == currentUserId) {
          ageFilteredPosts.add(post);
          continue;
        }
        
        try {
          // Get author's profile with age data
          final authorProfile = await _supabase
              .from('profiles')
              .select('age')
              .eq('id', authorId)
              .maybeSingle();
          
          // If the author doesn't have an age specified, skip the post
          if (authorProfile == null || authorProfile['age'] == null) {
            continue;
          }
          
          // Include the post if the age is within the specified range
          final int age = authorProfile['age'];
          if (age >= ageRange.start && age <= ageRange.end) {
            ageFilteredPosts.add(post);
          }
        } catch (e) {
          debugPrint('Error filtering post by age: $e');
          // Skip this post on error
        }
      }
      
      filteredPosts = ageFilteredPosts;
    }
    
    return FilterResult(
      posts: filteredPosts,
      locationServicesAvailable: locationAvailable,
    );
  }
}