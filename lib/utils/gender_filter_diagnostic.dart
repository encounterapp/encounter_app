import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A diagnostic tool to check what's happening with gender filters
class GenderFilterDiagnostic {
  /// Run a gender filter diagnostic check
  static Future<void> runDiagnostic(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    // Results collection
    final diagnosticResults = <String, dynamic>{};
    
    try {
      // Step 1: Check if filters are saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      diagnosticResults['genderFilter'] = prefs.getString('filter_gender') ?? "Not set";
      diagnosticResults['locationEnabled'] = prefs.getBool('location_filter_enabled') ?? "Not set";
      diagnosticResults['maxDistance'] = prefs.getDouble('filter_distance') ?? "Not set";
      
      // Step 2: Check user profile data
      diagnosticResults['myProfile'] = <String, dynamic>{};
      if (userId != null) {
        try {
          final myProfileResponse = await supabase
              .from('profiles')
              .select('id, username, gender')
              .eq('id', userId)
              .single();
          
          diagnosticResults['myProfile'] = {
            'id': myProfileResponse['id'] as String,
            'username': myProfileResponse['username'] as String? ?? 'Unknown',
            'gender': myProfileResponse['gender'] as String? ?? 'Not set',
          };
        } catch (e) {
          diagnosticResults['myProfile'] = {
            'error': 'Failed to fetch profile: $e',
          };
        }
      } else {
        diagnosticResults['myProfile'] = {
          'error': 'User not logged in',
        };
      }
      
      // Step 3: Fetch recent posts
      final recentPosts = await supabase
          .from('posts')
          .select('id, user_id, content, created_at')
          .order('created_at', ascending: false)
          .limit(5);
      
      // Step 4: Get gender info for post authors
      final postDetails = <Map<String, dynamic>>[];
      for (var post in recentPosts) {
        final postAuthorId = post['user_id'] as String?;
        final postId = post['id'] as String?;
        final content = post['content'] as String?;
        
        Map<String, dynamic> postDetail = {
          'postId': postId ?? 'Unknown',
          'authorId': postAuthorId ?? 'Unknown',
          'content': content ?? 'No content',
          'created_at': post['created_at'] as String? ?? 'Unknown date',
        };
        
        if (postAuthorId != null) {
          try {
            final authorProfile = await supabase
                .from('profiles')
                .select('username, gender')
                .eq('id', postAuthorId)
                .single();
            
            final username = authorProfile['username'] as String?;
            final gender = authorProfile['gender'] as String?;
            
            postDetail['authorUsername'] = username ?? 'Unknown';
            postDetail['authorGender'] = gender ?? 'Not set';
            
            // Check if this post would be filtered
            postDetail['passesFilter'] = {
              'everyone': true,
              'males': _checkMaleFilter(gender),
              'females': _checkFemaleFilter(gender),
            };
          } catch (e) {
            postDetail['authorError'] = e.toString();
          }
        } else {
          postDetail['authorError'] = 'No author ID';
        }
        
        postDetails.add(postDetail);
      }
      
      diagnosticResults['recentPosts'] = postDetails;
      
      // Display the results
      _showDiagnosticResults(context, diagnosticResults);
      
    } catch (e) {
      _showError(context, "Error running diagnostic: $e");
    }
  }
  
  /// Check if a gender value would pass the male filter
  static bool _checkMaleFilter(String? gender) {
    if (gender == null || gender.trim().isEmpty) return false;
    
    String normalized = gender.trim().toLowerCase();
    
    // Check for male indicators
    return normalized == "male" || 
           normalized == "m" || 
           normalized == "man" || 
           (normalized.contains("male") && !normalized.contains("female"));
  }
  
  /// Check if a gender value would pass the female filter
  static bool _checkFemaleFilter(String? gender) {
    if (gender == null || gender.trim().isEmpty) return false;
    
    String normalized = gender.trim().toLowerCase();
    
    // Check for female indicators
    return normalized == "female" || 
           normalized == "f" || 
           normalized == "woman" || 
           normalized.contains("female");
  }
  
  /// Show the diagnostic results
  static void _showDiagnosticResults(BuildContext context, Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gender Filter Diagnostic'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSection('Current Filters', [
                _buildTextRow('Gender Filter:', results['genderFilter'].toString()),
                _buildTextRow('Location Enabled:', results['locationEnabled'].toString()),
                _buildTextRow('Max Distance:', results['maxDistance'].toString()),
              ]),
              
              _buildSection('My Profile', [
                if (results['myProfile']['error'] != null)
                  _buildTextRow('Error:', results['myProfile']['error'].toString())
                else ...[
                  _buildTextRow('ID:', results['myProfile']['id'].toString()),
                  _buildTextRow('Username:', results['myProfile']['username'].toString()),
                  _buildTextRow('Gender:', results['myProfile']['gender'].toString()),
                ]
              ]),
              
              _buildSection('Recent Posts (${(results['recentPosts'] as List).length})', [
                for (var post in results['recentPosts'] as List)
                  _buildPostInfo(post as Map<String, dynamic>),
              ]),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  /// Show an error message
  static void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostic Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Build a section with a title and content
  static Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
  
  /// Build a text row with label and value
  static Widget _buildTextRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  /// Build post information section
  static Widget _buildPostInfo(Map<String, dynamic> post) {
    // Safely extract values from the post map
    final String postContent = post['content']?.toString() ?? 'No content';
    final String authorUsername = post['authorUsername']?.toString() ?? post['authorId']?.toString() ?? 'Unknown';
    final String authorGender = post['authorGender']?.toString() ?? 'Unknown';
    final String? authorError = post['authorError']?.toString();
    final Map<String, dynamic>? filterStatus = post['passesFilter'] as Map<String, dynamic>?;
    
    final bool passesMaleFilter = filterStatus?['males'] == true;
    final bool passesFemaleFilter = filterStatus?['females'] == true;
    
    // Truncate content if needed
    final String displayContent = postContent.length > 30 
        ? postContent.substring(0, 30) + '...'
        : postContent;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayContent,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextRow('Author:', authorUsername),
          _buildTextRow('Gender:', authorGender),
          if (authorError != null)
            _buildTextRow('Error:', authorError),
          const SizedBox(height: 4),
          if (filterStatus != null) Row(
            children: [
              Icon(
                passesMaleFilter ? Icons.check : Icons.close,
                color: passesMaleFilter ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text('Males Filter'),
              const SizedBox(width: 16),
              Icon(
                passesFemaleFilter ? Icons.check : Icons.close,
                color: passesFemaleFilter ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text('Females Filter'),
            ],
          ),
        ],
      ),
    );
  }
}