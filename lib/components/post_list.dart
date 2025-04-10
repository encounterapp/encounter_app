import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/new_chat.dart';
import 'package:encounter_app/utils/post_location_filter.dart';
import 'package:encounter_app/pages/home_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:encounter_app/controllers/chat_controller.dart';
import 'package:encounter_app/pages/post_detail_page.dart'; 
import 'package:encounter_app/utils/post_manager.dart';

/// Improved user profile cache with better error handling and typing
class UserProfileCache {
  static final Map<String, Map<String, dynamic>> _profiles = {};
  static final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  static Future<Map<String, dynamic>> getProfile(String userId, SupabaseClient supabase) async {
    // Return from cache if available
    if (_profiles.containsKey(userId)) {
      return Future.value(_profiles[userId]!);
    }

    // Wait for pending request if one exists
    if (_pendingRequests.containsKey(userId)) {
      return _pendingRequests[userId]!.future;
    }

    // Create new request
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[userId] = completer;

    try {
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        final profile = _cacheAndReturn(userId, null, null);
        completer.complete(profile);
        _pendingRequests.remove(userId);
        return profile;
      }

      final profile = _cacheAndReturn(
          userId, response['username'], response['avatar_url']);
      completer.complete(profile);
      _pendingRequests.remove(userId);
      return profile;
    } catch (error) {
      debugPrint("Error fetching profile for $userId: $error");
      final profile = _cacheAndReturn(userId, null, null);
      completer.complete(profile);
      _pendingRequests.remove(userId);
      return profile;
    }
  }

  static Map<String, dynamic> _cacheAndReturn(
      String userId, String? username, String? avatarUrl) {
    final int colorValue = userId.hashCode & 0xFFFFFF;
    final String userIdShort = userId.substring(0, min(4, userId.length));

    final profile = {
      'username': username ?? 'User_$userIdShort',
      'avatar_url': avatarUrl,
      'avatar_color': colorValue,
    };

    _profiles[userId] = profile;
    return profile;
  }

  static void clearCache() {
    _profiles.clear();
  }
}

/// A post model class to represent a post
class Post {
  final String id;
  final String userId;
  final String? title;
  final String? content;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String status; // 'active', 'closed', etc.
  final double? distanceMiles;
  final bool? meetingConfirmed;
  final bool? meetingHappened;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isClosed => status == 'closed';
  bool get isArchived => isClosed && (meetingHappened ?? false);

  Post({
    required this.id,
    required this.userId,
    this.title,
    this.content,
    required this.createdAt,
    this.expiresAt,
    this.status = 'active', // Default status is active
    this.distanceMiles,
    this.meetingConfirmed,
    this.meetingHappened,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      status: json['status'] ?? 'active', // Default to active if null
      distanceMiles: json['distance_miles'],
      meetingConfirmed: json['meeting_confirmed'],
      meetingHappened: json['meeting_happened'],
    );
  }

  // Create a new post with updated fields
  Post copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
    double? distanceMiles,
    bool? meetingConfirmed,
    bool? meetingHappened,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      meetingConfirmed: meetingConfirmed ?? this.meetingConfirmed,
      meetingHappened: meetingHappened ?? this.meetingHappened,
    );
  }
}

/// A PostList controller to handle data fetching and state
class PostListController {
  final SupabaseClient supabase;
  final String? _userId;
  final StreamController<List<Post>> _postsController = StreamController<List<Post>>.broadcast();
  StreamSubscription<List<Map<String, dynamic>>>? _postsStreamSubscription;
  bool _isLoading = true;
  bool _locationFilterEnabled = true;
  double _maxDistance = 5.0;
  String _genderFilter = "Everyone"; // Default gender filter
  static const double MAX_ALLOWED_DISTANCE = 5.0;
  bool _locationServicesAvailable = true;

  // Expose streams and state
  Stream<List<Post>> get postsStream => _postsController.stream;
  bool get isLoading => _isLoading;
  bool get locationFilterEnabled => _locationFilterEnabled;
  bool get locationServicesAvailable => _locationServicesAvailable;
  double get maxDistance => _maxDistance;
  String get genderFilter => _genderFilter;
  bool get isUserSpecific => _userId != null;

