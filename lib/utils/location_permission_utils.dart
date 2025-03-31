import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationPermissionUtils {
  static const String _hasRequestedLocationKey = 'has_requested_location';

  /// Checks if location permissions should be requested
  /// Returns true if this is the first time after registration
  static Future<bool> shouldRequestLocationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequestedLocation = prefs.getBool(_hasRequestedLocationKey) ?? false;
    
    // If we've already requested permission, don't ask again
    if (hasRequestedLocation) {
      return false;
    }
    
    return true;
  }

  /// Marks that we've requested location permission
  static Future<void> markLocationPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRequestedLocationKey, true);
  }

  /// Requests location permission with a user-friendly dialog
  static Future<bool> requestLocationPermission(BuildContext context) async {
    bool permissionGranted = false;

    // Show explanation dialog first
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encounter needs access to your location to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_alt, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Show you nearby users to connect with'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_activity, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Find relevant posts and events in your area'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Your exact location is never shared with other users without your consent'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Not Now'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Allow'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ).then((value) async {
      // If user pressed Allow
      if (value == true) {
        // Request actual permission from the system
        LocationPermission permission = await Geolocator.requestPermission();
        permissionGranted = (permission == LocationPermission.always || 
                            permission == LocationPermission.whileInUse);
        
        // If permission granted, save location to profile
        if (permissionGranted) {
          try {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium
            );
            
            // Save to user profile in Supabase
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (userId != null) {
              await Supabase.instance.client.from('profiles').update({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'last_location_update': DateTime.now().toIso8601String(),
              }).eq('id', userId);
            }
          } catch (e) {
            debugPrint('Error getting or saving location: $e');
          }
        }
      }
    });

    // Mark that we've requested permission (regardless of the result)
    await markLocationPermissionRequested();
    
    return permissionGranted;
  }

  /// Checks current permission status
  static Future<bool> checkPermissionStatus() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }
}