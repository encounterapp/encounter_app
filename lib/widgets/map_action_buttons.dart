import 'package:flutter/material.dart';

class MapActionButtons extends StatelessWidget {
  final VoidCallback onWeMetPressed;
  final VoidCallback onDidNotMeetPressed;
  
  const MapActionButtons({
    Key? key,
    required this.onWeMetPressed,
    required this.onDidNotMeetPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onWeMetPressed,
              icon: const Icon(Icons.check_circle),
              label: const Text("We Met"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDidNotMeetPressed,
              icon: const Icon(Icons.cancel),
              label: const Text("We Did Not Meet"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}