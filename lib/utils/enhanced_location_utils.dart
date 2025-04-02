import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedLocationUtils {
  // Cache the last known position
  static Position? _lastPosition;
  
  // Keys for shared preferences
  static const String _hasRequestedLocationKey = 'has_requested_location';
  static const String _locationEnabledKey = 'location_enabled';

  /// Checks if the device has location services enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  /// Checks if the app has location permission
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

  /// Comprehensive check for location availability
  static Future<bool> isLocationAvailable() async {
    // First check if location services are enabled on the device
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled on device');
      return false;
    }
    
    // Then check if we have permission
    final hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      debugPrint('App does not have location permission');
      return false;
    }
    
    // Check the user preference (they might have manually disabled it in the app)
    final prefs = await SharedPreferences.getInstance();
    final userEnabled = prefs.getBool(_locationEnabledKey) ?? true; // Default to true
    
    if (!userEnabled) {
      debugPrint('User has disabled location in app preferences');
    }
    
    return userEnabled;
  }

  /// Opens device location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }

  /// Opens app settings
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Handles the error case when location permission is denied forever
  static Future<void> handlePermissionDeniedForever(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission is required to show nearby posts. '
            'Please open settings and enable location permission for this app.'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Handles the error case when location services are disabled
  static Future<void> handleLocationServicesDisabled(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are disabled on your device. '
            'Please enable location services to see nearby posts.'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Requests location permission with proper error handling
  static Future<bool> requestLocationPermission(BuildContext context) async {
    // First check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      await handleLocationServicesDisabled(context);
      return false;
    }

    // Check the current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    // If denied, request permission
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      
      // Still denied after request
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return false;
      }
    }
    
    // Handle the case when permission is denied forever
    if (permission == LocationPermission.deniedForever) {
      await handlePermissionDeniedForever(context);
      return false;
    }

    // Mark that we've requested permission
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRequestedLocationKey, true);
    await prefs.setBool(_locationEnabledKey, true);
    
    return true;
  }

  /// Gets the current position with error handling
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // If we have a cached position, return it
      if (_lastPosition != null) {
        return _lastPosition;
      }
      
      // Check if location is available
      final isAvailable = await isLocationAvailable();
      if (!isAvailable) {
        return null;
      }
      
      // Get the current position with updated settings
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        )
      );
      
      // Cache the position
      _lastPosition = position;
      
      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Updates the user's location in the database
  static Future<bool> updateUserLocation() async {
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

  /// Enable or disable location in app preferences
  static Future<void> setLocationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationEnabledKey, enabled);
    
    // Clear the cached position when disabling
    if (!enabled) {
      _lastPosition = null;
    }
  }

  /// Check if this is the first time requesting location
  static Future<bool> shouldRequestLocationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_hasRequestedLocationKey) ?? false);
  }

  /// Marks that we've requested location permission
static Future<void> markLocationPermissionRequested() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hasRequestedLocationKey, true);
}

}