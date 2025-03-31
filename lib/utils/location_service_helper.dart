import 'package:flutter/material.dart';
import 'package:encounter_app/utils/enhanced_location_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encounter_app/utils/location_troubleshooter.dart';
import 'dart:async';

/// A service class that handles all location-related functionality
/// This class serves as the main point of interaction for location services
/// throughout the app, providing a clean interface for the rest of the code.
class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;
  
  // Private constructor
  LocationService._internal();
  
  // Location state
  bool _isLocationAvailable = false;
  bool _isCheckingLocation = false;
  Position? _lastKnownPosition;
  
  // Stream controllers for location state
  final _locationStateStreamController = StreamController<LocationState>.broadcast();
  
  // Getters
  Stream<LocationState> get locationStateStream => _locationStateStreamController.stream;
  bool get isLocationAvailable => _isLocationAvailable;
  bool get isCheckingLocation => _isCheckingLocation;
  Position? get lastKnownPosition => _lastKnownPosition;
  
  // Initialize the service
  Future<void> initialize() async {
    _setCheckingState(true);
    
    try {
      // Check if location is available
      final isAvailable = await EnhancedLocationUtils.isLocationAvailable();
      _isLocationAvailable = isAvailable;
      
      // If location is available, get the current position
      if (isAvailable) {
        _lastKnownPosition = await EnhancedLocationUtils.getCurrentPosition();
        
        // Update the user location in the database
        await updateUserLocation();
      }
      
      // Emit the current state
      _emitCurrentState();
    } catch (e) {
      debugPrint('Error initializing location service: $e');
    } finally {
      _setCheckingState(false);
    }
  }
  
  // Request location permission with UI feedback
  Future<bool> requestLocationPermission(BuildContext context) async {
    _setCheckingState(true);
    
    try {
      // Check if location services are enabled
      final serviceEnabled = await EnhancedLocationUtils.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          await EnhancedLocationUtils.handleLocationServicesDisabled(context);
        }
        _setCheckingState(false);
        return false;
      }
      
      // Request permission
      final permissionGranted = await EnhancedLocationUtils.requestLocationPermission(context);
      _isLocationAvailable = permissionGranted;
      
      // If permission was granted, get the current position
      if (permissionGranted) {
        _lastKnownPosition = await EnhancedLocationUtils.getCurrentPosition();
        
        // Update the user location in the database
        await updateUserLocation();
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location access granted successfully!')),
          );
        }
      }
      
      // Emit the current state
      _emitCurrentState();
      
      return permissionGranted;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    } finally {
      _setCheckingState(false);
    }
  }
  
  // Update user location in the database
  Future<bool> updateUserLocation() async {
    try {
      if (!_isLocationAvailable) {
        return false;
      }
      
      // If we don't have a position, get one
      if (_lastKnownPosition == null) {
        _lastKnownPosition = await EnhancedLocationUtils.getCurrentPosition();
        if (_lastKnownPosition == null) {
          return false;
        }
      }
      
      // Update the user location in the database
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }
      
      await Supabase.instance.client.from('profiles').update({
        'latitude': _lastKnownPosition!.latitude,
        'longitude': _lastKnownPosition!.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      return true;
    } catch (e) {
      debugPrint('Error updating user location: $e');
      return false;
    }
  }
  
  // Refresh the location state
  Future<void> refreshLocationState() async {
    _setCheckingState(true);
    
    try {
      // Check if location is available
      final isAvailable = await EnhancedLocationUtils.isLocationAvailable();
      _isLocationAvailable = isAvailable;
      
      // If location is available, get the current position
      if (isAvailable) {
        _lastKnownPosition = await EnhancedLocationUtils.getCurrentPosition();
        
        // Update the user location in the database
        await updateUserLocation();
      }
      
      // Emit the current state
      _emitCurrentState();
    } catch (e) {
      debugPrint('Error refreshing location state: $e');
    } finally {
      _setCheckingState(false);
    }
  }
  
  // Toggle location services
  Future<void> toggleLocationServices(bool enabled) async {
    try {
      // Set the location enabled preference
      await EnhancedLocationUtils.setLocationEnabled(enabled);
      
      // Refresh the location state
      await refreshLocationState();
    } catch (e) {
      debugPrint('Error toggling location services: $e');
    }
  }
  
  // Calculate distance between current location and a given point
  Future<double?> calculateDistanceToPoint(double latitude, double longitude) async {
    try {
      if (!_isLocationAvailable) {
        return null;
      }
      
      // If we don't have a position, get one
      if (_lastKnownPosition == null) {
        _lastKnownPosition = await EnhancedLocationUtils.getCurrentPosition();
        if (_lastKnownPosition == null) {
          return null;
        }
      }
      
      // Calculate the distance
      return Geolocator.distanceBetween(
        _lastKnownPosition!.latitude,
        _lastKnownPosition!.longitude,
        latitude,
        longitude,
      ) / 1000; // Convert to kilometers
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      return null;
    }
  }
  
  // Show the troubleshooter dialog
  void showTroubleshooter(BuildContext context) {
    LocationTroubleshooter.showTroubleshootingDialog(context);
  }
  
  // Helper method to set the checking state
  void _setCheckingState(bool checking) {
    _isCheckingLocation = checking;
    _emitCurrentState();
  }
  
  // Helper method to emit the current state
  void _emitCurrentState() {
    _locationStateStreamController.add(
      LocationState(
        isAvailable: _isLocationAvailable,
        isChecking: _isCheckingLocation,
        position: _lastKnownPosition,
      ),
    );
  }
  
  // Dispose the service
  void dispose() {
    _locationStateStreamController.close();
  }
}

/// A class that represents the current state of the location service
class LocationState {
  final bool isAvailable;
  final bool isChecking;
  final Position? position;
  
  LocationState({
    required this.isAvailable,
    required this.isChecking,
    this.position,
  });
}

// For easy access
final locationService = LocationService.instance;