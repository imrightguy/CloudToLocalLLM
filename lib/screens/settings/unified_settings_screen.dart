import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UnifiedSettingsScreen extends StatefulWidget {
  final String? initialCategory;

  const UnifiedSettingsScreen({super.key, this.initialCategory});

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  late String _selectedCategory;

  final List<_CategoryItem> _categories = [
    _CategoryItem('general', 'General', Icons.settings),
    _CategoryItem('appearance', 'Appearance', Icons.palette),
    _CategoryItem('connection', 'Connection', Icons.vpn_key),
    _CategoryItem('avatar', 'Avatar', Icons.face),
    _CategoryItem('desktop', 'Desktop', Icons.desktop_windows),
    _CategoryItem('about', 'About', Icons.info),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'general';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Row(
        children: [
          _buildNavigationRail(context),
          Expanded(child: _buildContentArea(context)),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category.id;

          return ListTile(
            leading: Icon(category.icon),
            title: Text(category.label),
            selected: isSelected,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            onTap: () {
              setState(() {
                _selectedCategory = category.id;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildCategoryContent(context),
      ),
    );
  }

  Widget _buildCategoryContent(BuildContext context) {
    switch (_selectedCategory) {
      case 'general':
        return _buildGeneralSettings(context);
      case 'appearance':
        return _buildAppearanceSettings(context);
      case 'connection':
        return _buildConnectionSettings(context);
      case 'avatar':
        return _buildAvatarSettings(context);
      case 'desktop':
        return _buildDesktopSettings(context);
      case 'about':
        return _buildAboutSettings(context);
      default:
        return Center(child: Text('Unknown category: $_selectedCategory'));
    }
  }

  Widget _buildGeneralSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('General Settings',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('Application preferences and configuration.'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Downloads'),
          subtitle: const Text('Manage download settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/downloads'),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('Customize the look and feel of the application.'),
      ],
    );
  }

  Widget _buildConnectionSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connection', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('Manage tunnel and daemon connections.'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('Tunnel Settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/tunnel'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_ethernet),
          title: const Text('Daemon Settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/daemon'),
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Connection Status'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/connection-status'),
        ),
      ],
    );
  }

  Widget _buildAvatarSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avatar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('Configure avatar personality and evolution.'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.face),
          title: const Text('Avatar Customization'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/avatar/customization'),
        ),
      ],
    );
  }

  Widget _buildDesktopSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Desktop', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('Desktop-specific settings and file operations.'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('File Operations'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/desktop/files'),
        ),
      ],
    );
  }

  Widget _buildAboutSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Text('CloudToLocalLLM - OpenClaw Agent Manager'),
        const SizedBox(height: 8),
        const Text('Version: 1.0.0'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.cloud),
          title: const Text('Upgrade to Pro'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/upgrade'),
        ),
      ],
    );
  }
}

class _CategoryItem {
  final String id;
  final String label;
  final IconData icon;

  const _CategoryItem(this.id, this.label, this.icon);
}
