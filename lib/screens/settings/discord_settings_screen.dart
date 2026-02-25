import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../components/modern_card.dart';
import '../../components/gradient_button.dart';
import '../../services/discord_service.dart';

/// Discord Bot Settings Screen
///
/// Allows users to configure their Discord bot token and guild ID,
/// test the connection, and view connection status.
class DiscordSettingsScreen extends StatefulWidget {
  const DiscordSettingsScreen({super.key});

  @override
  State<DiscordSettingsScreen> createState() => _DiscordSettingsScreenState();
}

class _DiscordSettingsScreenState extends State<DiscordSettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _guildIdController = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;
  String? _saveMessage;
  bool _saveSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final discordService = context.read<DiscordService>();
    setState(() {
      _tokenController.text = discordService.botToken ?? '';
      _guildIdController.text = discordService.guildId ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (_tokenController.text.trim().isEmpty) {
      setState(() {
        _saveMessage = 'Please enter a bot token';
        _saveSuccess = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      final discordService = context.read<DiscordService>();
      await discordService.setBotToken(_tokenController.text.trim());
      await discordService.setGuildId(_guildIdController.text.trim());

      setState(() {
        _saveMessage = 'Settings saved successfully';
        _saveSuccess = true;
      });

      // Clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _saveMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _saveMessage = 'Failed to save settings: $e';
        _saveSuccess = false;
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final discordService = context.read<DiscordService>();

      // First save the settings
      await discordService.setBotToken(_tokenController.text.trim());
      await discordService.setGuildId(_guildIdController.text.trim());

      // Test the configuration
      final result = await discordService.testConfiguration();

      setState(() {
        _testResult = result;
      });
    } catch (e) {
      setState(() {
        _testResult = {
          'success': false,
          'error': e.toString(),
        };
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _guildIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discordService = context.watch<DiscordService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Discord Bot Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Card
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        discordService.isConnected
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: discordService.isConnected
                            ? Colors.green
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        discordService.isConnected
                            ? 'Connected'
                            : 'Disconnected',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: discordService.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (discordService.isConnected &&
                      discordService.botToken != null)
                    _buildConnectionInfo(discordService),
                  if (discordService.connectionError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Error: ${discordService.connectionError}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bot Configuration Card
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Bot Configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'Bot Token',
                      hintText: 'Enter your Discord bot token',
                      prefixIcon: const Icon(Icons.vpn_key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    obscureText: true,
                    maxLines: 1,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _guildIdController,
                    decoration: InputDecoration(
                      labelText: 'Guild ID (Optional)',
                      hintText: 'Enter your server/guild ID',
                      prefixIcon: const Icon(Icons.dns),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    maxLines: 1,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          text: _isSaving ? 'Saving...' : 'Save Settings',
                          onPressed: _isSaving ? null : _saveSettings,
                          isLoading: _isSaving,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isTesting ? null : _testConnection,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isTesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Test Connection'),
                        ),
                      ),
                    ],
                  ),
                  if (_saveMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _saveSuccess
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _saveSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _saveSuccess ? Icons.check_circle : Icons.error,
                            color: _saveSuccess ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _saveMessage!,
                              style: TextStyle(
                                color: _saveSuccess ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test Results Card
            if (_testResult != null)
              ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _testResult!['success'] == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: _testResult!['success'] == true
                              ? Colors.green
                              : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _testResult!['success'] == true
                              ? 'Connection Successful'
                              : 'Connection Failed',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _testResult!['success'] == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTestResult(_testResult!),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Help Card
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline,
                          color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'How to Get Your Bot Token',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Go to the Discord Developer Portal\n'
                    '2. Create a new application\n'
                    '3. Go to the "Bot" section\n'
                    '4. Click "Add Bot"\n'
                    '5. Copy your bot token\n'
                    '6. Enable the following intents:\n'
                    '   - Server Members Intent\n'
                    '   - Message Content Intent\n'
                    '7. Invite the bot to your server',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(
                        text: 'https://discord.com/developers/applications',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Open Discord Developer Portal'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(DiscordService discordService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_testResult != null && _testResult!['botName'] != null) ...[
          _buildInfoRow('Bot Name:', _testResult!['botName']),
          const SizedBox(height: 8),
          _buildInfoRow('Bot ID:', _testResult!['botId']),
        ] else ...[
          const Text('Bot is connected'),
        ],
      ],
    );
  }

  Widget _buildTestResult(Map<String, dynamic> result) {
    if (result['success'] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status:', 'Connected'),
          if (result['botName'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Bot Name:', result['botName']),
          ],
          if (result['botId'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Bot ID:', result['botId']),
          ],
        ],
      );
    } else {
      return Text(
        'Error: ${result['error'] ?? 'Unknown error'}',
        style: const TextStyle(color: Colors.red),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
