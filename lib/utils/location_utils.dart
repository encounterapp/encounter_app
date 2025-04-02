import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationUtils {
  /// Checks if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  /// Checks current location permission status
  static Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  /// Requests location permission
  static Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  /// Gets current location
  static Future<Position?> getCurrentPosition() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Then check if we have permission
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          return null;
        }
      }

      // Get the current position with appropriate settings
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5)
        )
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Updates user location in database
  static Future<bool> updateUserLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return false;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      // Update the profile with the current location
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
}