import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sidebar_section.dart';
import 'navigation_rail_item.dart';
import '../../services/connection_manager_service.dart';
import '../../services/theme_provider.dart';

class OpenClawNavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const OpenClawNavigationShell({
    required this.navigationShell,
    super.key,
  });

  @override
  State<OpenClawNavigationShell> createState() => _OpenClawNavigationShellState();
}

class _OpenClawNavigationShellState extends State<OpenClawNavigationShell> {
  bool _sidebarCollapsed = false;
  final bool _focusMode = false;

  @override
  Widget build(BuildContext context) {
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
                if (!_focusMode)
                  _buildResourcesSection(),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top banner
                if (!_focusMode)
                  _buildTopBanner()
                else
                  const SizedBox.shrink(),

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
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset('assets/images/openclaw_logo.png', width: 32, height: 32, errorBuilder: (ctx, _, __) => const Icon(Icons.smart_toy, size: 32)),
          const SizedBox(width: 12),
          if (!_sidebarCollapsed)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OPENCLAW',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Gateway Dashboard',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(_sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left),
            onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            tooltip: 'Collapse sidebar',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        // Chat section
        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Chat',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Chat',
              route: '/chat',
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
              route: '/overview',
              icon: Icons.dashboard_outlined,
              selected: widget.navigationShell.currentIndex == 1,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Channels',
              route: '/channels',
              icon: Icons.cable_outlined,
              selected: widget.navigationShell.currentIndex == 2,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Instances',
              route: '/instances',
              icon: Icons.devices_outlined,
              selected: widget.navigationShell.currentIndex == 3,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Sessions',
              route: '/sessions',
              icon: Icons.history_outlined,
              selected: widget.navigationShell.currentIndex == 4,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Usage',
              route: '/usage',
              icon: Icons.analytics_outlined,
              selected: widget.navigationShell.currentIndex == 5,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Cron Jobs',
              route: '/cron',
              icon: Icons.schedule_outlined,
              selected: widget.navigationShell.currentIndex == 6,
            ),
          ],
        ),

        // Agent section
        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Agent',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Agents',
              route: '/agents',
              icon: Icons.smart_toy_outlined,
              selected: widget.navigationShell.currentIndex == 7,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Skills',
              route: '/skills',
              icon: Icons.extension_outlined,
              selected: widget.navigationShell.currentIndex == 8,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Nodes',
              route: '/nodes',
              icon: Icons.hub_outlined,
              selected: widget.navigationShell.currentIndex == 9,
            ),
          ],
        ),

        // Settings section
        SidebarSection(
          collapsed: _sidebarCollapsed,
          title: 'Settings',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Config',
              route: '/config',
              icon: Icons.settings_outlined,
              selected: widget.navigationShell.currentIndex == 10,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Debug',
              route: '/debug',
              icon: Icons.bug_report_outlined,
              selected: widget.navigationShell.currentIndex == 11,
            ),
            OpenClawNavItem(
              collapsed: _sidebarCollapsed,
              title: 'Logs',
              route: '/logs',
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
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => launchUrl(Uri.parse('https://docs.openclaw.ai'), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
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
              // Version
              Text(
                'Version: ${gatewayStatus['version'] ?? 'n/a'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 24),

              // Health status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHealthy
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHealthy ? 'Healthy' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const Spacer(),

              // Theme toggle
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
