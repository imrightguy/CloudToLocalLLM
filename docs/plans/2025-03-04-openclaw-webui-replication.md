# OpenClaw WebUI Replication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replicate the OpenClaw WebUI navigation structure and chat interface in Flutter, creating a unified, consistent user experience that matches the official WebUI.

**Architecture:**
- Create a `NavigationShell` widget that wraps all content with the OpenClaw WebUI layout (collapsible sidebar + top banner + main content area)
- Implement grouped navigation sections (Chat, Control, Agent, Settings, Resources) matching the WebUI exactly
- Use GoRouter for navigation with route-based rendering of main content
- State management via existing Provider pattern for sidebar collapse state, theme mode, and active section

**Tech Stack:**
- Flutter 3.5+ with Material Design 3
- go_router for navigation
- Provider for state management
- Existing services (ConnectionManagerService, GatewayControlService, etc.)

---

## Task 1: Create NavigationShell Widget (Core Layout)

**Files:**
- Create: `lib/widgets/navigation/openclaw_navigation_shell.dart`
- Create: `lib/widgets/navigation/sidebar_section.dart`
- Create: `lib/widgets/navigation/navigation_rail_item.dart`

**Step 1: Create sidebar section widget**

Create `lib/widgets/navigation/sidebar_section.dart`:

```dart
import 'package:flutter/material.dart';

class SidebarSection extends StatefulWidget {
  final String title;
  final List<NavigationRailDestination> destinations;
  final bool initiallyExpanded;

  const SidebarSection({
    required this.title,
    required this.destinations,
    this.initiallyExpanded = true,
    super.key,
  });

  @override
  State<SidebarSection> createState() => _SidebarSectionState();
}

class _SidebarSectionState extends State<SidebarSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: _isExpanded
              ? Column(
                  children: widget.destinations.map((dest) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: dest,
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
```

Run: `flutter analyze lib/widgets/navigation/sidebar_section.dart`
Expected: No issues

**Step 2: Create navigation rail item widget**

