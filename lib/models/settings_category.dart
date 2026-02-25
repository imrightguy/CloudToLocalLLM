/// Settings Category Models
///
/// Defines the structure for settings categories and their visibility rules.
library;

import 'package:flutter/material.dart';

/// Represents a settings category with metadata and visibility rules
abstract class SettingsCategory {
  /// Unique identifier for the category
  String get id;

  /// Display title for the category
  String get title;

  /// Icon to display in the category list
  IconData get icon;

  /// Whether this category should be visible in the current context
  bool get isVisible;

  /// Priority for ordering categories (lower numbers appear first)
  int get priority;

  /// Description of what this category contains
  String get description;

  /// Whether this category requires admin privileges
  bool get requiresAdmin;

  /// Get the widget builder for this category's content
  WidgetBuilder get contentBuilder;
}

/// Base implementation of SettingsCategory
class BaseSettingsCategory implements SettingsCategory {
  @override
  final String id;

  @override
  final String title;

  @override
  final IconData icon;

  @override
  final bool isVisible;

  @override
  final int priority;

  @override
  final String description;

  @override
  final bool requiresAdmin;

  @override
  final WidgetBuilder contentBuilder;

  const BaseSettingsCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.isVisible,
    required this.contentBuilder,
    this.priority = 0,
    this.description = '',
    this.requiresAdmin = false,
  });

  /// Create a copy with updated values
  BaseSettingsCategory copyWith({
    String? id,
    String? title,
    IconData? icon,
    bool? isVisible,
    int? priority,
    String? description,
    bool? requiresAdmin,
    WidgetBuilder? contentBuilder,
  }) {
    return BaseSettingsCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      isVisible: isVisible ?? this.isVisible,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      requiresAdmin: requiresAdmin ?? this.requiresAdmin,
      contentBuilder: contentBuilder ?? this.contentBuilder,
    );
  }
}

/// Predefined category IDs
class SettingsCategoryIds {
  static const String general = 'general';
  static const String localLLMProviders = 'local_llm_providers';
  static const String account = 'account';
  static const String privacy = 'privacy';
  static const String desktop = 'desktop';
  static const String mobile = 'mobile';
  static const String importExport = 'import_export';
  static const String premiumFeatures = 'premium_features';
  static const String openClawGateway = 'openclaw_gateway';
  static const String adminCenter = 'admin_center';
  static const String about = 'about';
  static const String agentStatus = 'agent_status';
  static const String avatar = 'avatar';
}

/// Settings category visibility rules based on platform and user role
class CategoryVisibilityRules {
  /// Check if a category should be visible on the current platform
  static bool isVisibleOnPlatform(
    String categoryId, {
    required bool isWeb,
    required bool isWindows,
    required bool isLinux,
    required bool isAndroid,
    required bool isIOS,
  }) {
    switch (categoryId) {
      case SettingsCategoryIds.general:
      case SettingsCategoryIds.openClawGateway:
      case SettingsCategoryIds.account:
      case SettingsCategoryIds.privacy:
      case SettingsCategoryIds.importExport:
      case SettingsCategoryIds.about:
        // Always visible on all platforms
        return true;

      case SettingsCategoryIds.localLLMProviders:
        // Disabled - using OpenClaw Gateway only, no local LLM providers
        return false;

      case SettingsCategoryIds.desktop:
        // Only visible on desktop platforms
        return isWindows || isLinux;

      case SettingsCategoryIds.mobile:
        // Only visible on mobile platforms
        return isAndroid || isIOS;

      case SettingsCategoryIds.premiumFeatures:
      case SettingsCategoryIds.adminCenter:
        // Visibility determined by user role, not platform
        return true;

      default:
        return false;
    }
  }

  /// Check if a category should be visible based on user role
  static bool isVisibleForUserRole({
    required String categoryId,
    required bool isAdminUser,
    required bool isPremiumUser,
  }) {
    switch (categoryId) {
      case SettingsCategoryIds.adminCenter:
        // Only show Admin Center for admin users
        return isAdminUser;

      case SettingsCategoryIds.premiumFeatures:
        // Only show Premium Features for premium users
        return isPremiumUser;

      default:
        // All other categories are visible to all users
        return true;
    }
  }
}

/// Settings category metadata for sorting and organization
class SettingsCategoryMetadata {
  /// Standard category priorities (lower = appears first)
  static const int priorityGeneral = 0;
  static const int priorityLocalLLM = 10;
  static const int priorityAccount = 20;
  static const int priorityPrivacy = 30;
  static const int priorityDesktop = 40;
  static const int priorityMobile = 50;
  static const int priorityImportExport = 55;
  static const int priorityPremium = 60;
  static const int priorityAdmin = 100;

