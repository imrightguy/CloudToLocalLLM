import 'package:flutter/material.dart';
import '../../services/enhanced_user_tier_service.dart';

class AccountSettingsCategory extends StatefulWidget {
  const AccountSettingsCategory({Key? key}) : super(key: key);

  @override
  State<AccountSettingsCategory> createState() => _AccountSettingsCategoryState();
}

class _AccountSettingsCategoryState extends State<AccountSettingsCategory> {
  final _tierService = EnhancedUserTierService.instance;

  @override
  void initState() {
    super.initState();
    // Listen to tier changes
    _tierService.addListener(_onTierChanged);
  }

  @override
  void dispose() {
    _tierService.removeListener(_onTierChanged);
    super.dispose();
  }

  void _onTierChanged() {
    setState(() {}); // Rebuild on tier change
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // Current Tier Display
        Card(
          child: ListTile(
            leading: _getTierIcon(),
            title: Text(_tierService.tierName),
            subtitle: Text(_getTierDescription()),
            trailing: _tierService.isPremium
                ? const Icon(Icons.verified, color: Colors.amber)
                : const Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),

        // Upgrade Button (only for free tier)
        if (_tierService.currentTier == UserTier.free)
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to upgrade page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upgrade page coming soon')),
              );
            },
            icon: const Icon(Icons.star),
            label: const Text('Upgrade to Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),

        // Admin Status Check
        const SizedBox(height: 24),
        _buildAdminStatus(),
      ],
    );
  }

  Widget _getTierIcon() {
    switch (_tierService.currentTier) {
      case UserTier.premium:
        return const Icon(Icons.workspace_premium, color: Colors.amber);
      case UserTier.enterprise:
        return const Icon(Icons.business, color: Colors.blue);
      default:
        return const Icon(Icons.person_outline);
    }
  }

  String _getTierDescription() {
    switch (_tierService.currentTier) {
      case UserTier.premium:
        return 'Premium features unlocked';
      case UserTier.enterprise:
        return 'Full enterprise access';
      default:
        return 'Basic features included';
    }
  }

  Widget _buildAdminStatus() {
    // TODO: Check actual admin status from AuthService/AdminService
    // For now, use hardcoded status
    final isAdmin = false;

    return Card(
      child: ListTile(
        leading: Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.person,
          color: isAdmin ? Colors.red : Colors.grey,
        ),
        title: Text(isAdmin ? 'Admin Access' : 'User'),
        subtitle: Text(isAdmin ? 'You have admin privileges' : 'Standard user account'),
        trailing: isAdmin
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
      ),
    );
  }
}
