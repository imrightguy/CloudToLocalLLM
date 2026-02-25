import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/platform_category_filter.dart';
import '../services/admin_center_service.dart';
import '../services/enhanced_user_tier_service.dart';
import '../services/theme_provider.dart';
import '../services/platform_adapter.dart';

import '../models/settings_category.dart';
import '../widgets/settings/settings_category_list.dart';
import '../widgets/settings/general_settings_category.dart';
import '../widgets/settings/agent_status_settings_category.dart';
import '../widgets/settings/avatar_settings_category.dart';
import '../widgets/settings/import_export_settings_category.dart';
import '../widgets/settings/account_settings_category.dart';
import '../widgets/settings/privacy_settings_category.dart';
import '../widgets/settings/desktop_settings_category.dart';
import '../widgets/settings/mobile_settings_category.dart';
import '../widgets/settings/admin_settings_category.dart';
import '../widgets/settings/premium_settings_category.dart';
import '../widgets/settings/about_settings_category.dart';
import '../widgets/settings/openclaw_gateway_category.dart';
import '../utils/responsive_layout.dart';
import '../di/locator.dart' as di;
import 'package:go_router/go_router.dart';

/// Main unified settings screen that orchestrates the settings experience
/// across all platforms (web, Windows, Linux, mobile).
class UnifiedSettingsScreen extends StatefulWidget {
  /// Optional initial category to display
  final String? initialCategory;

  const UnifiedSettingsScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  late PlatformCategoryFilter _platformFilter;
  late AuthService _authService;
  late PlatformAdapter _platformAdapter;

  AdminCenterService? _adminCenterService;
  EnhancedUserTierService? _tierService;

