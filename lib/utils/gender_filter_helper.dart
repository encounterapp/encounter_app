import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// A utility class to handle gender filtering with extensive debugging
class GenderFilterHelper {
  static const String EVERYONE = "Everyone";
  static const String MALES = "Males";
  static const String FEMALES = "Females";
  
  /// Filter posts based on the gender of the author with detailed logging
  static Future<List<Map<String, dynamic>>> filterPostsByGender(
    List<Map<String, dynamic>> posts, 
    String genderFilter,
    SupabaseClient supabase) async {
    
    debugPrint("\n==== GENDER FILTER DEBUG ====");
    debugPrint("Active filter: '$genderFilter'");
    debugPrint("Input posts count: ${posts.length}");
    
    // Always log the current user ID for reference
    final currentUserId = supabase.auth.currentUser?.id;
    debugPrint("Current user ID: $currentUserId");
    
    // If filter is set to "Everyone", return all posts
    if (genderFilter == EVERYONE) {
      debugPrint("Using 'Everyone' filter - no filtering applied");
      return posts;
    }
    
    final filteredPosts = <Map<String, dynamic>>[];
    final userGenders = <String, String?>{}; // Cache for user genders
    final List<String> includedPostIds = [];
    final List<String> excludedPostIds = [];
    final Map<String, String> filteringReasons = {};
    
    // First pass - collect all user genders to reduce database calls
    // Use fetch one by one instead of batch since 'in' operator might have issues
    final Set<String> uniqueUserIds = posts.map((post) => post['user_id'] as String).toSet();
    debugPrint("Unique users in posts: ${uniqueUserIds.length}");
    
    try {
      // Fetch profiles individually to avoid 'in' operator issues
      for (var userId in uniqueUserIds) {
        try {
          final profile = await supabase
              .from('profiles')
              .select('id, gender')
              .eq('id', userId)
              .maybeSingle();
              
          if (profile != null) {
            userGenders[profile['id']] = profile['gender'];
          }
        } catch (e) {
          debugPrint("Error fetching gender for user $userId: $e");
        }
      }
      
      debugPrint("Fetched ${userGenders.length}/${uniqueUserIds.length} user genders");
    } catch (e) {
      debugPrint("Error fetching user genders: $e");
    }
    
    // Second pass - process each post with the cached gender data
    for (final post in posts) {
      final userId = post['user_id'];
      final postId = post['id'] ?? 'unknown'; // For logging purposes
      
      // Skip if no user ID (shouldn't happen in normal operation)
      if (userId == null) {
        debugPrint("Skipping post $postId: No user ID");
        excludedPostIds.add(postId);
        filteringReasons[postId] = "No user ID";
        continue;
      }
      
      // Always include the current user's posts
      if (userId == currentUserId) {
        debugPrint("Including post $postId: Current user's post");
        filteredPosts.add(post);
        includedPostIds.add(postId);
        continue;
      }
      
      // Try to get gender from cache, if not found, fetch individually
      String? gender = userGenders[userId];
      if (gender == null) {
        try {
          debugPrint("Fetching missing gender for user $userId");
          final response = await supabase
              .from('profiles')
              .select('gender')
              .eq('id', userId)
              .maybeSingle();
          
          gender = response?['gender'];
          userGenders[userId] = gender; // Cache the result
        } catch (e) {
          debugPrint("Error fetching gender for user $userId: $e");
          excludedPostIds.add(postId);
          filteringReasons[postId] = "Error fetching gender";
          continue;
        }
      }
      
      // Log the raw gender value for debugging
      debugPrint("User $userId gender: '${gender ?? "null"}'");
      
      // Skip users with no gender
      if (gender == null || gender.trim().isEmpty) {
        debugPrint("Excluding post $postId: No gender specified");
        excludedPostIds.add(postId);
        filteringReasons[postId] = "No gender specified";
        continue;
      }
      
      // Normalize the gender value
      String normalizedGender = gender.trim().toLowerCase();
      debugPrint("Normalized gender: '$normalizedGender'");
      
      bool include = false;
      
      // Apply gender filtering
      if (genderFilter == MALES) {
        include = _matchMaleGender(normalizedGender);
        debugPrint("Male filter check for '$normalizedGender': $include");
      } else if (genderFilter == FEMALES) {
        include = _matchFemaleGender(normalizedGender);
        debugPrint("Female filter check for '$normalizedGender': $include");
      }
      
      if (include) {
        filteredPosts.add(post);
        includedPostIds.add(postId);
        debugPrint("✓ Including post $postId");
      } else {
        excludedPostIds.add(postId);
        filteringReasons[postId] = "Gender mismatch";
        debugPrint("✗ Excluding post $postId");
      }
    }
    
    // Summary of filtering
    debugPrint("\n==== FILTERING SUMMARY ====");
    debugPrint("Original posts: ${posts.length}");
    debugPrint("Filtered posts: ${filteredPosts.length}");
    debugPrint("Included posts: ${includedPostIds.length}");
    debugPrint("Excluded posts: ${excludedPostIds.length}");
    debugPrint("============================\n");
    
    return filteredPosts;
  }
  
  /// Try different approaches to match male gender
  static bool _matchMaleGender(String gender) {
    // Direct equality check
    if (gender == "male") return true;
    
    // Common variations
    if (gender == "m" || gender == "man" || gender == "boy") return true;
    
    // Contains "male" but not "female"
    if (gender.contains("male") && !gender.contains("female")) return true;
    
    // Contains specific male-indicating words
    final maleKeywords = ["man", "men", "boy", "masculine", "cis male", "trans male"];
    if (maleKeywords.any((keyword) => gender.contains(keyword))) return true;
    
    return false;
  }
  
  /// Try different approaches to match female gender
  static bool _matchFemaleGender(String gender) {
    // Direct equality check
    if (gender == "female") return true;
    
    // Common variations
    if (gender == "f" || gender == "woman" || gender == "girl") return true;
    
    // Contains "female"
    if (gender.contains("female")) return true;
    
    // Contains specific female-indicating words
    final femaleKeywords = ["woman", "women", "girl", "feminine", "cis female", "trans female"];
    if (femaleKeywords.any((keyword) => gender.contains(keyword))) return true;
    
    return false;
  }
  
  /// Validates a gender filter option
  static bool isValidGenderFilter(String filter) {
    return filter == EVERYONE || filter == MALES || filter == FEMALES;
  }
  
  /// Determines if a user with the given gender should be shown with the specified filter
  static bool shouldShowUserWithGender(String? userGender, String genderFilter) {
    // If filter is "Everyone", show all users
    if (genderFilter == EVERYONE) {
      return true;
    }
    
    // No gender, don't show in gender-specific filters
    if (userGender == null || userGender.trim().isEmpty) {
      return false;
    }
    
    // Normalize the gender string
    String normalizedGender = userGender.trim().toLowerCase();
    
    // For "Males" filter
    if (genderFilter == MALES) {
      return _matchMaleGender(normalizedGender);
    }
    
    // For "Females" filter
    if (genderFilter == FEMALES) {
      return _matchFemaleGender(normalizedGender);
    }
    
    // Default case
    return false;
  }
}