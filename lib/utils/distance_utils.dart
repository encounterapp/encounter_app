import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class DistanceUtils {
  /// Calculate distance between two coordinates using Geolocator
  static double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    try {
      // Use Geolocator to calculate distance in meters
      final distanceInMeters = Geolocator.distanceBetween(
        lat1, lon1, lat2, lon2
      );
      
      // Convert to miles (1 meter = 0.000621371 miles)
      return distanceInMeters * 0.000621371;
    } catch (e) {
      // Fallback to Haversine formula if Geolocator fails
      return _calculateHaversineDistance(lat1, lon1, lat2, lon2);
    }
  }
  
  /// Calculate distance using Haversine formula (fallback method)
  static double _calculateHaversineDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    const double earthRadius = 6371; // Radius of the earth in km
    
    double toRadians(double degree) {
      return degree * (math.pi / 180);
    }
    
    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);
    
    final a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(lat1)) * math.cos(toRadians(lat2)) * 
      math.sin(dLon / 2) * math.sin(dLon / 2);
      
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceKm = earthRadius * c;
    
    return distanceKm * 0.621371; // Convert km to miles
  }
}