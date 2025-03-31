import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();
  factory LocationManager() => _instance;
  
  LocationManager._internal();
  
  // Last known position
  Position? _lastKnownPosition;
  
  // Getters
  Position? get lastKnownPosition => _lastKnownPosition;
  double? get latitude => _lastKnownPosition?.latitude;
  double? get longitude => _lastKnownPosition?.longitude;
  
  // Initialize location services
  Future<bool> initialize() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check and request permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    // Get initial position
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );
      return true;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return false;
    }
  }
  
  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );
      return _lastKnownPosition;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }
  
  // Update user's location in the database
  Future<bool> updateUserLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return false;
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      
      await Supabase.instance.client.from('profiles').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      return true;
    } catch (e) {
      debugPrint('Error updating user location: $e');
      return false;
    }
  }
  
  // Calculate distance between two coordinates in kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
  
  // Get distance from current position to another location in kilometers
  Future<double?> getDistanceTo(double lat, double lon) async {
    try {
      final currentPosition = await getCurrentPosition();
      if (currentPosition == null) return null;
      
      return calculateDistance(
        currentPosition.latitude, 
        currentPosition.longitude,
        lat, 
        lon
      );
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      return null;
    }
  }
}