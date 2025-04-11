import 'package:flutter/material.dart';
import 'package:encounter_app/utils/safety_manager.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({Key? key}) : super(key: key);

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  // Map of report reasons to display text
  final Map<String, String> _reportReasons = {
    'inappropriate_content': 'Inappropriate Content',
    'harassment': 'Harassment or Bullying',
    'spam': 'Spam or Advertising',
    'underage_user': 'User appears to be underage',
    'impersonation': 'Impersonation',
    'other': 'Other',
  };

  // Map of report statuses to colors
  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'reviewed': Colors.blue,
    'action_taken': Colors.green,
    'dismissed': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await SafetyManager.getMyReports();
      
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getReportReasonText(String reason) {
    return _reportReasons[reason] ?? 'Unknown Reason';
  }

  String _formatReportStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'reviewed':
        return 'Under Review';
      case 'action_taken':
        return 'Action Taken';
      case 'dismissed':
        return 'Dismissed';
      default:
        return 'Unknown Status';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Reports Submitted',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t submitted any reports yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'If you encounter inappropriate behavior, you can report users to help keep the community safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final reportedProfiles = report['reported_profiles'];
        final username = reportedProfiles?['username'] ?? 'Unknown User';
        final avatarUrl = reportedProfiles?['avatar_url'];
        final reason = report['reason'];
        final details = report['details'];
        final status = report['status'] ?? 'pending';
        final createdAt = DateTime.parse(report['created_at']);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info and status
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? Icon(Icons.person, color: Colors.grey[600]) : null,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Reported ${timeago.format(createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColors[status]?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statusColors[status] ?? Colors.grey,
                        ),
                      ),
                      child: Text(
                        _formatReportStatus(status),
                        style: TextStyle(
                          color: _statusColors[status] ?? Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                
                // Report reason and details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.report_problem,
                      color: Colors.red[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason: ${_getReportReasonText(reason)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (details != null && details.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              details,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Admin notes if any
                if (report['admin_notes'] != null && report['admin_notes'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.blue[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Response from moderator:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report['admin_notes'],
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Tips about moderation process
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reports are typically reviewed within 24 hours.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}