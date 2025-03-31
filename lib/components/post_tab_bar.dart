import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago; // Import timeago

class PostsTabBar extends StatefulWidget {
  final String userId; // Add the userId as a parameter
  const PostsTabBar({super.key, required this.userId});

  @override
  State<PostsTabBar> createState() => _PostsTabBarState();
}

class _PostsTabBarState extends State<PostsTabBar> {
  // Function to fetch non-expired posts for the  user
  Future<List<Map<String, dynamic>>> _fetchNonExpiredPosts() async {
    final now = DateTime.now().toUtc(); // Get current time in UTC
    final response = await Supabase.instance.client
        .from('posts')
        .select(
            '*, users:user_id(username, avatar_url)') // Join with the users table
        .eq('user_id',
            widget.userId) // Use the userId parameter here!
        .gt('expires_at', now.toIso8601String()) // Filter by expires_at > now
        .order('created_at',
            ascending:
                false);
    return response;
  }

  // Function to fetch expired posts for the user
  Future<List<Map<String, dynamic>>> _fetchExpiredPosts() async {
    final now = DateTime.now().toUtc();
    final response = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url)')
        .eq('user_id', widget.userId)
        .lt('expires_at', now.toIso8601String()) // Filter for expired posts
        .order('created_at', ascending:
                false);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Current Post"),
              Tab(text: "Archived Posts"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Current Post Tab - Now includes non-expired posts
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchNonExpiredPosts(),
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
                          return Container(
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
                                  ),
                                  // Add more post details here as needed
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
                // Archived Posts Tab - Now displays expired posts
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchExpiredPosts(),
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
                          return Container(
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
                                  ),
                                ],
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