  PostListController({required this.supabase, String? userId}) : _userId = userId {
    _init();
  }

  Future<void> _init() async {
    await _loadFilterPreferences();
    _loadPosts();
  }

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Only enable location filter on the main feed (not on user profiles)
    final locationEnabled = _userId == null && (prefs.getBool('location_filter_enabled') ?? true);
    
    // Load distance but ensure it doesn't exceed max distance
    double distance = prefs.getDouble('filter_distance') ?? 5.0;
    if (distance > MAX_ALLOWED_DISTANCE) {
      distance = MAX_ALLOWED_DISTANCE;
      // Save the corrected value back to preferences
      await prefs.setDouble('filter_distance', MAX_ALLOWED_DISTANCE);
    }
    
    // Load gender filter
    final genderPref = prefs.getString('filter_gender') ?? "Everyone";
    
    _locationFilterEnabled = locationEnabled;
    _maxDistance = distance;
    _genderFilter = genderPref;
  }

  void _loadPosts() {
    _isLoading = true;

    // Build the base query
    var query = supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    // Apply user ID filter if provided
    if (_userId != null) {
      query = supabase
          .from('posts')
          .stream(primaryKey: ['id'])
          .eq('user_id', _userId)
          .order('created_at', ascending: false);
    }

    // Subscribe to the stream
    _postsStreamSubscription = query.listen((data) async {
      await _processPostsData(data);
    }, onError: (error) {
      debugPrint("Stream error: $error");
      _isLoading = false;
      _postsController.addError(error);
    });
  }

  Future<void> _processPostsData(List<Map<String, dynamic>> data) async {
    try {
      // Filter out expired posts
      List<Map<String, dynamic>> filteredData = data.where((post) {
        final expiresAt = post['expires_at'];
        if (expiresAt == null) {
          return true;
        }
        try {
          final expiryDate = DateTime.parse(expiresAt);
          return expiryDate.isAfter(DateTime.now());
        } catch (e) {
          debugPrint("Invalid date format for expires_at: $e");
          return true;
        }
      }).toList();
      
      // Filter out posts based on status for main feed vs. user profile
      if (_userId == null) {
        // For main feed, show only active posts
        filteredData = filteredData.where((post) => 
          post['status'] == null || post['status'] == 'active'
        ).toList();
      } else {
        // For user profile, show all posts except deleted ones
        filteredData = filteredData.where((post) => 
          post['status'] != 'deleted'
        ).toList();
      }
      
      // Apply location and gender filtering if on the main feed
      if (_userId == null) {
        final filterResult = await PostLocationFilter.filterPosts(
          filteredData, 
          maxDistance: _maxDistance,
          genderFilter: _genderFilter,
          locationFilterEnabled: _locationFilterEnabled
        );
        
        _locationServicesAvailable = filterResult.locationServicesAvailable;
        
        // If location services are unavailable and location filtering is enabled, set empty list
        if (!_locationServicesAvailable && _locationFilterEnabled) {
          filteredData = [];
        } else {
          filteredData = filterResult.posts;
        }
      }

      // Convert to Post objects
      final posts = filteredData.map((json) => Post.fromJson(json)).toList();
      
      // Add to stream
      _postsController.add(posts);
      _isLoading = false;
    } catch (e) {
      debugPrint("Error processing posts: $e");
      _postsController.addError(e);
      _isLoading = false;
    }
  }

  Future<List<Post>> getInitialPosts() async {
    try {
      // Build the query
      var query = supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      
      if (_userId != null) {
        query = supabase
            .from('posts')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: false);
      }
      
      // Execute the query
      final response = await query;
      
      // Filter out expired posts
      List<Map<String, dynamic>> filteredPosts = response.where((post) {
        final expiresAt = post['expires_at'];
        if (expiresAt == null) {
          return true;
        }
        try {
          final expiryDate = DateTime.parse(expiresAt);
          return expiryDate.isAfter(DateTime.now());
        } catch (e) {
          debugPrint("Invalid date format for expires_at: $e");
          return true;
        }
      }).toList();
      
      // Filter posts based on status
      if (_userId == null) {
        // For main feed, show only active posts
        filteredPosts = filteredPosts.where((post) => 
          post['status'] == null || post['status'] == 'active'
        ).toList();
      } else {
        // For user profile, show all posts except deleted ones
        filteredPosts = filteredPosts.where((post) => 
          post['status'] != 'deleted'
        ).toList();
      }
      
      // Apply filters if not on a specific user profile
      if (_userId == null) {
        final filterResult = await PostLocationFilter.filterPosts(
          filteredPosts, 
          maxDistance: _maxDistance,
          genderFilter: _genderFilter,
          locationFilterEnabled: _locationFilterEnabled
        );
        
        _locationServicesAvailable = filterResult.locationServicesAvailable;
        
        if (!_locationServicesAvailable && _locationFilterEnabled) {
          filteredPosts = [];
        } else {
          filteredPosts = filterResult.posts;
        }
      }
      
      // Convert to Post objects
      return filteredPosts.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching initial posts: $e");
      return [];
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    await _loadFilterPreferences();
    _loadPosts();
  }

  void dispose() {
    _postsStreamSubscription?.cancel();
    _postsController.close();
  }

  // Existing code with new method to refresh after deletion
  Future<void> refreshAfterDeletion() async {
    _isLoading = true;
    notifyListeners();
    await _loadFilterPreferences();
    _loadPosts();
  }
  
  // Add this method to notify UI changes
  void notifyListeners() {
    _postsController.add([]);
  }
}

