import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A utility class to manage post operations like deletion and archiving
class PostManager {
  static final supabase = Supabase.instance.client;

  /// Delete a post by its ID
  /// Returns true if deletion was successful
  static Future<bool> deletePost(String postId) async {
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

      // Delete any related chat sessions
      await _deleteRelatedChatSessions(postId);

      // Now delete the post
      await supabase.from('posts').delete().eq('id', postId);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
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