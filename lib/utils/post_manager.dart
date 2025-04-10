import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/subscription_service.dart';
import 'package:encounter_app/utils/subscription_manager.dart';
import 'package:encounter_app/pages/home_page.dart';

/// A utility class to manage post operations like deletion and archiving
class PostManager {
  static final supabase = Supabase.instance.client;
  
  // Maximum number of active posts a user can have simultaneously
  static const int MAX_ACTIVE_POSTS = 2;

  /// Create a new post after checking subscription limits and active posts limit
  static Future<Map<String, dynamic>?> createPost(
    BuildContext context, 
    Map<String, dynamic> postData
  ) async {
    // First check if the user has reached active posts limit
    final activePostsCount = await _getActivePostsCount();
    
    if (activePostsCount >= MAX_ACTIVE_POSTS) {
      if (context.mounted) {
        _showActivePostsLimitReachedDialog(context);
      }
      return null;
    }
    
    // Next check if the user can create a post based on their subscription
    final canCreate = await SubscriptionManager.canCreatePost(context);
    
    if (!canCreate) return null;
    
    try {
      // Now create the post
      final response = await supabase
          .from('posts')
          .insert(postData)
          .select()
          .single();
          
      return response;
    } catch (e) {
      // Handle the case where the database throws an error
      // This could happen if the subscription check above passes,
      // but the database trigger still fails (unlikely but possible)
      if (e is PostgrestException && 
          e.message.contains('Monthly post limit reached')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have reached your monthly post limit. Please upgrade your subscription.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating post: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      debugPrint('Error creating post: $e');
      return null;
    }
  }
  
  /// Get the number of active posts for the current user
  static Future<int> _getActivePostsCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;
    
    try {
      // Get all active posts for the current user
      final response = await supabase
          .from('posts')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'active');
      
      // Count the results in the response list
      return response.length;
    } catch (e) {
      debugPrint('Error getting active posts count: $e');
      return 0;
    }
  }
  
  /// Show dialog when active posts limit is reached
  static void _showActivePostsLimitReachedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Active Posts Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can only have $MAX_ACTIVE_POSTS active posts at a time.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'To create a new post, you need to either:',
            ),
            SizedBox(height: 8),
            _buildOptionItem('Wait for someone to accept one of your posts'),
            _buildOptionItem('Wait for an existing post to expire'),
            _buildOptionItem('Delete one of your active posts'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to profile to see existing posts
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomePage(selectedIndex: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: Text('View My Posts'),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildOptionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 20, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  /// Delete a post by its ID
  /// Returns true if deletion was successful
// In lib/utils/post_manager.dart
static Future<Map<String, dynamic>> deletePost(String postId) async {
  try {
    // First check if the user is the owner of the post
    final user = supabase.auth.currentUser;
    if (user == null) return {'success': false, 'error': 'User not logged in'};

    final post = await supabase
        .from('posts')
        .select()
        .eq('id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (post == null) {
      return {
        'success': false, 
        'error': 'Post not found or you do not have permission to delete it'
      };
    }

    // End any related chat sessions
    await _endRelatedChatSessions(postId);

    // Instead of deleting the post, mark it as deleted
    // This ensures it still counts toward monthly limits
    await supabase.from('posts').update({
      'status': 'deleted',
      'deleted_at': DateTime.now().toIso8601String(),
      'deleted_by': user.id,
    }).eq('id', postId);
    
    return {'success': true};
  } catch (e) {
    debugPrint('Error deleting post: $e');
    return {'success': false, 'error': e.toString()};
  }
}

  /// Archive an expired post
  /// This moves it from 'active' to 'archived' status
  static Future<bool> archiveExpiredPost(String postId) async {
    try {
      // First check if the user is the owner of the post
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final post = await supabase
          .from('posts')
          .select()
          .eq('id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (post == null) {
        debugPrint('Post not found or user does not own this post');
        return false;
      }

      // Check if post is expired
      final expiresAt = post['expires_at'];
      if (expiresAt == null) return false;

      final expiryDate = DateTime.parse(expiresAt);
      final now = DateTime.now();

      if (expiryDate.isAfter(now)) {
        debugPrint('Post is not yet expired');
        return false;
      }

      // Update the post to archived status
      await supabase.from('posts').update({
        'status': 'archived',
        'archived_at': DateTime.now().toIso8601String(),
      }).eq('id', postId);

      return true;
    } catch (e) {
      debugPrint('Error archiving post: $e');
      return false;
    }
  }

  /// Move all expired posts to archive for a specific user
  static Future<int> archiveAllExpiredPosts() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return 0;

      final now = DateTime.now().toIso8601String();
      
      // Find all expired posts that are still active
      final expiredPosts = await supabase
          .from('posts')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'active')
          .lt('expires_at', now);

      if (expiredPosts.isEmpty) return 0;

      // Update all expired posts to archived status
      for (final post in expiredPosts) {
        await supabase.from('posts').update({
          'status': 'archived',
          'archived_at': now,
        }).eq('id', post['id']);
      }

      return expiredPosts.length;
    } catch (e) {
      debugPrint('Error archiving expired posts: $e');
      return 0;
    }
  }

  /// Check if a post has any active chat sessions
  static Future<bool> hasActiveChatSessions(String postId) async {
    try {
      final chatSessions = await supabase
          .from('chat_sessions')
          .select()
          .eq('post_id', postId)
          .eq('status', 'active');

      return chatSessions.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for active chat sessions: $e');
      return false;
    }
  }

   /// End all chat sessions related to a post
  static Future<void> _endRelatedChatSessions(String postId) async {
    try {
      // Get all chat sessions related to this post
      final chatSessions = await supabase
          .from('chat_sessions')
          .select('id')
          .eq('post_id', postId);

      // For each chat session, mark it as ended
      for (final session in chatSessions) {
        final sessionId = session['id'];
        
        // Add a system message about post deletion
        await supabase.from('messages').insert({
          'chat_session_id': sessionId,
          'content': 'This chat has been ended because the post was deleted by the creator.',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'is_system_message': true,
        });
        
        // End the chat session
        await supabase.from('chat_sessions').update({
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          'end_reason': 'post_deleted',
        }).eq('id', sessionId);
      }
    } catch (e) {
      debugPrint('Error ending related chat sessions: $e');
    }
  }

  /// Delete all chat sessions related to a post
  static Future<void> _deleteRelatedChatSessions(String postId) async {
    try {
      // Get all chat sessions related to this post
      final chatSessions = await supabase
          .from('chat_sessions')
          .select('id')
          .eq('post_id', postId);

      // For each chat session, delete related messages
      for (final session in chatSessions) {
        final sessionId = session['id'];
        
        // Delete messages linked to this chat session
        await supabase
            .from('messages')
            .delete()
            .eq('chat_session_id', sessionId);
      }

      // Delete the chat sessions
      await supabase
          .from('chat_sessions')
          .delete()
          .eq('post_id', postId);
    } catch (e) {
      debugPrint('Error deleting related chat sessions: $e');
    }
  }

  /// Show confirmation dialog for post deletion
  static Future<bool> showDeleteConfirmation(
    BuildContext context, {
    bool hasActiveSessions = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: Text(
          hasActiveSessions
              ? 'This post has active conversations. Deleting it will end all ongoing chats. Do you want to continue?'
              : 'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    ) ?? false;
  }
}