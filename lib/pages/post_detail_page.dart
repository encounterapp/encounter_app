import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/new_chat.dart';
import 'package:encounter_app/pages/home_page.dart';
import 'package:encounter_app/controllers/chat_controller.dart';
import 'package:encounter_app/utils/distance_utils.dart';
import 'package:encounter_app/utils/post_manager.dart'; // Import PostManager
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _author;
  String? _currentUserId;
  bool _isAuthor = false;
  double? _distanceToAuthor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadPost();
  }

  void _initializeUser() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }

  Future<void> _loadPost() async {
    try {
      // Fetch post details including user profile via join
      final response = await supabase
          .from('posts')
          .select('*, profiles:user_id(*)')
          .eq('id', widget.postId)
          .single();

      if (mounted) {
        setState(() {
          _post = response;
          _author = response['profiles'];
          _isAuthor = _currentUserId == response['user_id'];
          _isLoading = false;
        });

        // If it's not the author, calculate distance
        if (!_isAuthor) {
          _calculateDistanceToAuthor();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading post: ${e.toString()}';
        });
      }
      debugPrint('Error loading post: $e');
    }
  }

  Future<void> _calculateDistanceToAuthor() async {
    if (_author == null) return;
    
    // Store current user ID in a local final variable to allow promotion
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      // Get current user's location
      final currentUserLocation = await supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', currentUserId)
          .single();

      if (currentUserLocation == null ||
          currentUserLocation['latitude'] == null ||
          currentUserLocation['longitude'] == null ||
          _author!['latitude'] == null ||
          _author!['longitude'] == null) {
        return;
      }

      // Calculate distance using Haversine formula
      final double lat1 = currentUserLocation['latitude'];
      final double lon1 = currentUserLocation['longitude'];
      final double lat2 = _author!['latitude'];
      final double lon2 = _author!['longitude'];

      final distance = await _calculateHaversineDistance(lat1, lon1, lat2, lon2);

      if (mounted) {
        setState(() {
          _distanceToAuthor = distance;
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
    }
  }

  // Calculate distance between two coordinates
  Future<double> _calculateHaversineDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) async {
    // Use our utility class to calculate distance
    return DistanceUtils.calculateDistance(lat1, lon1, lat2, lon2);
  }

  void _handleChat() async {
    if (_post == null || _author == null) return;
    
    // Store current user ID in a local final variable to allow promotion
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to chat.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

      // Check if user is trying to chat with themselves
  if (currentUserId == _post!['user_id']) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot start a chat with yourself.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

    // Check if post is closed
    if (_post!['status'] == 'closed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post is closed. The users have already matched.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if the user can start a chat (24-hour rule)
    final bool canChat = await ChatController.canStartChatWith(
      currentUserId,
      _post!['user_id']
    );
  
    if (!canChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot start a chat with this user for 24 hours after declining.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Don't proceed with chat creation
    }

    // Create a chat session linked to this post
    final chatSessionId = await ChatController.createChatSessionForPost(
      widget.postId,
      _post!['user_id'],
      context
    );
    
    // If chat session creation failed, show error
    if (chatSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create chat session. Try again later.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Open the chat screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            recipientId: _post!['user_id'],
            postId: widget.postId,
          ),
        ),
      );
    }
  }

  void _navigateToProfile() {
    if (_post == null) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomePage(
          selectedIndex: 2, 
          selectedUserId: _post!['user_id'],
        ),
      ),
    );
  }

  // New method to handle post deletion
  // For PostDetailPage class in lib/pages/post_detail_page.dart
Future<void> _handleDeletePost() async {
  // Use widget.postId instead of post.id
  final String postId = widget.postId;
  
  // Check if post has active chat sessions
  final hasActiveSessions = await PostManager.hasActiveChatSessions(postId);

  // Show confirmation dialog
  final confirmDelete = await PostManager.showDeleteConfirmation(
    context,
    hasActiveSessions: hasActiveSessions,
  );

  if (!confirmDelete) return;

  // Show loading indicator
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Deleting post...'),
      duration: Duration(seconds: 1),
    ),
  );

  // Attempt to delete the post
  final result = await PostManager.deletePost(postId);

  if (context.mounted) {
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to home instead of using onPostDeleted
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomePage(selectedIndex: 0),
        ),
      );
    } else {
      // Enhanced error dialog with retry option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('Failed to Delete Post'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('There was a problem deleting your post.'),
              SizedBox(height: 8),
              if (result['error'] != null)
                Text(
                  'Error: ${result['error']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              SizedBox(height: 16),
              Text('Would you like to try again?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDeletePost(); // Retry deletion
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: Text('TRY AGAIN'),
            ),
          ],
        ),
      );
    }
  }
}

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatTimeAgo(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return timeago.format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPost,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: const Center(
          child: Text('Post not found'),
        ),
      );
    }

    // Whether post is expired
    final bool isExpired = _post!['expires_at'] != null && 
                         DateTime.parse(_post!['expires_at']).isBefore(DateTime.now());
    
    // Post status badges
    final bool isClosed = _post!['status'] == 'closed';
    final bool isArchived = _post!['status'] == 'archived';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          // Add delete button for post owner
          if (_isAuthor)
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: _handleDeletePost,
              tooltip: 'Delete Post',
            ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const HomePage(selectedIndex: 0),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author section with avatar and username
            GestureDetector(
              onTap: _navigateToProfile,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _author != null && _author!['avatar_url'] != null
                          ? NetworkImage(_author!['avatar_url'])
                          : null,
                      child: _author == null || _author!['avatar_url'] == null
                          ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _author != null ? '@${_author!['username'] ?? 'Unknown User'}' : 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeAgo(_post!['created_at']),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              
                              if (_distanceToAuthor != null) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.place, size: 16, color: Colors.blue[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${_distanceToAuthor!.toStringAsFixed(1)} miles away',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Status badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        'CLOSED',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    
                  if (isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Text(
                        'ARCHIVED',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    
                  if (!isExpired && !isClosed && !isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Post title and content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _post!['title'] ?? 'No Title',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _post!['content'] ?? 'No content available',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Timing information
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timeline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTimelineItem(
                        'Created',
                        _formatDate(_post!['created_at']),
                        Icons.create,
                        Colors.blue,
                      ),
                      
                      if (_post!['expires_at'] != null)
                        _buildTimelineItem(
                          'Expires',
                          _formatDate(_post!['expires_at']),
                          Icons.timer,
                          isExpired ? Colors.red : Colors.orange,
                        ),
                        
                      if (_post!['closed_at'] != null)
                        _buildTimelineItem(
                          'Closed',
                          _formatDate(_post!['closed_at']),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        
                      if (_post!['archived_at'] != null)
                        _buildTimelineItem(
                          'Archived',
                          _formatDate(_post!['archived_at']),
                          Icons.archive,
                          Colors.blue,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
      // Only show the chat button if user is not the author and post is active
      floatingActionButton: (!_isAuthor && !isClosed && !isExpired && !isArchived) 
        ? FloatingActionButton.extended(
            onPressed: _handleChat,
            icon: Image.asset("assets/icons/hand.png", width: 30),
            label: const Text('Chat'),
            backgroundColor: Colors.blue,
          )
        : _isAuthor && !isClosed && !isExpired && !isArchived
          ? FloatingActionButton.extended(
              onPressed: _handleDeletePost,
              icon: const Icon(Icons.delete),
              label: const Text('Delete Post'),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }
  
  Widget _buildTimelineItem(
    String label, 
    String value, 
    IconData icon, 
    Color color
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}