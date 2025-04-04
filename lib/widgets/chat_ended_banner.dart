import 'package:flutter/material.dart';

class ChatEndedBanner extends StatelessWidget {
  final String message;
  
  const ChatEndedBanner({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if this is an age-related message
    final bool isAgeMessage = message.contains('under 18') || 
                              message.contains('minor') || 
                              message.contains('age verification');
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAgeMessage ? Colors.orange[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: isAgeMessage ? Border.all(color: Colors.orange) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAgeMessage)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(Icons.warning_amber, size: 16, color: Colors.orange[800]),
              ),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: isAgeMessage ? Colors.orange[800] : Colors.grey[800], 
                  fontSize: 14, 
                  fontStyle: FontStyle.italic,
                  fontWeight: isAgeMessage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}