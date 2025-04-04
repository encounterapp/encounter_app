import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMine;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMine,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if this message might contain age-related content to highlight
    final bool containsAgeWarning = message.toLowerCase().contains('under 18') ||
                                  message.toLowerCase().contains('minor') ||
                                  message.toLowerCase().contains('adult');
                                  
    // Determine bubble color based on whether it's the user's message and if it contains warnings
    Color bubbleColor;
    if (isMine) {
      bubbleColor = containsAgeWarning ? Colors.orange : Colors.blue;
    } else {
      bubbleColor = containsAgeWarning ? Colors.orange[100]! : Colors.grey[300]!;
    }
    
    // Text color based on bubble color
    Color textColor = isMine ? Colors.white : Colors.black;
    
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMine ? 12 : 0),
            topRight: Radius.circular(isMine ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          // Add border for age-related messages
          border: containsAgeWarning 
              ? Border.all(color: Colors.orange[700]!, width: 1.0) 
              : null,
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 16, 
            color: textColor,
            // Make age-related text bold
            fontWeight: containsAgeWarning ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}