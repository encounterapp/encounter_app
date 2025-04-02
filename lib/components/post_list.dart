import 'package:encounter_app/utils/location_manager.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/new_chat.dart';
import 'package:encounter_app/utils/post_location_filter.dart';
import 'dart:math';
import 'package:encounter_app/pages/home_page.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keep the original UserProfileCache class
class UserProfileCache {
  static final Map<String, Map<String, dynamic>> _profiles = {};
  static final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  static Future<Map<String, dynamic>> getProfile(
      String userId, SupabaseClient supabase) async {
    debugPrint("Attempting to get profile for user: $userId");

    if (_profiles.containsKey(userId)) {
      debugPrint("✅ Profile found in cache for user: $userId");
      return Future.value(_profiles[userId]!);
    }

    if (_pendingRequests.containsKey(userId)) {
      debugPrint("⏳ Profile request already in progress for user: $userId");
      return _pendingRequests[userId]!.future;
    }

    final Completer<Map<String, dynamic>> completer = Completer();
    _pendingRequests[userId] = completer;

    try {
      debugPrint("Fetching profile from database for user: $userId");
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      debugPrint("Database response for $userId: $response");

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
      debugPrint("❌ Error fetching profile for $userId: $error");
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
    debugPrint("Cached profile for $userId: $profile");
    return profile;
  }

  static void clearCache() {
    _profiles.clear();
  }
}

/// Displays a list of posts, optionally filtered by user ID.
class PostList extends StatefulWidget {
  final String? userId; // Optional user ID to filter posts
  const PostList({this.userId, super.key});

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList>
    with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>?
      _postsStreamSubscription;
  late String _userId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];
  bool _locationFilterEnabled = true; // Default to enable location filtering
  double _maxDistance = 5.0; // Default to 5 miles
  static const double MAX_ALLOWED_DISTANCE = 5.0; // New constant to enforce the limit

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? '';
    _loadFilterPreferences().then((_) => _loadPosts()); // Load preferences first
  }

  /// Loads filter preferences from SharedPreferences
  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Only enable location filter on the main feed (not on user profiles)
    final locationEnabled = _userId.isEmpty && (prefs.getBool('location_filter_enabled') ?? true);
    
    // Load distance but ensure it doesn't exceed 5 miles
    double distance = prefs.getDouble('filter_distance') ?? 5.0;
    if (distance > MAX_ALLOWED_DISTANCE) {
      distance = MAX_ALLOWED_DISTANCE;
      // Optionally save the corrected value back to preferences
      await prefs.setDouble('filter_distance', MAX_ALLOWED_DISTANCE);
    }
    
    if (mounted) {
      setState(() {
        _locationFilterEnabled = locationEnabled;
        _maxDistance = distance;
      });
    }
  }

  /// Loads posts from the database and listens for real-time updates.
  void _loadPosts() {
    _isLoading = true;

    // 1. Start by selecting the base table. Build the query.
    var query = supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    // 2. Apply user ID filter if provided.
    if (_userId.isNotEmpty) {
      query = supabase
          .from('posts')
          .stream(primaryKey: ['id'])
          .eq('user_id', _userId)
          .order('created_at', ascending: false);
    }

    // 3. *IMPORTANT*: Use listen and store the subscription.
    _postsStreamSubscription = query.listen((data) async {
      // 4. When new data arrives, filter and update the state
      if (mounted) {
        try {
          // Filter out expired posts first
          List<Map<String, dynamic>> filteredData = data.where((post) {
            final expiresAt = post['expires_at'];
            if (expiresAt == null) {
              return true; // Keep posts with no expiration date.
            }
            try {
              final expiryDate = DateTime.parse(expiresAt);
              return expiryDate.isAfter(DateTime.now()); // Keep if not expired.
            } catch (e) {
              print("Invalid date format for expires_at: $e");
              return true; // Keep the post to avoid losing data.
            }
          }).toList();
          
          // Apply location filtering if enabled and on the main feed
          if (_locationFilterEnabled && _userId.isEmpty) {
            final locationFilterResult = await PostLocationFilter.filterPostsByDistance(
              filteredData, 
              maxDistance: _maxDistance
            );
            
            // If location services are unavailable, set empty list
            if (locationFilterResult.locationServicesAvailable == false) {
              filteredData = []; // Show no posts when location is unavailable
            } else {
              filteredData = locationFilterResult.posts;
            }
          }

          setState(() {
            _posts = filteredData;
            _isLoading = false;
          });
        } catch (e) {
          debugPrint("Error filtering posts: $e");
          // On error, still update with the data we have
          setState(() {
            _posts = data;
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      // 5. Handle errors during the stream.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading posts: $error'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint("Stream error: $error");
    });
  }

  @override
  void dispose() {
    // Cancel the stream subscription to prevent memory leaks.
    _postsStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super for AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        // 1. Show loading indicator
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        
        // 2. Use FutureBuilder for initial data load
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _getInitialPosts(),
          builder: (context, initialSnapshot) {
            // 3. Handle different states of the FutureBuilder
            if (initialSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (initialSnapshot.hasError) {
              return Center(child: Text('Error: ${initialSnapshot.error}'));
            } else if (!initialSnapshot.hasData || initialSnapshot.data!.isEmpty) {
              if (!_isLoading) {
                if (_locationFilterEnabled && _userId.isEmpty) {
                  // Check if it's empty due to location services being unavailable
                  return FutureBuilder<bool>(
                    future: PostLocationFilter.isLocationAvailable(),
                    builder: (context, locationSnapshot) {
                      if (locationSnapshot.hasData && locationSnapshot.data == false) {
                        // Location services are unavailable - show appropriate message
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
                                onPressed: () async {
                                  final locationManager = LocationManager();
                                  await locationManager.initialize();
                                  // Refresh after attempting to enable location
                                  setState(() {
                                    _isLoading = true;
                                    _posts = [];
                                  });
                                  _loadPosts();
                                },
                              ),
                            ],
                          ),
                        );
                      } else {
                        // No posts found despite location being available
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No posts found nearby',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try moving to another location',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  );
                }
                return const Center(child: Text('No posts found.'));
              }
              return const Center(child: CircularProgressIndicator());
            } else {
              // 4. If initial data is loaded, update _posts and build the ListView
              List<Map<String, dynamic>> initialPosts = initialSnapshot.data!;
              
              // Filter out expired posts
              initialPosts = initialPosts.where((post) {
                final expiresAt = post['expires_at'];
                if (expiresAt == null) {
                  return true;
                }
                try {
                  final expiryDate = DateTime.parse(expiresAt);
                  return expiryDate.isAfter(DateTime.now());
                } catch (e) {
                  print("Invalid date format for expires_at: $e");
                  return true;
                }
              }).toList();

              if (_posts.isEmpty) {
                _posts = initialPosts;
              }
            }
            
            // 5. Build the ListView
            return RefreshIndicator(
              onRefresh: () async {
                // 6. Handle refresh
                setState(() {
                  _isLoading = true;
                  _posts = [];
                });
                // Reload filter preferences in case they changed
                await _loadFilterPreferences();
                _loadPosts();
                await Future.delayed(const Duration(seconds: 2));
              },
              child: _posts.isEmpty 
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height / 2 - 100,
                        child: Center(
                          child: FutureBuilder<bool>(
                            future: _locationFilterEnabled && _userId.isEmpty 
                              ? PostLocationFilter.isLocationAvailable()
                              : Future.value(true),
                            builder: (context, locationSnapshot) {
                              // Show location disabled message
                              if (_locationFilterEnabled && _userId.isEmpty && 
                                  locationSnapshot.hasData && locationSnapshot.data == false) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.location_disabled,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Location services unavailable',
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold
                                      ),
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
                                      onPressed: () async {
                                        final locationManager = LocationManager();
                                        await locationManager.initialize();
                                        // Refresh after attempting to enable location
                                        setState(() {
                                          _isLoading = true;
                                          _posts = [];
                                        });
                                        _loadPosts();
                                      },
                                    ),
                                  ],
                                );
                              } else {
                                // Regular empty state message
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _locationFilterEnabled && _userId.isEmpty
                                        ? Icons.location_off
                                        : Icons.article_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _locationFilterEnabled && _userId.isEmpty
                                        ? 'No posts found within $_maxDistance miles'
                                        : 'No posts found',
                                      style: const TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      // 7. Build each post item using PostCard
                      return PostCard(
                        key: ValueKey(_posts[index]['id']),
                        post: _posts[index],
                        supabase: supabase,
                      );
                    },
                  ),
            );
          },
        ),
      ],
    );
  }

  /// Fetches the initial set of posts.
  Future<List<Map<String, dynamic>>> _getInitialPosts() async {
    try {
      // 1. Build the query
      var query = supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      
      if (_userId.isNotEmpty) {
        query = supabase
            .from('posts')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: false);
      }
      
      // 2. Execute the query
      final response = await query;
      List<Map<String, dynamic>> filteredPosts = response;
      
      // 3. Apply location filtering if enabled (only on main feed)
      if (_locationFilterEnabled && _userId.isEmpty) {
        final locationFilterResult = await PostLocationFilter.filterPostsByDistance(
          response, 
          maxDistance: _maxDistance
        );
        
        // If location services are unavailable, set empty list
        if (locationFilterResult.locationServicesAvailable == false) {
          filteredPosts = []; // Show no posts when location is unavailable
        } else {
          filteredPosts = locationFilterResult.posts;
        }
      }
      
      return filteredPosts;
    } catch (e) {
      // 4. Handle error appropriately
      print("Error fetching initial posts: $e");
      return []; // Return an empty list to prevent the app from crashing
    }
  }
}

