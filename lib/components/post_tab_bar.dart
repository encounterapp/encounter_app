import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago; // Import timeago
import 'package:encounter_app/pages/post_detail_page.dart'; // Import the post detail page

class PostsTabBar extends StatefulWidget {
  final String userId; // Add the userId as a parameter
  const PostsTabBar({super.key, required this.userId});

  @override
  State<PostsTabBar> createState() => _PostsTabBarState();
}

class _PostsTabBarState extends State<PostsTabBar> {
  // Function to fetch non-expired, active posts for the user
  Future<List<Map<String, dynamic>>> _fetchCurrentPosts() async {
    final now = DateTime.now().toUtc(); // Get current time in UTC
    final response = await Supabase.instance.client
        .from('posts')
        .select(
            '*, users:user_id(username, avatar_url)') // Join with the users table
        .eq('user_id',
            widget.userId) // Use the userId parameter here!
        .gt('expires_at', now.toIso8601String()) // Filter by expires_at > now
        .eq('status', 'active') // Only active posts
        .order('created_at',
            ascending: false);
    return response;
  }

  // Function to fetch archived posts (closed posts) for the user
  // We'll do an additional check using chat_sessions to find successful meetings
  Future<List<Map<String, dynamic>>> _fetchArchivedPosts() async {
    // First get all closed posts by this user
    final response = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url), closed_by')
        .eq('user_id', widget.userId)
        .eq('status', 'closed') // Closed posts
        .order('created_at', ascending: false);
    
    // Create a list to hold the filtered posts
    List<Map<String, dynamic>> archivedPosts = [];
    
    // For each closed post, check if there's a successful meeting in chat_sessions
    for (final post in response) {
      if (post['closed_by'] != null) {
        // Look up this chat session to see if the meeting was successful
        final chatSession = await Supabase.instance.client
            .from('chat_sessions')
            .select('successful_meeting')
            .eq('id', post['closed_by'])
            .maybeSingle();
            
        // If this chat session had a successful meeting, include it in archived posts
        if (chatSession != null && chatSession['successful_meeting'] == true) {
          archivedPosts.add(post);
        }
      }
    }
    
    return archivedPosts;
  }

  // Navigate to post detail page
  void _navigateToPostDetail(BuildContext context, String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailPage(postId: postId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Current Posts"),
              Tab(text: "Archived Posts"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Current Posts Tab - Now includes non-expired active posts
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchCurrentPosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}')); //Show Error
                    } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text(
                              "No current posts available.")); //No data message
                    } else {
                      // Display the non-expired posts using a ListView.builder
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final post = snapshot.data![index];
                          final user =
                              post['users']; // Access the joined user data.
                          // Customize how each post is displayed
                          return InkWell(
                            // Make the entire post card tappable
                            onTap: () => _navigateToPostDetail(context, post['id']),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: user?['avatar_url'] != null
                                              ? NetworkImage(user['avatar_url'])
                                              : const AssetImage(
                                                      'assets/default_avatar.png')
                                                  as ImageProvider, // Use a default image.
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user?['username'] ??
                                                    'Unknown User', //Handle null username
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              Text(
                                                timeago.format(DateTime.parse(
                                                    post['created_at'])), // Format the date
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Add a view details icon
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      post['title'] ??
                                          'No Title', //Make sure to handle null title
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      post['content'] ??
                                          'No Description', //Handle null description.
                                      style: const TextStyle(fontSize: 16),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    // Add more post details here as needed
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
                // Archived Posts Tab - Now displays closed posts with successful meetings
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchArchivedPosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(
                          child:
                              Text("No archived posts available.")); //Message for empty state
                    } else {
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final post = snapshot.data![index];
                          final user = post['users'];
                          
                          // Build archived post with success indicator and tap to view details
                          return InkWell(
                            onTap: () => _navigateToPostDetail(context, post['id']),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Archive badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'MEETING SUCCESSFUL',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: user?['avatar_url'] != null
                                              ? NetworkImage(user['avatar_url'])
                                              : const AssetImage(
                                                      'assets/default_avatar.png')
                                                  as ImageProvider,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user?['username'] ??
                                                    'Unknown User',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              Text(
                                                timeago.format(DateTime.parse(
                                                    post['created_at'])),
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Add a view details icon
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      post['title'] ?? 'No Title',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      post['content'] ?? 'No Description',
                                      style: const TextStyle(fontSize: 16),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}