import 'package:flutter/material.dart';

class ActionButtonsPane extends StatelessWidget {
  final VoidCallback onEndChat;
  final VoidCallback? onMeet;
  final bool disabled;
  final bool ageGapWarningNeeded;
  final bool isCurrentUserMinor;
  
  const ActionButtonsPane({
    Key? key,
    required this.onEndChat,
    this.onMeet,
    required this.disabled,
    this.ageGapWarningNeeded = false,
    this.isCurrentUserMinor = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safety guidelines
    final List<String> safetyGuidelines = [
      '• Meet in public places only',
      '• Tell a friend or family member about your plans',
      '• No solicitation of any kind',
      '• No harassment or inappropriate content',
      '• Report violations immediately',
    ];
    
    // Add age-specific guidelines
    if (ageGapWarningNeeded) {
      if (isCurrentUserMinor) {
        safetyGuidelines.add('• Consider involving a trusted adult in communications');
        safetyGuidelines.add('• Never share personal information or photos');
      } else {
        safetyGuidelines.add('• Communication must be appropriate for minors');
        safetyGuidelines.add('• Inappropriate communications with minors may violate laws');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : onMeet,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Meet"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // Apply disabled styling
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : onEndChat,
                  icon: const Icon(Icons.close),
                  label: const Text("Decline"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // Apply disabled styling
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          // Guidelines collapsed section
          ExpansionTile(
            title: const Text(
              "Safety Guidelines",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            initiallyExpanded: false,
            iconColor: Colors.orange,
            children: [
              // Display all safety guidelines including age-specific ones
              ...safetyGuidelines.map((guideline) => _buildGuidelineText(guideline)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGuidelineText(String text) {
    // Highlight age-related guidelines with a different color
    final bool isAgeGuideline = text.contains('minor') || 
                               text.contains('adult') || 
                               text.contains('trusted');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14, 
          color: isAgeGuideline ? Colors.orange[800] : Colors.grey[600],
          fontWeight: isAgeGuideline ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}