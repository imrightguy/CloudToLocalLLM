// Enhanced User Tier Service
// Integrates subscription tier management with app-wide state

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User subscription tiers
enum UserTier {
  free,
  premium,
  enterprise,
}

/// Service to manage and observe user subscription tier
class EnhancedUserTierService extends ChangeNotifier {
  static const String _tierKey = 'user_tier';
  static const String _tierNameKey = 'user_tier_name';

  UserTier _currentTier = UserTier.free;
  String _tierName = 'Free';

  bool _isInitialized = false;

  // Singleton instance
  static EnhancedUserTierService? _instance;
  static EnhancedUserTierService get instance {
    _instance ??= EnhancedUserTierService._internal();
    return _instance!;
  }

  factory EnhancedUserTierService() {
    return instance;
  }

  EnhancedUserTierService._internal() {
    // Don't initialize in constructor - prefs must be loaded asynchronously
  }

  /// Get current tier
  UserTier get currentTier => _currentTier;

  /// Get tier name for display
  String get tierName => _tierName;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Load tier from storage
  Future<void> _loadTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierString = prefs.getString(_tierKey) ?? 'free';
      _currentTier = UserTier.values.firstWhere(
        (e) => e.name == tierString,
        orElse: () => UserTier.free,
      );
      _tierName = prefs.getString(_tierNameKey) ?? 'Free';
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tier: $e');
    }
  }

  /// Update tier (call this when user upgrades/downgrades)
  Future<void> updateTier(UserTier tier, String name) async {
    _currentTier = tier;
    _tierName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier.name);
    await prefs.setString(_tierNameKey, name);
    notifyListeners();
  }

  /// Check if user has premium features
  bool get isPremium => _currentTier != UserTier.free;

  /// Alias for isPremium for compatibility
  bool get isPremiumTier => isPremium;

  /// Check if user has enterprise features
  bool get isEnterprise => _currentTier == UserTier.enterprise;

  List<String> get tierBenefits {
    switch (_currentTier) {
      case UserTier.enterprise:
        return [
          'Unlimited local models',
          'Priority cloud routing',
          'Advanced analytics',
          'Multi-user support',
          'Custom LLM configurations'
        ];
      case UserTier.premium:
        return [
          'Unlimited local models',
          'Priority cloud routing',
          'Standard analytics'
        ];
      case UserTier.free:
        return ['Standard local models', 'Cloud routing'];
    }
  }

  List<String> get tierLimitations {
    switch (_currentTier) {
      case UserTier.enterprise:
      case UserTier.premium:
        return [];
      case UserTier.free:
        return ['Limited to 3 concurrent models', 'No advanced analytics'];
    }
  }

  Future<void> initialize() async {
    await _loadTier();
  }
}