  // State management
  late String _activeCategory;
  String _searchQuery = '';
  List<BaseSettingsCategory> _visibleCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _activeCategory = widget.initialCategory ?? SettingsCategoryIds.general;
  }

  /// Initialize required services
  void _initializeServices() {
    try {
      _authService = di.serviceLocator.get<AuthService>();

      _platformAdapter = di.serviceLocator.get<PlatformAdapter>();

      // Try to get AdminCenterService if available
      try {
        _adminCenterService = di.serviceLocator.get<AdminCenterService>();
      } catch (e) {
        debugPrint(
          '[UnifiedSettingsScreen] AdminCenterService not available: $e',
        );
      }

      // Try to get EnhancedUserTierService if available
      try {
        _tierService = di.serviceLocator.get<EnhancedUserTierService>();
      } catch (e) {
        debugPrint(
          '[UnifiedSettingsScreen] EnhancedUserTierService not available: $e',
        );
      }

      // Create platform filter with services
      _platformFilter = PlatformCategoryFilter(
        authService: _authService,
        adminCenterService: _adminCenterService,
        tierService: _tierService,
      );

      // Load visible categories
      _loadVisibleCategories();
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error initializing services: $e');
      setState(() {
        _errorMessage = 'Failed to initialize settings: $e';
        _isLoading = false;
      });
    }
  }

  /// Load visible categories based on platform and user role
  Future<void> _loadVisibleCategories() async {
    try {
      final allCategories = _buildAllCategories();
      debugPrint(
          '[UnifiedSettingsScreen] Built ${allCategories.length} categories');

      final visibleCategories =
          await _platformFilter.getVisibleCategories(allCategories);

      debugPrint(
          '[UnifiedSettingsScreen] Filtered to ${visibleCategories.length} visible categories');
      for (final cat in visibleCategories) {
        debugPrint('[UnifiedSettingsScreen] Visible category: ${cat.id}');
      }

      if (mounted) {
        setState(() {
          _visibleCategories = visibleCategories;
          _isLoading = false;

          // Validate that active category is still visible
          if (!_visibleCategories.any((c) => c.id == _activeCategory)) {
            _activeCategory = _visibleCategories.isNotEmpty
                ? _visibleCategories.first.id
                : SettingsCategoryIds.general;
          }
          debugPrint(
              '[UnifiedSettingsScreen] Active category set to: $_activeCategory');
        });
      }
    } catch (e) {
      debugPrint('[UnifiedSettingsScreen] Error loading categories: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load settings categories: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Build all available settings categories
  List<BaseSettingsCategory> _buildAllCategories() {
    return [
      BaseSettingsCategory(
        id: SettingsCategoryIds.general,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.general),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.general),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.general,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.general,
        ),
        isVisible: true,
        contentBuilder: (context) => GeneralSettingsCategory(
          categoryId: SettingsCategoryIds.general,
          isActive: _activeCategory == SettingsCategoryIds.general,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.agentStatus,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.agentStatus,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.agentStatus,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.agentStatus,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.agentStatus,
        ),
        isVisible: true,
        contentBuilder: (context) => AgentStatusSettingsCategory(
          categoryId: SettingsCategoryIds.agentStatus,
          isActive: _activeCategory == SettingsCategoryIds.agentStatus,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.avatar,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.avatar,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.avatar,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.avatar,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.avatar,
        ),
        isVisible: true,
        contentBuilder: (context) => AvatarSettingsCategory(
          categoryId: SettingsCategoryIds.avatar,
          isActive: _activeCategory == SettingsCategoryIds.avatar,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.openClawGateway,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.openClawGateway,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.openClawGateway,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.openClawGateway,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.openClawGateway,
        ),
        isVisible: true,
        contentBuilder: (context) => const OpenClawGatewayCategory(
          categoryId: SettingsCategoryIds.openClawGateway,
          isActive: true,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.account,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.account),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.account),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.account,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.account,
        ),
        isVisible: true,
        contentBuilder: (context) => AccountSettingsCategory(
          categoryId: SettingsCategoryIds.account,
          isActive: _activeCategory == SettingsCategoryIds.account,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.privacy,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.privacy),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.privacy),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.privacy,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.privacy,
        ),
        isVisible: true,
        contentBuilder: (context) => PrivacySettingsCategory(
          categoryId: SettingsCategoryIds.privacy,
          isActive: _activeCategory == SettingsCategoryIds.privacy,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.importExport,
        title:
            SettingsCategoryMetadata.getTitle(SettingsCategoryIds.importExport),
        icon:
            SettingsCategoryMetadata.getIcon(SettingsCategoryIds.importExport),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.importExport,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.importExport,
        ),
        isVisible: true,
        contentBuilder: (context) => ImportExportSettingsCategory(
          categoryId: SettingsCategoryIds.importExport,
          isActive: _activeCategory == SettingsCategoryIds.importExport,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.desktop,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.desktop),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.desktop),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.desktop,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.desktop,
        ),
        isVisible: true,
        contentBuilder: (context) => DesktopSettingsCategory(
          categoryId: SettingsCategoryIds.desktop,
          isActive: _activeCategory == SettingsCategoryIds.desktop,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.mobile,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.mobile),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.mobile),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.mobile,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.mobile,
        ),
        isVisible: true,
        contentBuilder: (context) => MobileSettingsCategory(
          categoryId: SettingsCategoryIds.mobile,
          isActive: _activeCategory == SettingsCategoryIds.mobile,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.premiumFeatures,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.premiumFeatures,
        ),
        icon: SettingsCategoryMetadata.getIcon(
          SettingsCategoryIds.premiumFeatures,
        ),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.premiumFeatures,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.premiumFeatures,
        ),
        isVisible: true,
        contentBuilder: (context) => PremiumSettingsCategory(
          categoryId: SettingsCategoryIds.premiumFeatures,
          isActive: _activeCategory == SettingsCategoryIds.premiumFeatures,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.adminCenter,
        title: SettingsCategoryMetadata.getTitle(
          SettingsCategoryIds.adminCenter,
        ),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.adminCenter),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.adminCenter,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.adminCenter,
        ),
        isVisible: true,
        contentBuilder: (context) => AdminSettingsCategory(
          categoryId: SettingsCategoryIds.adminCenter,
          isActive: _activeCategory == SettingsCategoryIds.adminCenter,
        ),
      ),
      BaseSettingsCategory(
        id: SettingsCategoryIds.about,
        title: SettingsCategoryMetadata.getTitle(SettingsCategoryIds.about),
        icon: SettingsCategoryMetadata.getIcon(SettingsCategoryIds.about),
        description: SettingsCategoryMetadata.getDescription(
          SettingsCategoryIds.about,
        ),
        priority: SettingsCategoryMetadata.getPriority(
          SettingsCategoryIds.about,
        ),
        isVisible: true,
        contentBuilder: (context) => AboutSettingsCategory(
          categoryId: SettingsCategoryIds.about,
          isActive: _activeCategory == SettingsCategoryIds.about,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Use ThemeProvider to ensure real-time theme updates
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (_isLoading) {
          return Scaffold(
            body: Center(
              child: _platformAdapter.buildProgressIndicator(),
            ),
          );
        }

        if (_errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Settings Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  _platformAdapter.buildButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _loadVisibleCategories();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildResponsiveLayout(context);
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return _buildMobileLayout();
      case ScreenSize.tablet:
        return _buildTabletLayout();
      case ScreenSize.desktop:
        return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          tooltip: 'Back',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: SettingsCategoryList(
              categories: _getFilteredCategories(),
              activeCategory: _activeCategory,
              onCategorySelected: _navigateToCategoryMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          tooltip: 'Back',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: SettingsCategoryList(
                    categories: _getFilteredCategories(),
                    activeCategory: _activeCategory,
                    onCategorySelected: (categoryId) {
                      setState(() {
                        _activeCategory = categoryId;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _buildActiveCategoryContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildSearchBar(),
                Expanded(
                  child: SettingsCategoryList(
                    categories: _getFilteredCategories(),
                    activeCategory: _activeCategory,
                    onCategorySelected: (categoryId) {
                      setState(() {
                        _activeCategory = categoryId;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _buildActiveCategoryContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: _platformAdapter.buildTextField(
        placeholder: 'Search settings...',
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  List<BaseSettingsCategory> _getFilteredCategories() {
    if (_searchQuery.isEmpty) {
      return _visibleCategories;
    }

    final query = _searchQuery.toLowerCase();
    return _visibleCategories.where((category) {
      return category.title.toLowerCase().contains(query) ||
          category.description.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildActiveCategoryContent() {
    final category = _visibleCategories.firstWhere(
      (c) => c.id == _activeCategory,
      orElse: () => _visibleCategories.first,
    );

    return Container(
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: category.contentBuilder(context),
        ),
      ),
    );
  }

  void _navigateToCategoryMobile(String categoryId) {
    // On mobile, we push a new screen for the category details
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              SettingsCategoryMetadata.getTitle(categoryId),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          body: Container(
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildCategoryContentById(categoryId),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContentById(String categoryId) {
    final category = _visibleCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => _visibleCategories.first,
    );
    return category.contentBuilder(context);
  }

  @override
  void dispose() {
    _platformFilter.dispose();
    super.dispose();
  }
}
