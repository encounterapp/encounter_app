import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscription tiers with their respective limits
enum SubscriptionTier {
  free,
  tier1,
  tier2,
  tier3
}

/// Features that can be limited by subscription tiers
enum LimitedFeature {
  posts,
  chatSessions
}

/// Subscription service to manage subscription tiers, limits and usage tracking
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final supabase = Supabase.instance.client;
  
  // Maps tiers to their respective monthly limits
  static const Map<SubscriptionTier, Map<LimitedFeature, int>> _tierLimits = {
    SubscriptionTier.free: {
      LimitedFeature.posts: 20,
      LimitedFeature.chatSessions: 40,
    },
    SubscriptionTier.tier1: {
      LimitedFeature.posts: 75,
      LimitedFeature.chatSessions: 150,
    },
    SubscriptionTier.tier2: {
      LimitedFeature.posts: 150,
      LimitedFeature.chatSessions: 300,
    },
    SubscriptionTier.tier3: {
      LimitedFeature.posts: -1, // -1 means unlimited
      LimitedFeature.chatSessions: -1, // -1 means unlimited
    },
  };

  // Maps tiers to display names
  static const Map<SubscriptionTier, String> tierNames = {
    SubscriptionTier.free: 'Free',
    SubscriptionTier.tier1: 'Premium Tier 1',
    SubscriptionTier.tier2: 'Premium Tier 2',
    SubscriptionTier.tier3: 'Premium Tier 3',
  };

  // Maps tiers to prices (can be updated as needed)
  static const Map<SubscriptionTier, double> tierPrices = {
    SubscriptionTier.free: 0.0,
    SubscriptionTier.tier1: 6.99,
    SubscriptionTier.tier2: 13.99,
    SubscriptionTier.tier3: 29.99,
  };

  // Maps limited features to their display names
  static const Map<LimitedFeature, String> featureNames = {
    LimitedFeature.posts: 'Posts',
    LimitedFeature.chatSessions: 'Chat Sessions',
  };

  /// Get the current user's subscription tier
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return SubscriptionTier.free;
      }

      final response = await supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        return SubscriptionTier.free;
      }

      final String tierString = response['subscription_tier'] ?? 'free';
      return _stringToTier(tierString);
    } catch (e) {
      debugPrint('Error getting subscription tier: $e');
      return SubscriptionTier.free;
    }
  }

  /// Get the limit for a specific feature based on the user's tier
  Future<int> getFeatureLimit(LimitedFeature feature) async {
    final tier = await getCurrentTier();
    return _tierLimits[tier]?[feature] ?? 0;
  }

  /// Get the current usage for a specific feature
  Future<int> getCurrentUsage(LimitedFeature feature) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return 0;
      }

      // Get the current month and year
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Feature specific queries
      if (feature == LimitedFeature.posts) {
        // UPDATED: Include all posts created this month, regardless of current status
        // This includes active, archived, and deleted posts
        final response = await supabase
            .from('posts')
            .select('id')
            .eq('user_id', user.id)
            .gte('created_at', firstDayOfMonth.toIso8601String())
            .lte('created_at', lastDayOfMonth.toIso8601String());

        return response.length;
      } else if (feature == LimitedFeature.chatSessions) {
        final response = await supabase
            .from('chat_sessions')
            .select('id')
            .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
            .gte('created_at', firstDayOfMonth.toIso8601String())
            .lte('created_at', lastDayOfMonth.toIso8601String());

        return response.length;
      }

      return 0;
    } catch (e) {
      debugPrint('Error getting current usage: $e');
      return 0;
    }
  }

  /// Check if the user can use a feature (still has remaining usage)
  Future<bool> canUseFeature(LimitedFeature feature) async {
    final tier = await getCurrentTier();
    final limit = _tierLimits[tier]?[feature] ?? 0;
    
    // Unlimited usage for some tiers
    if (limit < 0) return true;
    
    final usage = await getCurrentUsage(feature);
    return usage < limit;
  }

  /// Increment the usage counter for a feature
  Future<bool> incrementUsage(LimitedFeature feature) async {
    // First check if the user can use this feature
    final canUse = await canUseFeature(feature);
    if (!canUse) return false;

    // If the user can use the feature, we don't need to do anything else
    // as the usage is tracked by actual database records
    return true;
  }

  /// Get the remaining usage for a feature
  Future<int> getRemainingUsage(LimitedFeature feature) async {
    final tier = await getCurrentTier();
    final limit = _tierLimits[tier]?[feature] ?? 0;
    
    // Unlimited usage
    if (limit < 0) return -1;
    
    final usage = await getCurrentUsage(feature);
    return limit - usage;
  }

  /// Update the user's subscription tier
  Future<bool> updateSubscriptionTier(SubscriptionTier tier) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final tierString = _tierToString(tier);
      
      // Check if user already has a subscription record
      final existingSubscription = await supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingSubscription == null) {
        // Create new subscription record
        await supabase.from('user_subscriptions').insert({
          'user_id': user.id,
          'subscription_tier': tierString,
          'subscription_start_date': DateTime.now().toIso8601String(),
          'subscription_end_date': _calculateEndDate().toIso8601String(),
        });
      } else {
        // Update existing subscription
        await supabase
            .from('user_subscriptions')
            .update({
              'subscription_tier': tierString,
              'subscription_start_date': DateTime.now().toIso8601String(),
              'subscription_end_date': _calculateEndDate().toIso8601String(),
            })
            .eq('user_id', user.id);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating subscription tier: $e');
      return false;
    }
  }

  /// Get usage statistics for all features
  Future<Map<LimitedFeature, Map<String, dynamic>>> getUsageStats() async {
    final result = <LimitedFeature, Map<String, dynamic>>{};
    
    for (final feature in LimitedFeature.values) {
      final limit = await getFeatureLimit(feature);
      final usage = await getCurrentUsage(feature);
      final remaining = limit < 0 ? -1 : limit - usage;
      
      result[feature] = {
        'limit': limit,
        'usage': usage,
        'remaining': remaining,
        'isUnlimited': limit < 0,
      };
    }
    
    return result;
  }

  /// Convert a tier to its string representation
  String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.tier1:
        return 'tier1';
      case SubscriptionTier.tier2:
        return 'tier2';
      case SubscriptionTier.tier3:
        return 'tier3';
      default:
        return 'free';
    }
  }

  /// Convert a string to its corresponding tier
  SubscriptionTier _stringToTier(String tierString) {
    switch (tierString.toLowerCase()) {
      case 'tier1':
        return SubscriptionTier.tier1;
      case 'tier2':
        return SubscriptionTier.tier2;
      case 'tier3':
        return SubscriptionTier.tier3;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Calculate the end date for a subscription (1 month from now)
  DateTime _calculateEndDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, now.day);
  }
}