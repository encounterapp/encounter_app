import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class LocationTroubleshooter {
  // Check and report on all potential location issues
  static Future<Map<String, dynamic>> diagnoseLocationIssues() async {
    final results = <String, dynamic>{};
    
    // Check if location services are enabled on the device
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      results['location_service_enabled'] = serviceEnabled;
    } catch (e) {
      results['location_service_enabled'] = false;
      results['location_service_error'] = e.toString();
    }
    
    // Check location permission status
    try {
      final permission = await Geolocator.checkPermission();
      results['permission_status'] = permission.toString();
      results['permission_granted'] = 
          permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse;
    } catch (e) {
      results['permission_status'] = 'error';
      results['permission_error'] = e.toString();
    }
    
    // Check if user is logged in (needed for saving location)
    final userId = Supabase.instance.client.auth.currentUser?.id;
    results['user_logged_in'] = userId != null;
    
    // Check location preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      results['has_requested_location'] = prefs.getBool('has_requested_location') ?? false;
      results['location_enabled_pref'] = prefs.getBool('location_enabled') ?? true;
    } catch (e) {
      results['preferences_error'] = e.toString();
    }
    
    // Try to get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      results['position_acquired'] = true;
      results['latitude'] = position.latitude;
      results['longitude'] = position.longitude;
      results['position_accuracy'] = position.accuracy;
      results['position_timestamp'] = position.timestamp?.toIso8601String();
    } catch (e) {
      results['position_acquired'] = false;
      results['position_error'] = e.toString();
      
      // Check if the error is a timeout
      results['is_timeout_error'] = e is TimeoutException;
    }
    
    // Check if location data is in the Supabase profile
    if (userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('latitude, longitude, last_location_update')
            .eq('id', userId)
            .single();
        
        results['profile_has_location'] = 
            response != null && 
            response['latitude'] != null && 
            response['longitude'] != null;
            
        if (results['profile_has_location']) {
          results['profile_latitude'] = response['latitude'];
          results['profile_longitude'] = response['longitude'];
          results['last_location_update'] = response['last_location_update'];
        }
      } catch (e) {
        results['profile_query_error'] = e.toString();
      }
    }
    
    return results;
  }
  
  // Show a dialog with troubleshooting information
  static void showTroubleshootingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.bug_report, color: Colors.red),
              SizedBox(width: 10),
              Text('Location Troubleshooter'),
            ],
          ),
          content: FutureBuilder<Map<String, dynamic>>(
            future: diagnoseLocationIssues(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              
              final results = snapshot.data!;
              
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDiagnosticSection(
                      title: 'Device Settings',
                      items: [
                        _buildDiagnosticItem(
                          'Location Services', 
                          results['location_service_enabled'] ? 'Enabled' : 'Disabled',
                          results['location_service_enabled'],
                        ),
                        _buildDiagnosticItem(
                          'Permission Status', 
                          results['permission_status'],
                          results['permission_granted'],
                        ),
                      ],
                    ),
                    
                    _buildDiagnosticSection(
                      title: 'App Settings',
                      items: [
                        _buildDiagnosticItem(
                          'User Logged In', 
                          results['user_logged_in'] ? 'Yes' : 'No',
                          results['user_logged_in'],
                        ),
                        _buildDiagnosticItem(
                          'Has Requested Permission', 
                          results['has_requested_location'] ? 'Yes' : 'No',
                          true, // This is informational, not a pass/fail
                        ),
                        _buildDiagnosticItem(
                          'Location Enabled in Preferences', 
                          results['location_enabled_pref'] ? 'Yes' : 'No',
                          results['location_enabled_pref'],
                        ),
                      ],
                    ),
                    
                    _buildDiagnosticSection(
                      title: 'Location Data',
                      items: [
                        _buildDiagnosticItem(
                          'Current Position Acquired', 
                          results['position_acquired'] ? 'Yes' : 'No',
                          results['position_acquired'],
                        ),
                      ],
                    ),
                    
                    if (results['position_acquired'])
                      _buildDiagnosticSection(
                        title: 'Current Position Details',
                        items: [
                          _buildDiagnosticItem(
                            'Latitude', 
                            results['latitude'].toString(),
                            true,
                          ),
                          _buildDiagnosticItem(
                            'Longitude', 
                            results['longitude'].toString(),
                            true,
                          ),
                          _buildDiagnosticItem(
                            'Accuracy', 
                            '${results['position_accuracy']} meters',
                            true,
                          ),
                        ],
                      ),
                      
                    if (results['user_logged_in'] && results['profile_has_location'] == true)
                      _buildDiagnosticSection(
                        title: 'Profile Location Data',
                        items: [
                          _buildDiagnosticItem(
                            'Latitude', 
                            results['profile_latitude'].toString(),
                            true,
                          ),
                          _buildDiagnosticItem(
                            'Longitude', 
                            results['profile_longitude'].toString(),
                            true,
                          ),
                          _buildDiagnosticItem(
                            'Last Updated', 
                            results['last_location_update'].toString(),
                            true,
                          ),
                        ],
                      ),
                      
                    if (results['position_error'] != null)
                      _buildDiagnosticSection(
                        title: 'Error Information',
                        items: [
                          _buildDiagnosticItem(
                            'Position Error', 
                            results['position_error'].toString(),
                            false,
                          ),
                          if (results['is_timeout_error'] == true)
                            _buildDiagnosticItem(
                              'Error Type', 
                              'Timeout - Location taking too long to acquire',
                              false,
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _fixLocationIssues(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Fix Issues'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  // Attempt to fix location issues
  static Future<void> _fixLocationIssues(BuildContext context) async {
    final results = await diagnoseLocationIssues();
    
    // If location services are disabled
    if (results['location_service_enabled'] == false) {
      bool opened = await Geolocator.openLocationSettings();
      if (!opened) {
        _showFixFailedDialog(context, "Couldn't open location settings");
      }
      return; // Return to let the user enable location services first
    }
    
    // If permission is denied
    if (results['permission_granted'] == false) {
      // If denied forever, open app settings
      if (results['permission_status'] == LocationPermission.deniedForever.toString()) {
        bool opened = await Geolocator.openAppSettings();
        if (!opened) {
          _showFixFailedDialog(context, "Couldn't open app settings");
        }
        return; // Return to let the user change permissions first
      } else {
        // Try to request permission
        LocationPermission permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          _showFixFailedDialog(context, "Permission denied");
          return;
        }
      }
    }
    
    // If location is disabled in preferences
    if (results['location_enabled_pref'] == false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_enabled', true);
    }
    
    // Try to get and update location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'last_location_update': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        
        _showFixSuccessDialog(context);
      }
    } catch (e) {
      _showFixFailedDialog(context, e.toString());
    }
  }
  
  // Show a dialog when fixing issues fails
  static void _showFixFailedDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text('Error Fixing Issues'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('There was a problem fixing the location issues:'),
              const SizedBox(height: 10),
              Text(error, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Please try the following:'),
              const SizedBox(height: 8),
              const Text('• Make sure location is enabled in device settings'),
              const Text('• Grant the app location permission'),
              const Text('• Try restarting your device'),
              const Text('• Check if other apps can access your location'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  // Show a dialog when fixing issues succeeds
  static void _showFixSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Issues Fixed'),
            ],
          ),
          content: const Text(
            'Location issues have been fixed successfully. You should now be able to use location features in the app.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }
  
  // Helper method to build a diagnostic section
  static Widget _buildDiagnosticSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        ...items,
        const Divider(),
      ],
    );
  }
  
  // Helper method to build a diagnostic item
  static Widget _buildDiagnosticItem(
    String label, 
    String value, 
    bool isOk,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}