/// Displays a single post.
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final SupabaseClient supabase;

  const PostCard({super.key, required this.post, required this.supabase});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late String _postId;
  late String _userId;
  bool _isExpired = false; // State variable to track expiration

  @override
  void initState() {
    super.initState();
    _postId = widget.post['id'];
    _userId = widget.post['user_id'];
    _checkExpiration(); // Check expiration status in initState
  }

  void _checkExpiration() {
    final expiresAt = widget.post['expires_at'];
    if (expiresAt != null) {
      try {
        final expiryDate = DateTime.parse(expiresAt);
        if (mounted) {
          setState(() {
            _isExpired = expiryDate.isBefore(DateTime.now());
          });
        }
      } catch (e) {
        // Handle error, log it, and assume not expired to show it.
        print("Error parsing expires_at: $e");
        if (mounted) {
          setState(() {
            _isExpired = false; // keep showing the post.  Or set to true to hide it.
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isExpired = false;
        });
      }
    }
  }

  /// Navigates to the profile page of the user who created the post.
  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            HomePage(selectedIndex: 2, selectedUserId: userId),
      ),
    );
  }

  /// Handles the action when the user wants to chat with the post author.
  void _handleChat(BuildContext context, String recipientId) {
    final currentUser = widget.supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You must be logged in to send direct messages.")),
      );
      return;
    }

    // Show a modal bottom sheet for the chat screen.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take up most of the screen.
      backgroundColor: Colors.white, // Set background color.
      shape: const RoundedRectangleBorder(
        // Give it rounded corners.
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias, // Ensure the border radius is applied.
      builder: (context) => SizedBox(
        // Define the height of the sheet.
        height: MediaQuery.of(context).size.height *
            0.9, // 90% of screen height.
        child: ChatScreen(
            recipientId:
                recipientId), // Pass the recipient ID to the chat screen.
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the post is expired, return an empty container.
    if (_isExpired) {
      return const SizedBox.shrink(); // This will remove the post from the UI.
    }

    // Check if the post has distance information
    final hasDistance = widget.post.containsKey('distance_miles');
    final double? distanceMiles = hasDistance ? widget.post['distance_miles'] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Display user info (avatar and username).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Map<String, dynamic>>(
                // Use FutureBuilder to get user profile.
                future: UserProfileCache.getProfile(_userId, widget.supabase),
                builder: (context, snapshot) {
                  // 2. Handle different states of the FutureBuilder.
                  // Default values.  These are used while loading, or if there's an error.
                  String username = 'User_$_userId';
                  String? profilePic;
                  int avatarColor = _userId.hashCode & 0xFFFFFF;

                  // If we have data, use it
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data != null) {
                    username = snapshot.data!['username'] ?? username;
                    profilePic = snapshot.data!['avatar_url'];
                    avatarColor = snapshot.data!['avatar_color'] ?? avatarColor;
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          radius: 22,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
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

                  // Convert the hash code to a color for consistent avatar backgrounds
                  final Color avatarBgColor = Color(avatarColor);

                  // 3. Display the user info.
                  return GestureDetector(
                    onTap: () =>
                        _navigateToProfile(context, _userId), // Navigate on tap.
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: avatarBgColor, // Use calculated color.
                          radius: 22,
                          backgroundImage: profilePic != null
                              ? NetworkImage(profilePic)
                              : null, // Use network image if available.
                          child: profilePic == null
                              ? Text(
                                  // Display initials if no profile picture.
                                  username
                                      .substring(
                                          0,
                                          min(2, username.length))
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '@$username', // Display username.
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              // 4. Display post date, expiration date, and distance.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(widget.post['created_at']), // Format creation date.
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (widget.post['expires_at'] != null)
                    // Show expiration date if it exists.
                    Text(
                      "Expires: ${_formatDate(widget.post['expires_at'])}",
                      style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                    ),
                  // Display distance if available
                  if (distanceMiles != null)
                    Row(
                      children: [
                        Icon(Icons.place, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 2),
                        Text(
                          "${distanceMiles.toStringAsFixed(1)} miles",
                          style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              )
            ],
          ),
          // 5. Display post content.
          const SizedBox(height: 5),
          Text(
            widget.post['content'] ??
                'No content available', // Use a null-aware operator.
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 10),
          // 6. Display action buttons (chat, bookmark).
          Row(
            children: [
              IconButton(
                icon: Image.asset("assets/icons/hand.png", width: 45),
                onPressed: () =>
                    _handleChat(context, _userId), // Handle chat action.
              ),
              //IconButton(
              //  icon: Icon(
              //    _isBookmarked
              //        ? Icons.bookmark
              //        : Icons.bookmark_add,
              //    color: Colors.grey,
              //    size: 40,
              //  ),
              //  onPressed: () => _handleBookmark(context),
              //),
            ],
          ),
          // 7. Display a divider.
          const Divider(height: 15, thickness: 0.5),
        ],
      ),
    );
  }

  /// Formats a date string.
  ///
  /// Handles null dates and parsing errors.
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      // If parsing fails, return a truncated string.
      return dateString.substring(0, min(10, dateString.length));
    }
  }
}