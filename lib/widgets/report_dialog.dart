import 'package:flutter/material.dart';

class ReportDialog extends StatefulWidget {
  final String recipientId;
  final String? recipientUsername;
  final Function(String reason, String details) onSubmit;

  const ReportDialog({
    Key? key,
    required this.recipientId,
    this.recipientUsername,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _selectedReason = 'inappropriate_content';
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, String> _reportReasons = {
    'inappropriate_content': 'Inappropriate Content',
    'harassment': 'Harassment or Bullying',
    'spam': 'Spam or Advertising',
    'underage_user': 'User appears to be underage',
    'impersonation': 'Impersonation',
    'other': 'Other',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_problem, color: Colors.red),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Report ${widget.recipientUsername ?? 'User'}',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please select a reason for your report:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // Reason selection dropdown
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _reportReasons.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedReason = value;
                  });
                }
              },
            ),
            
            SizedBox(height: 16),
            
            // Additional details text field
            Text(
              'Additional details (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Please provide any specific details about this report...',
                border: OutlineInputBorder(),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Reporting policy information
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our reporting policy:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Reports are confidential\n'
                    '• We review all reports within 24 hours\n'
                    '• False reports may result in account restrictions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting 
            ? null 
            : () => Navigator.of(context).pop(),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting 
            ? null 
            : () {
                setState(() {
                  _isSubmitting = true;
                });
                widget.onSubmit(
                  _selectedReason, 
                  _detailsController.text.trim()
                );
              },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ))
              : Text('SUBMIT REPORT'),
        ),
      ],
    );
  }
}