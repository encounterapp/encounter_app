import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/subscription_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({Key? key}) : super(key: key);

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionTier _currentTier = SubscriptionTier.free;
  Map<LimitedFeature, Map<String, dynamic>> _usageStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tier = await _subscriptionService.getCurrentTier();
      final usageStats = await _subscriptionService.getUsageStats();

      if (mounted) {
        setState(() {
          _currentTier = tier;
          _usageStats = usageStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _upgradeSubscription(SubscriptionTier tier) async {
    // This is where you would implement actual payment processing
    // For this example, we're just updating the tier directly
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Show a confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upgrade to ${SubscriptionService.tierNames[tier]}?'),
          content: Text(
            'You will be charged \$${SubscriptionService.tierPrices[tier]?.toStringAsFixed(2)} per month. '
            'Would you like to proceed?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('UPGRADE'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // In a real app, you would process payment here

      // Update the subscription in the database
      final success = await _subscriptionService.updateSubscriptionTier(tier);

      if (success) {
        // Reload the user data
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully upgraded to ${SubscriptionService.tierNames[tier]}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upgrade subscription. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error upgrading subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Membership'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current subscription info
                  _buildCurrentSubscriptionCard(),
                  
                  // Usage statistics
                  _buildUsageStatisticsCard(),
                  
                  // Premium tiers
                  _buildTierCard(
                    SubscriptionTier.free,
                    'Free',
                    0.0,
                    [
                      '20 posts per month',
                      '40 new chat sessions per month',
                      'Basic features',
                    ],
                    isPrimary: _currentTier == SubscriptionTier.free,
                  ),
                  _buildTierCard(
                    SubscriptionTier.tier1,
                    'Premium Tier 1',
                    6.99,
                    [
                      '75 posts per month',
                      '150 new chat sessions per month',
                      'All basic features',
                    ],
                    isPrimary: _currentTier == SubscriptionTier.tier1,
                  ),
                  _buildTierCard(
                    SubscriptionTier.tier2,
                    'Premium Tier 2',
                    13.99,
                    [
                      '150 posts per month',
                      '300 new chat sessions per month',
                      'All basic features',
                      'Priority customer support',
                    ],
                    isPrimary: _currentTier == SubscriptionTier.tier2,
                  ),
                  _buildTierCard(
                    SubscriptionTier.tier3,
                    'Premium Tier 3',
                    29.99,
                    [
                      'Unlimited posts',
                      'Unlimited new chat sessions',
                      'All premium features',
                      'Priority customer support',
                      'Early access to new features',
                    ],
                    isPrimary: _currentTier == SubscriptionTier.tier3,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: _currentTier == SubscriptionTier.free
                      ? Colors.grey
                      : Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Plan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        SubscriptionService.tierNames[_currentTier] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentTier != SubscriptionTier.free)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getSubscriptionDescription(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            if (_currentTier != SubscriptionTier.tier3) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => _showUpgradeOptions(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Upgrade Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSubscriptionDescription() {
    switch (_currentTier) {
      case SubscriptionTier.free:
        return 'You are on the Free plan. Upgrade to a premium tier to enjoy more features and increased limits.';
      case SubscriptionTier.tier1:
        return 'You are on the Premium Tier 1 plan with increased posting and chat session limits.';
      case SubscriptionTier.tier2:
        return 'You are on the Premium Tier 2 plan with high posting and chat session limits plus priority support.';
      case SubscriptionTier.tier3:
        return 'You are on the Premium Tier 3 plan with unlimited posting and chat sessions, plus all premium features.';
      default:
        return 'Unknown subscription tier.';
    }
  }

  void _showUpgradeOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upgrade Your Plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose a premium tier to increase your monthly limits:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (_currentTier.index < SubscriptionTier.tier1.index)
              _buildUpgradeOption(
                context,
                SubscriptionTier.tier1,
                'Premium Tier 1',
                4.99,
                '75 posts, 150 chat sessions',
              ),
            if (_currentTier.index < SubscriptionTier.tier2.index)
              _buildUpgradeOption(
                context,
                SubscriptionTier.tier2,
                'Premium Tier 2',
                9.99,
                '150 posts, 300 chat sessions',
              ),
            if (_currentTier.index < SubscriptionTier.tier3.index)
              _buildUpgradeOption(
                context,
                SubscriptionTier.tier3,
                'Premium Tier 3',
                19.99,
                'Unlimited posts & chat sessions',
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeOption(
    BuildContext context,
    SubscriptionTier tier,
    String name,
    double price,
    String features,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _upgradeSubscription(tier);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${price.toStringAsFixed(2)}/month',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      features,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageStatisticsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildUsageItem(
              LimitedFeature.posts,
              'Posts',
              Icons.post_add,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildUsageItem(
              LimitedFeature.chatSessions,
              'Chat Sessions',
              Icons.chat,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem(
    LimitedFeature feature,
    String name,
    IconData icon,
    Color color,
  ) {
    final stats = _usageStats[feature];
    if (stats == null) return const SizedBox.shrink();

    final usage = stats['usage'] as int;
    final limit = stats['limit'] as int;
    final isUnlimited = stats['isUnlimited'] as bool;
    
    // Calculate progress
    double progress = isUnlimited ? 0.1 : usage / (limit > 0 ? limit : 1);
    if (progress > 1) progress = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              isUnlimited
                  ? '$usage / Unlimited'
                  : '$usage / $limit',
              style: TextStyle(
                fontSize: 14,
                color: usage >= limit && !isUnlimited
                    ? Colors.red
                    : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            isUnlimited
                ? Colors.green
                : usage >= limit
                    ? Colors.red
                    : color,
          ),
          minHeight: 5,
          borderRadius: BorderRadius.circular(2.5),
        ),
        const SizedBox(height: 4),
        Text(
          isUnlimited
              ? 'Unlimited usage available'
              : usage >= limit
                  ? 'Limit reached'
                  : '${limit - usage} remaining this month',
          style: TextStyle(
            fontSize: 12,
            color: isUnlimited
                ? Colors.green
                : usage >= limit
                    ? Colors.red
                    : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard(
    SubscriptionTier tier,
    String name,
    double price,
    List<String> features, {
    bool isPrimary = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPrimary
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPrimary ? Icons.star : Icons.star_border,
                  color: isPrimary ? Colors.amber : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$${price.toStringAsFixed(2)}/month',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            if (!isPrimary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _upgradeSubscription(tier),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Upgrade to ${name.split(' ').last}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}