import 'package:flutter/material.dart';
import 'package:encounter_app/components/google_meeting_map_view.dart';

class MeetingMapView extends StatelessWidget {
  final String currentUserId;
  final String recipientId;
  final String recipientUsername;

  const MeetingMapView({
    Key? key,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientUsername,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMeetingMapView(
      currentUserId: currentUserId,
      recipientId: recipientId,
      recipientUsername: recipientUsername,
    );
  }
}