import 'package:flutter/material.dart';
import 'package:encounter_app/utils/enhanced_location_utils.dart';

class LocationPermissionDialog extends StatelessWidget {
  final Function(bool) onPermissionResult;

  const LocationPermissionDialog({
    super.key,
    required this.onPermissionResult,
  });

  Future<void> _handlePermissionRequest(BuildContext context) async {
    final permissionGranted = await EnhancedLocationUtils.requestLocationPermission(context);
    onPermissionResult(permissionGranted);
    
    if (permissionGranted) {
      // Update the user's location in the database if permission was granted
      await EnhancedLocationUtils.updateUserLocation();
      
      // Navigate back
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue[700]),
          const SizedBox(width: 10),
          const Text('Location Access'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encounter needs access to your location to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildFeatureItem(
              context,
              icon: Icons.people,
              text: 'Show you nearby users to connect with',
            ),
            
            _buildFeatureItem(
              context,
              icon: Icons.post_add,
              text: 'Display relevant posts from people in your area',
            ),
            
            _buildFeatureItem(
              context, 
              icon: Icons.event,
              text: 'Find local events and activities'
            ),
            
            const SizedBox(height: 10),
            
            _buildPrivacyNotice(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onPermissionResult(false);
            Navigator.of(context).pop();
          },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () => _handlePermissionRequest(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Allow'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your exact location is never shared with other users without your explicit consent.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}