Create `lib/widgets/navigation/navigation_rail_item.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OpenClawNavItem extends StatelessWidget {
  final String title;
  final String route;
  final IconData icon;
  final bool selected;

  const OpenClawNavItem({
    required this.title,
    required this.route,
    required this.icon,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Run: `flutter analyze lib/widgets/navigation/navigation_rail_item.dart`
Expected: No issues

**Step 3: Create main NavigationShell widget**

Create `lib/widgets/navigation/openclaw_navigation_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sidebar_section.dart';
import 'navigation_rail_item.dart';

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
  bool _focusMode = false;

  void _goBranch(int index) {
    widget.navigationShell.goBranch(index);
  }

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
          Image.asset('assets/images/openclaw_logo.png', width: 32, height: 32, errorBuilder: (ctx, err, stack) => const Icon(Icons.smart_toy, size: 32)),
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
          title: 'Chat',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              title: 'Chat',
              route: '/chat',
              icon: Icons.chat_bubble_outline,
              selected: widget.navigationShell.currentIndex == 0,
            ),
          ],
        ),

        // Control section
        SidebarSection(
          title: 'Control',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              title: 'Overview',
              route: '/overview',
              icon: Icons.dashboard_outlined,
              selected: widget.navigationShell.currentIndex == 1,
            ),
            OpenClawNavItem(
              title: 'Channels',
              route: '/channels',
              icon: Icons.cable_outlined,
              selected: widget.navigationShell.currentIndex == 2,
            ),
            OpenClawNavItem(
              title: 'Instances',
              route: '/instances',
              icon: Icons.devices_outlined,
              selected: widget.navigationShell.currentIndex == 3,
            ),
            OpenClawNavItem(
              title: 'Sessions',
              route: '/sessions',
              icon: Icons.history_outlined,
              selected: widget.navigationShell.currentIndex == 4,
            ),
            OpenClawNavItem(
              title: 'Usage',
              route: '/usage',
              icon: Icons.analytics_outlined,
              selected: widget.navigationShell.currentIndex == 5,
            ),
            OpenClawNavItem(
              title: 'Cron Jobs',
              route: '/cron',
              icon: Icons.schedule_outlined,
              selected: widget.navigationShell.currentIndex == 6,
            ),
          ],
        ),

        // Agent section
        SidebarSection(
          title: 'Agent',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              title: 'Agents',
              route: '/agents',
              icon: Icons.smart_toy_outlined,
              selected: widget.navigationShell.currentIndex == 7,
            ),
            OpenClawNavItem(
              title: 'Skills',
              route: '/skills',
              icon: Icons.extension_outlined,
              selected: widget.navigationShell.currentIndex == 8,
            ),
            OpenClawNavItem(
              title: 'Nodes',
              route: '/nodes',
              icon: Icons.hub_outlined,
              selected: widget.navigationShell.currentIndex == 9,
            ),
          ],
        ),

        // Settings section
        SidebarSection(
          title: 'Settings',
          initiallyExpanded: true,
          destinations: [
            OpenClawNavItem(
              title: 'Config',
              route: '/config',
              icon: Icons.settings_outlined,
              selected: widget.navigationShell.currentIndex == 10,
            ),
            OpenClawNavItem(
              title: 'Debug',
              route: '/debug',
              icon: Icons.bug_report_outlined,
              selected: widget.navigationShell.currentIndex == 11,
            ),
            OpenClawNavItem(
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
      child: OpenClawNavItem(
        title: 'Docs',
        route: 'https://docs.openclaw.ai',
        icon: Icons.menu_book_outlined,
        selected: false,
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
                  color: isHealthy ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHealthy ? 'Healthy' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
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
    super.key,
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
```

Run: `flutter analyze lib/widgets/navigation/openclaw_navigation_shell.dart`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/widgets/navigation/
git commit -m "feat: add OpenClaw WebUI navigation shell with collapsible sidebar

- Create NavigationShell widget matching OpenClaw WebUI layout
- Implement collapsible sidebar sections (Chat, Control, Agent, Settings)
- Add top banner with version, health status, theme toggle
- Create reusable SidebarSection and OpenClawNavItem widgets"
```

---

## Task 2: Update GoRouter Configuration

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/config/router.dart`

**Step 1: Update router configuration**

Modify `lib/config/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../screens/onboarding/setup_wizard_screen.dart';
import '../widgets/navigation/openclaw_navigation_shell.dart';
import '../services/setup_status_service.dart';
import '../services/auth_service.dart';
import '../screens/chat/home_layout_screen.dart';
import '../screens/dashboard/overview_screen.dart';

// Placeholder screens - to be implemented in subsequent tasks
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String route;

  const PlaceholderScreen({required this.title, required this.route, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Route: $route', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerConfig = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/setup',
  routes: [
    GoRoute(
      path: '/setup',
      pageBuilder: (context, state) => const SetupWizardScreen(),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) {
        // Check if setup is complete
        final setupStatus = context.read<SetupStatusService>();
        final authService = context.read<AuthService>();

        if (!setupStatus.isSetupComplete && !authService.isAuthenticated.value) {
          return const SetupWizardScreen();
        }

        // Use shell navigation for main app
        return StatefulShellRoute.indexed(
          state: state,
          builder: (context, state, navigationShell) {
            return OpenClawNavigationShell(navigationShell: navigationShell);
          },
          branches: [
            // Chat
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  pageBuilder: (context, state) => const HomeLayoutScreen(),
                ),
              ],
            ),
            // Overview/Dashboard
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/overview',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Overview',
                    route: '/overview',
                  ),
                ),
                GoRoute(
                  path: '/dashboard',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Dashboard',
                    route: '/dashboard',
                  ),
                ),
              ],
            ),
            // Channels
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/channels',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Channels',
                    route: '/channels',
                  ),
                ),
              ],
            ),
            // Instances
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/instances',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Instances',
                    route: '/instances',
                  ),
                ),
              ],
            ),
            // Sessions
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sessions',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Sessions',
                    route: '/sessions',
                  ),
                ),
              ],
            ),
            // Usage
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/usage',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Usage',
                    route: '/usage',
                  ),
                ),
              ],
            ),
            // Cron Jobs
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cron',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Cron Jobs',
                    route: '/cron',
                  ),
                ),
              ],
            ),
            // Agents
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/agents',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Agents',
                    route: '/agents',
                  ),
                ),
              ],
            ),
            // Skills
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/skills',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Skills',
                    route: '/skills',
                  ),
                ),
              ],
            ),
            // Nodes
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/nodes',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Nodes',
                    route: '/nodes',
                  ),
                ),
              ],
            ),
            // Config
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/config',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Config',
                    route: '/config',
                  ),
                ),
              ],
            ),
            // Debug
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/debug',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Debug',
                    route: '/debug',
                  ),
                ),
              ],
            ),
            // Logs
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/logs',
                  pageBuilder: (context, state) => const PlaceholderScreen(
                    title: 'Logs',
                    route: '/logs',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  ],
);
```

Run: `flutter analyze lib/config/router.dart`
Expected: No issues (may have import errors for screens not yet created)

**Step 2: Commit**

```bash
git add lib/config/router.dart
git commit -m "feat: update router with OpenClaw WebUI navigation structure

