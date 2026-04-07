import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../di/locator.dart' as di;
import '../../services/enhanced_user_tier_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Pricing and Upgrade Screen
/// Displays subscription plans and handles upgrade/downgrade flow
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  EnhancedUserTierService? _tierService;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    try {
      _tierService = di.serviceLocator.get<EnhancedUserTierService>();
    } catch (e) {
      debugPrint('[Pricing] EnhancedUserTierService not available: $e');
    }
  }

  /// Get current tier
  String _getCurrentTier() {
    return _tierService?.currentTier.toString() ?? 'free';
  }

  /// Check if user can select a plan
  bool _canSelectPlan(String planId) {
    final current = _getCurrentTier();
    if (current == planId) return false; // Already on this plan
    return true;
  }

  /// Handle plan selection
  Future<void> _selectPlan(String planId) async {
    if (!_canSelectPlan(planId)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Navigate to checkout or show confirmation dialog
      _showUpgradeConfirmation(planId);
    } catch (e) {
      setState(() {
        _error = 'Failed to process selection: $e';
        _isLoading = false;
      });
    }
  }

  /// Show upgrade confirmation dialog
  void _showUpgradeConfirmation(String planId) {
    final plan = _getPlanDetails(planId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to ${plan['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ${plan['price']}'),
            const SizedBox(height: 16),
            ...List.generate(
              (plan['benefits'] as List).length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(plan['benefits'][index]),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Future enhancement: Integration with payment gateway
              _showComingSoonDialog();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Show coming soon dialog
  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text(
            'Online payment processing will be available soon. Please contact support to upgrade your subscription.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get plan details
  Map<String, dynamic> _getPlanDetails(String planId) {
    final plans = _getPlans();
    return plans.firstWhere((p) => p['id'] == planId);
  }

  /// Get all available plans
  List<Map<String, dynamic>> _getPlans() {
    return [
      {
        'id': 'free',
        'name': 'Free',
        'price': '\$0/month',
        'description': 'For users who want basic functionality',
        'color': Colors.grey,
        'icon': Icons.info,
        'benefits': [
          'Web platform access',
          'Local conversation storage',
          'Basic LLM chat functionality',
          'Manual data export/import',
        ],
        'current': _getCurrentTier() == 'free',
      },
      {
        'id': 'premium',
        'name': 'Premium',
        'price': '\$9.99/month',
        'description': 'For power users who need more features',
        'color': Colors.blue,
        'icon': Icons.star,
        'benefits': [
          'All platform access (web, desktop, mobile)',
          'Persistent always-on containers',
          'Priority connection handling',
          'Extended request queue (20 requests)',
          'Optional encrypted cloud sync',
          'Cross-device conversation sync',
          'Automated backup and restore',
        ],
        'current': _getCurrentTier() == 'premium',
      },
      {
        'id': 'enterprise',
        'name': 'Enterprise',
        'price': '\$29.99/month',
        'description': 'For teams and organizations',
        'color': Colors.purple,
        'icon': Icons.diamond,
        'benefits': [
          'Everything in Premium',
          'Dedicated support',
          'Custom integrations',
          'SLA guarantee',
          'Advanced analytics',
          'Team management',
          'API access',
        ],
        'current': _getCurrentTier() == 'enterprise',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plans = _getPlans();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Choose Your Plan',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select the plan that best fits your needs',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Current tier indicator
                  if (_getCurrentTier() != 'free')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Text(
                            'You are currently on the ${_getCurrentTier().capitalize()} plan',
                            style: TextStyle(color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Pricing cards
                  ...plans.map(_buildPricingCard),

                  // Error message
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> plan) {
    final isCurrent = plan['current'] as bool;
    final canSelect = _canSelectPlan(plan['id']);
    final color = plan['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrent ? Colors.green : color.withValues(alpha: 0.5),
          width: isCurrent ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isCurrent ? Colors.green.shade50 : Colors.white,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(plan['icon'] as IconData, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['name'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CURRENT PLAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      plan['price'] as String,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan['description'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),

          // Benefits
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...(plan['benefits'] as List).map((benefit) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            benefit as String,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Current Plan'),
                    )
                  : FilledButton(
                      onPressed: canSelect && !_isLoading
                          ? () => _selectPlan(plan['id'] as String)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _getCurrentTier() == 'free'
                            ? 'Upgrade to ${plan['name']}'
                            : plan['id'] == 'free'
                                ? 'Downgrade to ${plan['name']}'
                                : 'Switch to ${plan['name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