/// Displays a list of posts, optionally filtered by user ID.
class PostList extends StatefulWidget {
  final String? userId; // Optional user ID to filter posts
  const PostList({this.userId, super.key});

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> with AutomaticKeepAliveClientMixin {
  late PostListController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = PostListController(
      supabase: Supabase.instance.client,
      userId: widget.userId,
    );
        // Archive expired posts on initialization
    _archiveExpiredPosts();
  }

    Future<void> _archiveExpiredPosts() async {
    // Only run this for current user's posts (not when viewing others)
    if (_controller.isUserSpecific) {
      final archivedCount = await PostManager.archiveAllExpiredPosts();
      if (archivedCount > 0) {
        // If we archived posts, refresh the list
        _controller.refresh();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return StreamBuilder<List<Post>>(
      stream: _controller.postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        return FutureBuilder<List<Post>>(
          future: _controller.getInitialPosts(),
          builder: (context, initialSnapshot) {
            // Show loading indicator if still loading
            if (_controller.isLoading && !initialSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Use data from either stream or initial load
            List<Post> posts = [];
            if (snapshot.hasData) {
              posts = snapshot.data!;
            } else if (initialSnapshot.hasData) {
              posts = initialSnapshot.data!;
            }

            if (posts.isEmpty) {
              return _buildEmptyStateView();
            }

            return RefreshIndicator(
              onRefresh: () async {
                await _controller.refresh();
              },
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    supabase: Supabase.instance.client,
                    isCurrentUser: widget.userId == Supabase.instance.client.auth.currentUser?.id,
                    onPostDeleted: () {
                      _controller.refreshAfterDeletion();
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyStateView() {
    // Check if empty due to location issues or no posts
    if (_controller.locationFilterEnabled && 
        !_controller.isUserSpecific && 
        !_controller.locationServicesAvailable) {
      return _buildLocationDisabledView();
    }
    
    return _buildNoPostsView();
  }

  Widget _buildLocationDisabledView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_disabled, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Location services unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please enable location services to see posts nearby',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on),
            label: const Text('Enable Location'),
            onPressed: () => _controller.refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPostsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _controller.locationFilterEnabled ? Icons.location_off : Icons.article_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _controller.locationFilterEnabled 
              ? 'No posts found within ${_controller.maxDistance} miles'
              : 'No posts found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A card that displays a single post
class PostCard extends StatelessWidget {
  final Post post;
  final SupabaseClient supabase;
  final bool isCurrentUser;
  final VoidCallback onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    required this.supabase,
    required this.isCurrentUser,
    required this.onPostDeleted,
  });

  /// Handles the action when user wants to delete their post
  Future<void> _handleDeletePost(BuildContext context) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null || currentUser.id != post.userId) {
      return; // Not the post owner
    }

    // Check if post has active chat sessions
    final hasActiveSessions = await PostManager.hasActiveChatSessions(post.id);

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
    final success = await PostManager.deletePost(post.id);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Call the callback to refresh the list
        onPostDeleted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navigates to the profile page of the user who created the post
  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomePage(selectedIndex: 2, selectedUserId: userId),
      ),
    );
  }

    // Add a method to navigate to post detail page
  void _navigateToPostDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailPage(postId: post.id),
      ),
    );
  }

  /// Handles the action when the user wants to chat with the post author
  void _handleChat(BuildContext context, String recipientId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to send direct messages.")),
      );
      return;
    }