  /// Get the priority for a category ID
  static int getPriority(String categoryId) {
    switch (categoryId) {
      case SettingsCategoryIds.general:
        return priorityGeneral;
      case SettingsCategoryIds.localLLMProviders:
        return priorityLocalLLM;
      case SettingsCategoryIds.openClawGateway:
        return 15;
      case SettingsCategoryIds.account:
        return priorityAccount;
      case SettingsCategoryIds.privacy:
        return priorityPrivacy;
      case SettingsCategoryIds.desktop:
        return priorityDesktop;
      case SettingsCategoryIds.mobile:
        return priorityMobile;
      case SettingsCategoryIds.importExport:
        return priorityImportExport;
      case SettingsCategoryIds.premiumFeatures:
        return priorityPremium;
      case SettingsCategoryIds.adminCenter:
        return priorityAdmin;
      case SettingsCategoryIds.about:
        return 100; // Show at the bottom
      case SettingsCategoryIds.agentStatus:
        return 5; // Show near the top
      case SettingsCategoryIds.avatar:
        return 10; // Show after Agent Status
      default:
        return 999;
    }
  }

  /// Get the icon for a category ID
  static IconData getIcon(String categoryId) {
    switch (categoryId) {
      case SettingsCategoryIds.general:
        return Icons.tune;
      case SettingsCategoryIds.localLLMProviders:
        return Icons.storage;
      case SettingsCategoryIds.openClawGateway:
        return Icons.hub;
      case SettingsCategoryIds.account:
        return Icons.person;
      case SettingsCategoryIds.privacy:
        return Icons.privacy_tip;
      case SettingsCategoryIds.desktop:
        return Icons.desktop_mac;
      case SettingsCategoryIds.mobile:
        return Icons.phone_android;
      case SettingsCategoryIds.importExport:
        return Icons.import_export;
      case SettingsCategoryIds.premiumFeatures:
        return Icons.star;
      case SettingsCategoryIds.adminCenter:
        return Icons.admin_panel_settings;
      case SettingsCategoryIds.about:
        return Icons.info_outline;
      case SettingsCategoryIds.agentStatus:
        return Icons.smart_toy;
      case SettingsCategoryIds.avatar:
        return Icons.psychology;
      default:
        return Icons.settings;
    }
  }

  /// Get the title for a category ID
  static String getTitle(String categoryId) {
    switch (categoryId) {
      case SettingsCategoryIds.general:
        return 'General';
      case SettingsCategoryIds.localLLMProviders:
        return 'Local LLM Providers';
      case SettingsCategoryIds.openClawGateway:
        return 'OpenClaw Gateway';
      case SettingsCategoryIds.account:
        return 'Account';
      case SettingsCategoryIds.privacy:
        return 'Privacy';
      case SettingsCategoryIds.desktop:
        return 'Desktop';
      case SettingsCategoryIds.mobile:
        return 'Mobile';
      case SettingsCategoryIds.importExport:
        return 'Import/Export';
      case SettingsCategoryIds.premiumFeatures:
        return 'Premium Features';
      case SettingsCategoryIds.adminCenter:
        return 'Admin Center';
      case SettingsCategoryIds.about:
        return 'About';
      case SettingsCategoryIds.agentStatus:
        return 'Agent Status';
      case SettingsCategoryIds.avatar:
        return 'Avatar';
      default:
        return 'Settings';
    }
  }

  /// Get the description for a category ID
  static String getDescription(String categoryId) {
    switch (categoryId) {
      case SettingsCategoryIds.general:
        return 'Theme, language, and general preferences';
      case SettingsCategoryIds.localLLMProviders:
        return 'Configure local AI model providers';
      case SettingsCategoryIds.openClawGateway:
        return 'Configure the primary AI engine connection';
      case SettingsCategoryIds.account:
        return 'Account information and subscription';
      case SettingsCategoryIds.privacy:
        return 'Privacy and data collection settings';
      case SettingsCategoryIds.desktop:
        return 'Desktop application settings';
      case SettingsCategoryIds.mobile:
        return 'Mobile application settings';
      case SettingsCategoryIds.importExport:
        return 'Import and export your settings';
      case SettingsCategoryIds.premiumFeatures:
        return 'Premium features and upgrades';
      case SettingsCategoryIds.adminCenter:
        return 'Administration and user management';
      case SettingsCategoryIds.about:
        return 'Version information and system details';
      case SettingsCategoryIds.agentStatus:
        return 'View agent status and activity';
      case SettingsCategoryIds.avatar:
        return 'Customize your avatar personality and evolution';
      default:
        return '';
    }
  }
}
