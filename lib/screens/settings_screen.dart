import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../widgets/settings/openclaw_gateway_category.dart';
import '../widgets/settings/hermes_gateway_category.dart';
import '../components/settings_sidebar.dart';

final Logger _log = Logger('SettingsScreen');

class SettingsScreen extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;
  final bool hermesEnabled;

  const SettingsScreen({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
    this.hermesEnabled = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: Row(
        children: [
          // Sidebar
          SettingsSidebar(
            sections: SettingsSidebar.defaultSections,
            selectedSectionId: 'general',
            onSectionSelected: (sectionId) {
              _log.info('Settings section selected: $sectionId');
            },
          ),
          // Main content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // General settings
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: const Text('App Theme'),
                        subtitle: const Text('Light / Dark / System'),
                      ),
                      ListTile(
                        title: const Text('Language'),
                        subtitle: const Text('English / French'),
                      ),
                    ],
                  ),
                ),
                // OpenClaw Gateway settings
                Card(
                  child: const OpenClawGatewayCategory(
                    categoryId: 'openclaw-gateway',
                  ),
                ),
                // Hermes Gateway settings
                Card(
                  child: HermesGatewayCategory(
                    hermesUrl: widget.hermesUrl,
                    hermesApiKey: widget.hermesApiKey,
                    hermesEnabled: widget.hermesEnabled,
                  ),
                ),
                // Model selection
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: const Text('Default Model'),
                        subtitle: const Text('Select your preferred LLM'),
                      ),
                      DropdownButton<String>(
                        value: 'hermes/model',
                        items: const [
                          DropdownMenuItem(
                            value: 'hermes/model',
                            child: Text('Hermes Default'),
                          ),
                          DropdownMenuItem(
                            value: 'openclaw/model',
                            child: Text('OpenClaw Default'),
                          ),
                          DropdownMenuItem(
                            value: 'anthropic/claude-3-opus',
                            child: Text('Claude 3 Opus'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          _log.info('Model changed to $newValue');
                          // Save preference
                        },
                      ),
                    ],
                  ),
                ),
                // API Key management
                Card(
                  child: ListTile(
                    title: const Text('API Keys'),
                    subtitle:
                        const Text('Manage your API keys for various services'),
                    trailing: IconButton(
                      icon: const Icon(Icons.key),
                      onPressed: () {
                        // Navigate to API key management
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
