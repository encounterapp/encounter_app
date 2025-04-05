import 'package:flutter/material.dart';
import 'package:encounter_app/components/meeting_map_view.dart';

/// A simple widget that wraps the MeetingMapView and adds any additional
/// functionality needed for the meeting map. This is a separate widget to
/// make it easier to reuse the map view in other contexts.
class MeetingMap extends StatelessWidget {
  final String currentUserId;
  final String recipientId;
  final String recipientUsername;
  
  const MeetingMap({
    Key? key,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientUsername,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: MeetingMapView(
        currentUserId: currentUserId,
        recipientId: recipientId,
        recipientUsername: recipientUsername,
      ),
    );
  }
}