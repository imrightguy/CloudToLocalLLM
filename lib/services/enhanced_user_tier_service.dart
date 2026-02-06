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
  final SharedPreferences _prefs;

  // Singleton instance
  static EnhancedUserTierService? _instance;
  static EnhancedUserTierService get instance {
    _instance ??= EnhancedUserTierService._internal();
    return _instance!;
  }

  factory EnhancedUserTierService() {
    return instance;
  }

  EnhancedUserTierService._internal()
      : _prefs = SharedPreferences.getInstance() {
    _loadTier();
  }

  /// Get current tier
  UserTier get currentTier => _currentTier;

  /// Get tier name for display
  String get tierName => _tierName;

  /// Load tier from storage
  Future<void> _loadTier() async {
    final tierString = _prefs.getString(_tierKey) ?? 'free';
    _currentTier = UserTier.values.firstWhere(
      (e) => e.name == tierString,
      orElse: () => UserTier.free,
    );
    _tierName = _prefs.getString(_tierNameKey) ?? 'Free';
    notifyListeners();
  }

  /// Update tier (call this when user upgrades/downgrades)
  Future<void> updateTier(UserTier tier, String name) async {
    _currentTier = tier;
    _tierName = name;
    await _prefs.setString(_tierKey, tier.name);
    await _prefs.setString(_tierNameKey, name);
    notifyListeners();
  }

  /// Check if user has premium features
  bool get isPremium => _currentTier != UserTier.free;

  /// Check if user has enterprise features
  bool get isEnterprise => _currentTier == UserTier.enterprise;
}
