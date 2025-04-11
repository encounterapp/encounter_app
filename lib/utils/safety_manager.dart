import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A utility class to manage user safety features like reporting and blocking
class SafetyManager {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if a user is blocked
  static Future<bool> isUserBlocked(String userId1, String userId2) async {
    try {
      // Check if either user has blocked the other
      final response = await _supabase
          .rpc('is_user_blocked', params: {
            'user1_id': userId1,
            'user2_id': userId2,
          });
      
      return response as bool;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false; // Default to false on error
    }
  }

  /// Block a user
  static Future<bool> blockUser(String blockedUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUser.id,
        'blocked_id': blockedUserId,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  static Future<bool> unblockUser(String blockedUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', blockedUserId);
      
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  /// Report a user
  static Future<bool> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
    String? chatSessionId,
    String? postId,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      // Create a unique report ID based on timestamp
      final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create report record
      final Map<String, dynamic> reportData = {
        'id': reportId,
        'reporter_id': currentUser.id,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'details': details,
        'status': 'pending',
      };
      
      // Add optional fields if provided
      if (chatSessionId != null) {
        reportData['chat_session_id'] = chatSessionId;
      }
      
      // Only add post_id if it's provided and valid
      // Note: postId is expected to be a UUID string
      if (postId != null && postId.isNotEmpty) {
        try {
          // Basic validation for UUID format (not foolproof but helps catch obvious issues)
          if (postId.length >= 36 && postId.contains('-')) {
            reportData['post_id'] = postId;
          } else {
            debugPrint('Invalid post ID format, not including in report');
          }
        } catch (e) {
          debugPrint('Error validating post ID: $e');
        }
      }
      
      await _supabase.from('user_reports').insert(reportData);
      
      return true;
    } catch (e) {
      debugPrint('Error reporting user: $e');
      return false;
    }
  }

  /// Get a list of blocked users
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id, created_at, profiles:blocked_id(username, avatar_url)')
          .eq('blocker_id', currentUser.id);
      
      return response;
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  /// Get a list of reports submitted by the current user
  static Future<List<Map<String, dynamic>>> getMyReports() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase
          .from('user_reports')
          .select('*, reported_profiles:reported_user_id(username, avatar_url)')
          .eq('reporter_id', currentUser.id)
          .order('created_at', ascending: false);
      
      return response;
    } catch (e) {
      debugPrint('Error getting user reports: $e');
      return [];
    }
  }
  
  /// Check if a user has been reported recently
  static Future<bool> hasReportedRecently(String reportedUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      // Check if there's a report in the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      
      final reports = await _supabase
          .from('user_reports')
          .select()
          .eq('reporter_id', currentUser.id)
          .eq('reported_user_id', reportedUserId)
          .gte('created_at', sevenDaysAgo);
          
      return reports.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking recent reports: $e');
      return false; // Allow reporting on error to ensure safety
    }
  }
  
  /// Filter posts to exclude blocked users
  static Future<List<Map<String, dynamic>>> filterPostsWithBlocks(List<Map<String, dynamic>> posts) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return posts;
      
      // Get all blocked users
      final blockedUsers = await getBlockedUsers();
      final blockedIds = blockedUsers.map((user) => user['blocked_id'] as String).toList();
      
      // Filter out posts from blocked users
      return posts.where((post) => !blockedIds.contains(post['user_id'])).toList();
    } catch (e) {
      debugPrint('Error filtering posts: $e');
      return posts; // Return original posts on error
    }
  }
}