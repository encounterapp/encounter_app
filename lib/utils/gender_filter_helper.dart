import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// A utility class to handle gender filtering related functions
class GenderFilterHelper {
  static const String EVERYONE = "Everyone";
  static const String MALES = "Males";
  static const String FEMALES = "Females";
  
  /// Filter posts based on the gender of the author
  /// 
  /// This method fetches the profile of each post's author and checks if their
  /// gender matches the filter criteria. Posts from users with "None" or "Other"
  /// gender will only be shown when the filter is set to "Everyone".
  static Future<List<Map<String, dynamic>>> filterPostsByGender(
    List<Map<String, dynamic>> posts, 
    String genderFilter,
    SupabaseClient supabase) async {
    
    debugPrint("Filtering ${posts.length} posts with gender filter: $genderFilter");
    
    // If filter is set to "Everyone", return all posts
    if (genderFilter == EVERYONE) {
      return posts;
    }
    
    final filteredPosts = <Map<String, dynamic>>[];
    final userGenders = <String, String?>{}; // Cache for user genders
    
    for (final post in posts) {
      final userId = post['user_id'];
      
      // Skip if no user ID (shouldn't happen in normal operation)
      if (userId == null) continue;
      
      // Check if the current user's ID matches the post author
      final currentUserId = supabase.auth.currentUser?.id;
      if (userId == currentUserId) {
        // Always include the current user's posts
        filteredPosts.add(post);
        continue;
      }
      
      // Get the gender from cache or fetch from database
      String? gender;
      if (userGenders.containsKey(userId)) {
        gender = userGenders[userId];
      } else {
        try {
          final response = await supabase
              .from('profiles')
              .select('gender')
              .eq('id', userId)
              .maybeSingle();
          
          gender = response?['gender'];
          userGenders[userId] = gender; // Cache the result
          debugPrint("Fetched gender for user $userId: ${gender ?? 'null'}");
        } catch (e) {
          debugPrint("Error fetching user gender: $e");
          // Skip this post on error
          continue;
        }
      }
      
      // Skip users with no gender
      if (gender == null) continue;
      
      // Apply gender filtering with case-insensitive comparison:
      // - If filter is "Males", only show posts from users with gender that matches "male" (case-insensitive)
      // - If filter is "Females", only show posts from users with gender that matches "female" (case-insensitive)
      // - Users with other gender values only show up with "Everyone" filter
      if ((genderFilter == MALES && gender.toLowerCase() == "male") ||
          (genderFilter == FEMALES && gender.toLowerCase() == "female")) {
        filteredPosts.add(post);
      }
    }
    
    debugPrint("Gender filtering: ${posts.length} posts → ${filteredPosts.length} posts");
    return filteredPosts;
  }
  
  /// Validates a gender filter option
  /// 
  /// Returns true if the gender filter is one of the valid options
  static bool isValidGenderFilter(String filter) {
    return filter == EVERYONE || filter == MALES || filter == FEMALES;
  }
  
  /// Determines if a user with the given gender should be shown with the specified filter
  /// 
  /// This method can be used to check if a user should be visible with the current
  /// gender filter before attempting to load their posts.
  static bool shouldShowUserWithGender(String? userGender, String genderFilter) {
    // If filter is "Everyone", show all users
    if (genderFilter == EVERYONE) {
      return true;
    }
    
    // No gender, don't show in gender-specific filters
    if (userGender == null) {
      return false;
    }
    
    // For "Males" filter, only show male users (case-insensitive)
    if (genderFilter == MALES) {
      return userGender.toLowerCase() == "male";
    }
    
    // For "Females" filter, only show female users (case-insensitive) 
    if (genderFilter == FEMALES) {
      return userGender.toLowerCase() == "female";
    }
    
    // Default case (should not happen with valid filters)
    return false;
  }
}