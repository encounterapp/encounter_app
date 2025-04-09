import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:encounter_app/pages/post_detail_page.dart';
import 'package:encounter_app/utils/post_manager.dart';

class PostsTabBar extends StatefulWidget {
  final String userId;
  const PostsTabBar({super.key, required this.userId});

  @override
  State<PostsTabBar> createState() => _PostsTabBarState();
}

class _PostsTabBarState extends State<PostsTabBar> {
  // Track if we need to refresh the tab views
  bool _shouldRefreshCurrent = false;
  bool _shouldRefreshArchived = false;

  @override
  void initState() {
    super.initState();
    // Archive any expired posts when the tab bar is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _archiveExpiredPosts();
    });
  }

  Future<void> _archiveExpiredPosts() async {
    // Only run for the current user
    if (widget.userId == Supabase.instance.client.auth.currentUser?.id) {
      final count = await PostManager.archiveAllExpiredPosts();
      if (count > 0 && mounted) {
        setState(() {
          _shouldRefreshCurrent = true;
          _shouldRefreshArchived = true;
        });
      }
    }
  }

  // Function to fetch non-expired, active posts for the user
  Future<List<Map<String, dynamic>>> _fetchCurrentPosts() async {
    // Reset the refresh flag
    _shouldRefreshCurrent = false;
    
    final now = DateTime.now().toUtc();
    final response = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url)')
        .eq('user_id', widget.userId)
        .gt('expires_at', now.toIso8601String())
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return response;
  }

  // Function to fetch archived posts, now including expired posts
  Future<List<Map<String, dynamic>>> _fetchArchivedPosts() async {
    // Reset the refresh flag
    _shouldRefreshArchived = false;
    
    final now = DateTime.now().toUtc();
    
    // Get both closed and expired posts
    final List<Map<String, dynamic>> response = [];
    
    // 1. Get closed posts with successful meetings
    final closedPosts = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url), closed_by')
        .eq('user_id', widget.userId)
        .eq('status', 'closed')
        .order('created_at', ascending: false);
    
    // For each closed post, check if there's a successful meeting
    for (final post in closedPosts) {
      if (post['closed_by'] != null) {
        // Look up this chat session to see if the meeting was successful
        final chatSession = await Supabase.instance.client
            .from('chat_sessions')
            .select('successful_meeting')
            .eq('id', post['closed_by'])
            .maybeSingle();
            
        // If this chat session had a successful meeting, include it in archived posts
        if (chatSession != null && chatSession['successful_meeting'] == true) {
          post['archive_reason'] = 'successful_meeting';
          response.add(post);
        }
      }
    }
    
    // 2. Get expired posts
    final expiredPosts = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url)')
        .eq('user_id', widget.userId)
        .lt('expires_at', now.toIso8601String())
        .order('created_at', ascending: false);
    
    // Add expired posts with an indicator
    for (final post in expiredPosts) {
      post['archive_reason'] = 'expired';
      response.add(post);
    }
    
    // 3. Get explicitly archived posts
    final archivedPosts = await Supabase.instance.client
        .from('posts')
        .select('*, users:user_id(username, avatar_url)')
        .eq('user_id', widget.userId)
        .eq('status', 'archived')
        .order('created_at', ascending: false);
    
    // Add archived posts with an indicator
    for (final post in archivedPosts) {
      post['archive_reason'] = 'archived';
      response.add(post);
    }
    
    return response;
  }

  // Navigate to post detail page
  void _navigateToPostDetail(BuildContext context, String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailPage(postId: postId)),
    ).then((_) {
      // Refresh the lists when returning from post detail
      if (mounted) {
        setState(() {
          _shouldRefreshCurrent = true;
          _shouldRefreshArchived = true;
        });
      }
    });
  }
  
  // Delete a post after confirmation
  Future<void> _handleDeletePost(BuildContext context, String postId, bool isActive) async {
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
    final success = await PostManager.deletePost(postId);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the appropriate tab
        setState(() {
          if (isActive) {
            _shouldRefreshCurrent = true;
          } else {
            _shouldRefreshArchived = true;
          }
        });
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

  @override
  Widget build(BuildContext context) {
    // Check if the viewer is the post owner
    final isCurrentUser = widget.userId == Supabase.instance.client.auth.currentUser?.id;
    
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
                // Current Posts Tab
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchCurrentPosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No current posts available."));
                    } else {
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            _shouldRefreshCurrent = true;
                          });
                        },
                        child: ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final post = snapshot.data![index];
                            final user = post['users'];
                            return InkWell(
                              onTap: () => _navigateToPostDetail(context, post['id']),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                                : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user?['username'] ?? 'Unknown User',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                Text(
                                                  timeago.format(DateTime.parse(post['created_at'])),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Delete button (only for post owner)
                                          if (isCurrentUser)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _handleDeletePost(context, post['id'], true),
                                              tooltip: 'Delete Post',
                                            ),
                                            
                                          // Details button
                                          IconButton(
                                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                            onPressed: () => _navigateToPostDetail(context, post['id']),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        post['title'] ?? 'No Title',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        ),
                      );
                    }
                  },
                ),
                
                // Archived Posts Tab
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchArchivedPosts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No archived posts available."));
                    } else {
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            _shouldRefreshArchived = true;
                          });
                        },
                        child: ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final post = snapshot.data![index];
                            final user = post['users'];
                            final archiveReason = post['archive_reason'] ?? 'unknown';
                            
                            // Determine badge styling based on archive reason
                            String badgeText;
                            Color badgeColor;
                            IconData badgeIcon;
                            
                            switch (archiveReason) {
                              case 'successful_meeting':
                                badgeText = 'MEETING SUCCESSFUL';
                                badgeColor = Colors.green;
                                badgeIcon = Icons.check_circle;
                                break;
                              case 'expired':
                                badgeText = 'EXPIRED';
                                badgeColor = Colors.orange;
                                badgeIcon = Icons.timer_off;
                                break;
                              case 'archived':
                                badgeText = 'ARCHIVED';
                                badgeColor = Colors.blue;
                                badgeIcon = Icons.archive;
                                break;
                              default:
                                badgeText = 'ARCHIVED';
                                badgeColor = Colors.grey;
                                badgeIcon = Icons.archive;
                            }
                            
                            return InkWell(
                              onTap: () => _navigateToPostDetail(context, post['id']),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: badgeColor.withOpacity(0.3)),
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
                                          color: badgeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(badgeIcon, color: badgeColor, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              badgeText,
                                              style: TextStyle(
                                                color: badgeColor,
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
                                                : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user?['username'] ?? 'Unknown User',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                Text(
                                                  timeago.format(DateTime.parse(post['created_at'])),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Delete button (only for post owner)
                                          if (isCurrentUser)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _handleDeletePost(context, post['id'], false),
                                              tooltip: 'Delete Archived Post',
                                            ),
                                            
                                          // Details button
                                          IconButton(
                                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                            onPressed: () => _navigateToPostDetail(context, post['id']),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        post['title'] ?? 'No Title',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        ),
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