import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sidebar_section.dart';
import 'navigation_rail_item.dart';
import '../../config/app_config.dart';
import '../../services/connection_manager_service.dart';
import '../../services/theme_provider.dart';

class OpenClawNavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const OpenClawNavigationShell({
    required this.navigationShell,
    super.key,
  });

  @override
  State<OpenClawNavigationShell> createState() =>
      _OpenClawNavigationShellState();
}

class _OpenClawNavigationShellState extends State<OpenClawNavigationShell> {
  bool _sidebarCollapsed = false;
  final bool _focusMode = false;

  @override
  Widget build(BuildContext context) {
    if (widget.navigationShell.currentIndex == 0) {
      return Scaffold(
        body: widget.navigationShell,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 56 : 240,
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
                // Header with collapse button
                if (!_focusMode)
                  _buildSidebarHeader()
                else
                  const SizedBox(height: 16),

                // Navigation sections
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildSidebarContent(),
                  ),
                ),

                // Resources section at bottom
                if (!_focusMode) _buildResourcesSection(),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top banner
                if (!_focusMode) _buildTopBanner() else const SizedBox.shrink(),

                // Page content
                Expanded(
                  child: widget.navigationShell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    if (_sidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 32,
              height: 32,
              errorBuilder: (ctx, _, __) => const Icon(Icons.hub, size: 32),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              tooltip: 'Expand sidebar',
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/app_icon.png',
            width: 32,
            height: 32,
            errorBuilder: (ctx, _, __) => const Icon(Icons.hub, size: 32),
          ),
          const SizedBox(width: 12),
          if (!_sidebarCollapsed)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CloudToLocalLLM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Runtime Control Plane',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            tooltip: 'Collapse sidebar',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Channel',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Runtime Channel',
              branchIndex: 0,
              navigationShell: widget.navigationShell,
              icon: Icons.chat_bubble_outline,
              selected: widget.navigationShell.currentIndex == 0,
            ),
          ],
        ),

        // Control section
        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Control',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Overview',
              branchIndex: 1,
              navigationShell: widget.navigationShell,
              icon: Icons.dashboard_outlined,
              selected: widget.navigationShell.currentIndex == 1,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Secure Channels',
              branchIndex: 2,
              navigationShell: widget.navigationShell,
              icon: Icons.cable_outlined,
              selected: widget.navigationShell.currentIndex == 2,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Runtimes',
              branchIndex: 3,
              navigationShell: widget.navigationShell,
              icon: Icons.devices_outlined,
              selected: widget.navigationShell.currentIndex == 3,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Sessions',
              branchIndex: 4,
              navigationShell: widget.navigationShell,
              icon: Icons.history_outlined,
              selected: widget.navigationShell.currentIndex == 4,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Usage',
              branchIndex: 5,
              navigationShell: widget.navigationShell,
              icon: Icons.analytics_outlined,
              selected: widget.navigationShell.currentIndex == 5,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Scheduled Tasks',
              branchIndex: 6,
              navigationShell: widget.navigationShell,
              icon: Icons.schedule_outlined,
              selected: widget.navigationShell.currentIndex == 6,
            ),
          ],
        ),

        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Management',
          initiallyExpanded: false,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Agents',
              branchIndex: 7,
              navigationShell: widget.navigationShell,
              icon: Icons.smart_toy_outlined,
              selected: widget.navigationShell.currentIndex == 7,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Skills',
              branchIndex: 8,
              navigationShell: widget.navigationShell,
              icon: Icons.extension_outlined,
              selected: widget.navigationShell.currentIndex == 8,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Devices',
              branchIndex: 9,
              navigationShell: widget.navigationShell,
              icon: Icons.hub_outlined,
              selected: widget.navigationShell.currentIndex == 9,
            ),
          ],
        ),

        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Settings',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Runtime Settings',
              branchIndex: 10,
              navigationShell: widget.navigationShell,
              icon: Icons.settings_outlined,
              selected: widget.navigationShell.currentIndex == 10,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Debug',
              branchIndex: 11,
              navigationShell: widget.navigationShell,
              icon: Icons.bug_report_outlined,
              selected: widget.navigationShell.currentIndex == 11,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Logs',
              branchIndex: 12,
              navigationShell: widget.navigationShell,
              icon: Icons.list_alt_outlined,
              selected: widget.navigationShell.currentIndex == 12,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResourcesSection() {
    return Padding(
      padding: EdgeInsets.all(_sidebarCollapsed ? 4 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => launchUrl(Uri.parse('${AppConfig.homepageUrl}/docs'),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 0 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: _sidebarCollapsed
                ? Center(
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Docs',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return Consumer<ConnectionManagerService>(
      builder: (context, connService, child) {
        final gatewayStatus = connService.getGatewayStatus();
        final isHealthy = connService.isGatewayHealthy();
        final runtimeLabel =
            gatewayStatus['backendLabel']?.toString() ?? 'No agent runtime';
        final runtimeUrl = connService.activeRuntimeClient?.identity.baseUrl;
        final capabilityModelCount =
            connService.activeRuntimeCapabilities?.models.length ?? 0;
        final configuredModelCount = connService.availableModels.length;
        final modelCount = capabilityModelCount > configuredModelCount
            ? capabilityModelCount
            : configuredModelCount;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  runtimeUrl == null
                      ? runtimeLabel
                      : '$runtimeLabel - $runtimeUrl',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              _BannerChip(
                label: isHealthy ? 'Runtime healthy' : 'Runtime offline',
                color: isHealthy
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              _BannerChip(
                label: 'Desktop actions require approval',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              _BannerChip(
                label: modelCount == 1
                    ? '1 runtime model'
                    : '$modelCount runtime models',
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const Spacer(),
              Row(
                children: [
                  _ThemeButton(
                    icon: Icons.brightness_auto,
                    label: 'System',
                    onPressed: () => _setTheme(ThemeMode.system),
                  ),
                  _ThemeButton(
                    icon: Icons.light_mode,
                    label: 'Light',
                    onPressed: () => _setTheme(ThemeMode.light),
                  ),
                  _ThemeButton(
                    icon: Icons.dark_mode,
                    label: 'Dark',
                    onPressed: () => _setTheme(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _setTheme(ThemeMode mode) {
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.setThemeMode(mode);
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ThemeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: label,
      iconSize: 20,
    );
  }
}