    // Check if post is closed
    if (post.isClosed) {
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
      currentUser.id,
      recipientId
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
      post.id,
      recipientId,
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

    // Show a modal bottom sheet for the chat screen
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ChatScreen(
          recipientId: recipientId,
          postId: post.id, // Pass post ID to chat screen
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateString.substring(0, min(10, dateString.length));
    }
  }

   @override
  Widget build(BuildContext context) {
    // Check if the post is expired, though this should be filtered earlier
    if (post.isExpired) {
      return const SizedBox.shrink();
    }

    return InkWell( // Wrap with InkWell to make entire card clickable
      onTap: () => _navigateToPostDetail(context), // Navigate to post detail page
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post status indicator
            if (post.isClosed) 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red)
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
              
            // User info row with avatar and username
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: UserProfileCache.getProfile(post.userId, supabase),
                  builder: (context, snapshot) {
                    // Default values
                    String username = 'User_${post.userId.substring(0, min(4, post.userId.length))}';
                    String? profilePic;
                    int avatarColor = post.userId.hashCode & 0xFFFFFF;

                    // If we have data, use it
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData &&
                        snapshot.data != null) {
                      username = snapshot.data!['username'] ?? username;
                      profilePic = snapshot.data!['avatar_url'];
                      avatarColor = snapshot.data!['avatar_color'] ?? avatarColor;
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingUserInfo();
                    }

                    return _buildUserInfo(context, username, profilePic, avatarColor);
                  },
                ),
                const Spacer(),
                // Timestamp and distance info
                _buildTimestampAndDistance(),
              ],
            ),
            
            const SizedBox(height: 5),
            
            // Post content
            Text(
              post.content ?? 'No content available',
              style: const TextStyle(fontSize: 15),
              maxLines: 3, // Limit the number of lines
              overflow: TextOverflow.ellipsis, // Add ellipsis for long text
            ),
            
            const SizedBox(height: 10),
            
            // Action buttons
            Row(
              children: [
                // Make button disabled when post is closed
                IconButton(
                  icon: Image.asset("assets/icons/hand.png", 
                    width: 45,
                    color: post.isClosed ? Colors.grey : null, // Grey out if closed
                  ),
                  onPressed: post.isClosed || post.userId == supabase.auth.currentUser?.id
                    ? null  // Disable for closed posts or own posts
                    : () => _handleChat(context, post.userId),
                ),
                
                // Delete button - only visible to the post owner and for active posts
                if (isCurrentUser && !post.isClosed)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleDeletePost(context),
                    tooltip: 'Delete Post',
                  ),
                
                const Spacer(),
                
                // Add a "View Details" button
                TextButton.icon(
                  onPressed: () => _navigateToPostDetail(context),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            
            const Divider(height: 15, thickness: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUserInfo() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          radius: 22,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          'Loading...',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(BuildContext context, String username, String? profilePic, int avatarColor) {
    return GestureDetector(
      onTap: () => _navigateToProfile(context, post.userId),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(avatarColor),
            radius: 22,
            backgroundImage: profilePic != null
                ? NetworkImage(profilePic)
                : null,
            child: profilePic == null
                ? Text(
                    username.substring(0, min(2, username.length)).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            '@$username',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampAndDistance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatDate(post.createdAt.toIso8601String()),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        if (post.expiresAt != null)
          Text(
            "Expires: ${_formatDate(post.expiresAt!.toIso8601String())}",
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
        if (post.distanceMiles != null)
          Row(
            children: [
              Icon(Icons.place, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: 2),
              Text(
                "${post.distanceMiles!.toStringAsFixed(1)} miles",
                style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}