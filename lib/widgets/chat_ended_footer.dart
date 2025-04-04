import 'package:flutter/material.dart';

class ChatEndedFooter extends StatelessWidget {
  final VoidCallback onReturn;
  
  const ChatEndedFooter({
    Key? key,
    required this.onReturn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: ElevatedButton(
        onPressed: onReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          "Return to Home",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}