- Add StatefulShellRoute for indexed navigation
- Configure all 13 routes matching WebUI sections
- Add PlaceholderScreen for unimplemented routes
- Integrate NavigationShell with GoRouter"
```

---

## Task 3: Implement Overview Page

**Files:**
- Create: `lib/screens/dashboard/overview_screen.dart`
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (merge overview functionality)

**Step 1: Create overview screen matching WebUI**

Create `lib/screens/dashboard/overview_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/connection_manager_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final connService = context.read<ConnectionManagerService>();
    await connService.testConnection();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gateway status, entry points, and a fast health read.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Consumer<ConnectionManagerService>(
                    builder: (context, connService, child) {
                      final gatewayStatus = connService.getGatewayStatus();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gateway Access Section
                          _buildSection(
                            'Gateway Access',
                            'Where the dashboard connects and how it authenticates.',
                            _buildGatewayAccessCard(connService),
                          ),

                          const SizedBox(height: 24),

                          // Snapshot Section
                          _buildSection(
                            'Snapshot',
                            'Latest gateway handshake information.',
                            _buildSnapshotCard(gatewayStatus),
                          ),

                          const SizedBox(height: 24),

                          // Quick Stats
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Instances',
                                  gatewayStatus['instances']?.toString() ?? '0',
                                  'Presence beacons in the last 5 minutes',
                                  Icons.devices,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Sessions',
                                  gatewayStatus['sessions']?.toString() ?? 'n/a',
                                  'Recent session keys tracked by the gateway',
                                  Icons.history,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String description, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildGatewayAccessCard(ConnectionManagerService connService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormField(
              'WebSocket URL',
              connService.getGatewayStatus()['endpoint'] ?? 'ws://127.0.0.1:18789',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Gateway Token',
              connService.gatewayToken?.substring(0, 16) ?? 'Not set',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Default Session Key',
              'main',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(Map<String, dynamic> gatewayStatus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSnapshotRow('Status', gatewayStatus['healthStatus']?.toString() ?? 'Unknown'),
            _buildSnapshotRow('Uptime', gatewayStatus['uptime'] ?? 'n/a'),
            _buildSnapshotRow('Last Channels Refresh', gatewayStatus['lastRefresh'] ?? 'n/a'),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        TextField(
          initialValue: value,
          readOnly: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Run: `flutter analyze lib/screens/dashboard/overview_screen.dart`
Expected: No issues

**Step 2: Commit**

```bash
git add lib/screens/dashboard/overview_screen.dart
git commit -m "feat: implement overview screen matching OpenClaw WebUI

- Create OverviewScreen with gateway access form
- Add snapshot section showing status, uptime, refresh time
- Implement quick stat cards for instances and sessions
- Match WebUI layout and styling"
```

---

## Task 4: Enhance Chat Interface with WebUI Features

**Files:**
- Modify: `lib/screens/chat/home_layout_screen.dart`
- Create: `lib/widgets/chat/chat_control_bar.dart`
- Create: `lib/widgets/chat/session_selector.dart`

**Step 1: Create session selector widget**

Create `lib/widgets/chat/session_selector.dart`:

```dart
import 'package:flutter/material.dart';

class SessionSelector extends StatefulWidget {
  final String currentSession;
  final ValueChanged<String> onSessionChanged;
  final bool enabled;

  const SessionSelector({
    required this.currentSession,
    required this.onSessionChanged,
    this.enabled = true,
    super.key,
  });

  @override
  State<SessionSelector> createState() => _SessionSelectorState();
}

class _SessionSelectorState extends State<SessionSelector> {
  final List<String> _sessions = ['main'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: widget.currentSession,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _sessions.map((session) {
        return DropdownMenuItem<String>(
          value: session,
          child: Text(session),
        );
      }).toList(),
      onChanged: widget.enabled ? (value) {
        widget.onSessionChanged(value!);
      } : null,
    );
  }
}
```

Run: `flutter analyze lib/widgets/chat/session_selector.dart`
Expected: No issues

**Step 2: Create chat control bar widget**

Create `lib/widgets/chat/chat_control_bar.dart`:

```dart
import 'package:flutter/material.dart';

class ChatControlBar extends StatelessWidget {
  final String currentSession;
  final bool isConnected;
  final ValueChanged<String> onSessionChanged;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onThinkingToggle;
  final ValueChanged<bool> onFocusModeToggle;
  final ValueChanged<bool> onCronSessionsToggle;
  final bool showThinking;
  final bool focusMode;
  final bool showCronSessions;

  const ChatControlBar({
    required this.currentSession,
    required this.isConnected,
    required this.onSessionChanged,
    required this.onRefresh,
    required this.onThinkingToggle,
    required this.onFocusModeToggle,
    required this.onCronSessionsToggle,
    this.showThinking = true,
    this.focusMode = false,
    this.showCronSessions = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // Session selector
          SessionSelector(
            currentSession: currentSession,
            onSessionChanged: onSessionChanged,
            enabled: isConnected,
          ),
          const SizedBox(width: 16),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isConnected ? onRefresh : null,
            tooltip: 'Refresh chat data',
          ),
          const Text('|'),

          // Toggle thinking output
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed: isConnected ? () => onThinkingToggle(!showThinking) : null,
            tooltip: 'Toggle assistant thinking/working output',
            style: IconButton.styleFrom(
              backgroundColor: showThinking ? Theme.of(context).colorScheme.primaryContainer : null,
            ),
          ),

          // Toggle focus mode
          IconButton(
            icon: const Icon(Icons.fullscreen_outlined),
            onPressed: isConnected ? () => onFocusModeToggle(!focusMode) : null,
            tooltip: 'Toggle focus mode (hide sidebar + page header)',
            style: IconButton.styleFrom(
              backgroundColor: focusMode ? Theme.of(context).colorScheme.primaryContainer : null,
            ),
          ),

          // Toggle cron sessions
          IconButton(
            icon: const Icon(Icons.schedule_outlined),
            onPressed: isConnected ? () => onCronSessionsToggle(!showCronSessions) : null,
            tooltip: 'Show cron sessions',
            style: IconButton.styleFrom(
              backgroundColor: showCronSessions ? Theme.of(context).colorScheme.primaryContainer : null,
            ),
          ),
        ],
      ),
    );
  }
}
```

Run: `flutter analyze lib/widgets/chat/chat_control_bar.dart`
Expected: No issues

**Step 3: Update home layout screen**

Modify `lib/screens/chat/home_layout_screen.dart`:

```dart
// Add control bar to the existing chat interface
// Add state for: showThinking, focusMode, showCronSessions

class _HomeLayoutScreenState extends State<HomeLayoutScreen> {
  bool _showThinking = true;
  bool _focusMode = false;
  bool _showCronSessions = true;

  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Add control bar
          if (!_focusMode)
            ChatControlBar(
              currentSession: _currentSession,
              isConnected: _connService.isConnected,
              onSessionChanged: (session) => setState(() => _currentSession = session),
              onRefresh: _loadData,
              onThinkingToggle: (value) => setState(() => _showThinking = value),
              onFocusModeToggle: (value) => setState(() => _focusMode = value),
              onCronSessionsToggle: (value) => setState(() => _showCronSessions = value),
              showThinking: _showThinking,
              focusMode: _focusMode,
              showCronSessions: _showCronSessions,
            ),

          // Existing chat content
          Expanded(
            child: _focusMode
                ? _buildChatContent()  // No header when focus mode
                : Column(
                    children: [
                      _buildChatHeader(),
                      Expanded(child: _buildChatContent()),
                    ],
                  ),
          ),

          // Existing input area
          _buildInputArea(),
        ],
      ),
    );
  }

  // ... existing methods ...
}
```

Run: `flutter analyze lib/screens/chat/home_layout_screen.dart`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/screens/chat/home_layout_screen.dart lib/widgets/chat/
git commit -m "feat: add WebUI chat control features to chat interface

- Add session selector dropdown
- Implement toggle buttons: thinking output, focus mode, cron sessions
- Add refresh chat data button
- Update home layout to integrate control bar
- Match OpenClaw WebUI chat functionality"
```

---

## Task 5: Remove Old Dashboard and Settings UI

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (move overview functionality)
- Delete: `lib/screens/settings/unified_settings_screen.dart` (replaced by shell navigation)

**Step 1: Clean up old dashboard components**

The existing `dashboard_screen.dart` contains both overview and agent monitoring. Move the agent monitoring to a separate screen.

Run: `mv lib/screens/dashboard/dashboard_screen.dart lib/screens/dashboard/old_dashboard_screen.dart.bak`

**Step 2: Remove unified settings screen**

The settings navigation is now handled by the sidebar navigation shell.

Run: `rm lib/screens/settings/unified_settings_screen.dart`

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor: remove old dashboard and settings UI components

- Archive old dashboard_screen.dart (functionality moved to overview_screen)
- Remove unified_settings_screen.dart (navigation now in sidebar)
- Clean up unused navigation components"
```

---

## Task 6: Update Theme Provider for Theme Toggle

**Files:**
- Modify: `lib/services/theme_provider.dart`

**Step 1: Add theme mode switching capability**

Modify `lib/services/theme_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  final SharedPreferences _prefs;

  ThemeProvider({required SharedPreferences prefs})
      : _prefs = prefs {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    final brightness = SchedulerPlatformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  Future<void> _loadThemeMode() async {
    final savedTheme = _prefs.getString('theme_mode');
    if (savedTheme != null) {
      _themeMode = savedTheme == 'system'
          ? ThemeMode.system
          : savedTheme == 'dark'
              ? ThemeMode.dark
              : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme_mode', mode.toString().split('.').last);
    notifyListeners();
  }

  ThemeData getTheme(BuildContext context) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;

    // TODO: Load custom colors from OpenClaw config
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4), // OpenClaw accent color
        brightness: brightness,
      ),
    );
  }
}
```

Run: `flutter analyze lib/services/theme_provider.dart`
Expected: No issues

**Step 2: Commit**

```bash
git add lib/services/theme_provider.dart
git commit -m "feat: add theme mode switching to ThemeProvider

- Implement setThemeMode() method
- Persist theme preference to shared preferences
- Support system, light, and dark modes
- Add isDarkMode getter for theme queries"
```

---

## Task 7: Add OpenClaw Logo Asset

**Files:**
- Create: `assets/images/openclaw_logo.png` (needs actual logo file)

**Step 1: Add placeholder or reference**

For now, use the icon as fallback. Update the NavigationShell widget if needed.

**Step 2: Update pubspec.yaml if needed**

Ensure assets directory is included in pubspec.yaml.

**Step 3: Commit**

```bash
git add assets/images/ pubspec.yaml
git commit -m "chore: add OpenClaw logo asset placeholder"
```

---

## Task 8: Test Navigation and Layout

**Files:**
- Test: Manual testing of navigation flow

**Step 1: Run the app**

Run: `flutter run -d linux`

**Step 2: Verify navigation**

Test each route in the sidebar:
- Chat
- Overview
- Channels (placeholder)
- Instances (placeholder)
- Sessions (placeholder)
- Usage (placeholder)
- Cron Jobs (placeholder)
- Agents (placeholder)
- Skills (placeholder)
- Nodes (placeholder)
- Config (placeholder)
- Debug (placeholder)
- Logs (placeholder)

**Step 3: Verify sidebar collapse**

Click collapse button and verify sidebar collapses/expands properly.

**Step 4: Verify theme toggle**

Test each theme button (System, Light, Dark).

**Step 5: Verify chat control bar**

Navigate to Chat page and test:
- Session selector
- Refresh button
- Toggle thinking output
- Toggle focus mode
- Toggle cron sessions

---

## Task 9: Fix Import Errors and Provider Dependencies

**Files:**
- Multiple

**Step 1: Fix any import errors**

Run: `flutter analyze`

Fix any missing imports or provider dependencies.

**Step 2: Commit**

```bash
git commit -m "fix: resolve import errors and provider dependencies"
```

---

## Task 10: Final Polish and Testing

**Files:**
- Multiple

**Step 1: Add OpenClaw logo**

Find and add the actual OpenClaw logo to `assets/images/openclaw_logo.png`.

**Step 2: Test all navigation flows**

Ensure all routes work correctly and the active state highlights properly.

**Step 3: Test focus mode**

Verify focus mode properly hides sidebar and top banner.

**Step 4: Test theme switching**

Verify theme persists across app restarts.

**Step 5: Commit**

```bash
git add -A
git commit -m "polish: complete OpenClaw WebUI replication

- Add OpenClaw logo asset
- Fix navigation active states
- Test and verify all UI features
- Ensure theme persistence works correctly"
```

---

## Summary

This plan replicates the OpenClaw WebUI with:

1. **Collapsible sidebar** with grouped sections (Chat, Control, Agent, Settings, Resources)
2. **Top banner** with OpenClaw branding, version info, health status, theme toggle
3. **13 routes** matching the WebUI navigation structure
4. **Chat interface controls** (session selector, refresh, thinking toggle, focus mode, cron sessions)
5. **Overview page** with gateway access form and snapshot info
6. **Theme switching** (System/Light/Dark) with persistence

The navigation is now unified and consistent across the entire app, matching the official OpenClaw WebUI experience.
