import 'package:flutter/material.dart';
import 'package:encounter_app/utils/location_service_helper.dart';

class LocationStatusWidget extends StatefulWidget {
  final bool showLabel;
  final bool showIcon;
  final VoidCallback? onTap;
  final double iconSize;
  
  const LocationStatusWidget({
    super.key,
    this.showLabel = true,
    this.showIcon = true,
    this.onTap,
    this.iconSize = 24.0,
  });

  @override
  State<LocationStatusWidget> createState() => _LocationStatusWidgetState();
}

class _LocationStatusWidgetState extends State<LocationStatusWidget> {
  @override
  void initState() {
    super.initState();
    // Initialize location service if not already initialized
    if (!locationService.isCheckingLocation && !locationService.isLocationAvailable) {
      locationService.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocationState>(
      stream: locationService.locationStateStream,
      initialData: LocationState(
        isAvailable: locationService.isLocationAvailable,
        isChecking: locationService.isCheckingLocation,
        position: locationService.lastKnownPosition,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        
        return InkWell(
          onTap: widget.onTap ?? () => _handleTap(context),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showIcon)
                  state.isChecking
                      ? SizedBox(
                          width: widget.iconSize,
                          height: widget.iconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      : Icon(
                          state.isAvailable ? Icons.location_on : Icons.location_off,
                          color: state.isAvailable ? Colors.green : Colors.red,
                          size: widget.iconSize,
                        ),
                if (widget.showLabel && widget.showIcon)
                  const SizedBox(width: 8),
                if (widget.showLabel)
                  Text(
                    state.isChecking
                        ? 'Checking location...'
                        : state.isAvailable
                            ? 'Location enabled'
                            : 'Location disabled',
                    style: TextStyle(
                      color: state.isChecking
                          ? Theme.of(context).primaryColor
                          : state.isAvailable
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context) {
    final isAvailable = locationService.isLocationAvailable;
    final isChecking = locationService.isCheckingLocation;
    
    if (isChecking) {
      // Do nothing if we're already checking
      return;
    }
    
    if (isAvailable) {
      // Show dialog to disable location
      _showDisableLocationDialog(context);
    } else {
      // Request location permission
      locationService.requestLocationPermission(context);
    }
  }

  void _showDisableLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disable Location?'),
          content: const Text(
            'If you disable location, you won\'t be able to see posts from nearby users '
            'or use other location-based features. Are you sure you want to disable location?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                locationService.toggleLocationServices(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );
  }
}

class LocationStatusIndicator extends StatelessWidget {
  const LocationStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocationState>(
      stream: locationService.locationStateStream,
      initialData: LocationState(
        isAvailable: locationService.isLocationAvailable,
        isChecking: locationService.isCheckingLocation,
        position: locationService.lastKnownPosition,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        
        if (state.isChecking) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state.isAvailable ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}