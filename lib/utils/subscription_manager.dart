import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionManager {
  static final SubscriptionService _service = SubscriptionService();
  static final supabase = Supabase.instance.client;
  
  /// Check if user can create a new post
  static Future<bool> canCreatePost(BuildContext context) async {
    return await _checkFeatureLimit(
      context,
      LimitedFeature.posts,
      'You have reached your monthly post limit.',
    );
  }
  
  /// Check if user can create a new chat
  static Future<bool> canCreateChat(BuildContext context) async {
    return await _checkFeatureLimit(
      context,
      LimitedFeature.chatSessions,
      'You have reached your monthly chat session limit.',
    );
  }
  
  /// Helper method to check limits and show upgrade dialog if needed
  static Future<bool> _checkFeatureLimit(
    BuildContext context, 
    LimitedFeature feature,
    String limitMessage,
  ) async {
    final canUse = await _service.canUseFeature(feature);
    
    if (!canUse && context.mounted) {
      // Show dialog offering to upgrade
      final shouldUpgrade = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limit Reached'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(limitMessage),
              const SizedBox(height: 16),
              const Text(
                'Would you like to upgrade your subscription to get more?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('NOT NOW'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('UPGRADE'),
            ),
          ],
        ),
      ) ?? false;

      if (shouldUpgrade && context.mounted) {
        Navigator.pushNamed(context, '/premium');
      }
      
      return false;
    }
    
    return canUse;
  }
  
  /// Show premium features dialog
  static void showPremiumFeaturesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Features'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeatureItem('More monthly posts (up to unlimited)'),
            _buildFeatureItem('More monthly chat sessions (up to unlimited)'),
            _buildFeatureItem('Priority customer support'),
            _buildFeatureItem('Early access to new features'),
            _buildFeatureItem('Ad-free experience'),
            SizedBox(height: 16),
            Text(
              'Upgrade now to get more out of your experience!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('MAYBE LATER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/premium');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text('UPGRADE NOW'),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  /// Show premium upgrade banner
  static Widget buildPremiumBanner(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Get unlimited posts and chats',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Display remaining usage counts
  static Future<Widget> buildUsageSummary(BuildContext context) async {
    final stats = await _service.getUsageStats();
    final postsData = stats[LimitedFeature.posts];
    final chatsData = stats[LimitedFeature.chatSessions];
    
    if (postsData == null || chatsData == null) {
      return const SizedBox.shrink();
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Usage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/premium'),
                  child: Text(
                    'Upgrade',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildUsageMeter(
              context,
              'Posts',
              postsData['usage'] as int,
              postsData['limit'] as int,
              postsData['isUnlimited'] as bool,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildUsageMeter(
              context,
              'Chats',
              chatsData['usage'] as int,
              chatsData['limit'] as int,
              chatsData['isUnlimited'] as bool,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }
  
  static Widget _buildUsageMeter(
    BuildContext context,
    String label,
    int used,
    int limit,
    bool isUnlimited,
    Color color,
  ) {
    final double progress = isUnlimited ? 0.1 : used / (limit > 0 ? limit : 1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              isUnlimited
                  ? 'Unlimited'
                  : '$used / $limit',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isUnlimited
                    ? Colors.green
                    : used >= limit
                        ? Colors.red
                        : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress > 1 ? 1 : progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            isUnlimited ? Colors.green : used >= limit ? Colors.red : color,
          ),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
  
  /// Get current subscription tier
  static Future<SubscriptionTier> getCurrentTier() async {
    return await _service.getCurrentTier();
  }
  
  /// Update subscription tier
  static Future<bool> updateSubscription(SubscriptionTier tier) async {
    return await _service.updateSubscriptionTier(tier);
  }
}