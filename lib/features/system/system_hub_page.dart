import 'package:flutter/material.dart';
import 'package:zoidbot/components/modern_card.dart';
import 'package:zoidbot/services/system_control_service.dart';
import 'package:zoidbot/services/window_manager_service.dart';
import 'package:zoidbot/di/locator.dart';
import 'package:zoidbot/config/theme.dart';
import 'package:zoidbot/utils/logger.dart';

class SystemHubPage extends StatefulWidget {
  const SystemHubPage({super.key});

  @override
  State<SystemHubPage> createState() => _SystemHubPageState();
}

class _SystemHubPageState extends State<SystemHubPage> {
  final _systemService = serviceLocator<SystemControlService>();
  final _windowService = serviceLocator<WindowManagerService>();
  
  Map<String, String> _stats = {
    'cpu': 'Loading...',
    'ram': 'Loading...',
    'uptime': 'Loading...'
  };
  bool _isRefreshing = false;
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    setState(() => _isRefreshing = true);
    try {
      final stats = await _systemService.getSystemStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      appLogger.error('[SystemHub] Failed to refresh stats', error: e);
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _takeScreenshot() async {
    final path = await _systemService.captureScreenshot();
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Screenshot saved: $path'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to take screenshot. Ensure gnome-screenshot or scrot is installed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runCommand(String cmd) async {
    if (cmd.isEmpty) return;
    final result = await _systemService.executeCommand(cmd);
    if (mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          title: Text('Command Output', style: TextStyle(color: AppTheme.primaryColor)),
          content: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
              child: Text(
                result ?? 'No output',
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Hub'),
        backgroundColor: AppTheme.backgroundCard,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _isRefreshing ? AppTheme.primaryColor : null),
            onPressed: _isRefreshing ? null : _refreshStats,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OS-Level Control Center',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spacingL),
            
            _buildResourceMonitors(),
            SizedBox(height: AppTheme.spacingXL),
            
            _buildDesktopControls(),
            SizedBox(height: AppTheme.spacingXL),
            
            _buildTerminalSimulator(),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceMonitors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Resources', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: AppTheme.spacingM),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3,
          mainAxisSpacing: AppTheme.spacingM,
          crossAxisSpacing: AppTheme.spacingM,
          children: [
            _buildStatCard('CPU Load', _stats['cpu']!, Icons.speed, Colors.orange),
            _buildStatCard('RAM Usage', _stats['ram']!, Icons.memory, Colors.blue),
            _buildStatCard('Uptime', _stats['uptime']!, Icons.access_time, Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ModernCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                Text(
                  value, 
                  overflow: TextOverflow.ellipsis, 
                  maxLines: 1,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Desktop Control', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: AppTheme.spacingM),
        Wrap(
          spacing: AppTheme.spacingM,
          runSpacing: AppTheme.spacingM,
          children: [
            _buildControlButton('Minimize App', Icons.minimize, () => _windowService.minimizeWindow()),
            _buildControlButton('Volume Up', Icons.volume_up, () => _systemService.adjustVolume(true)),
            _buildControlButton('Volume Down', Icons.volume_down, () => _systemService.adjustVolume(false)),
            _buildControlButton('Mute/Unmute', Icons.volume_off, () => _systemService.toggleMute()),
            _buildControlButton('Screenshot', Icons.camera_alt, _takeScreenshot),
            _buildControlButton('Maximize', Icons.check_box_outline_blank, () => _windowService.maximizeWindow()),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 140,
      child: ModernCard(
        onTap: onPressed,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppTheme.primaryColor),
            SizedBox(height: AppTheme.spacingS),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalSimulator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Command', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: AppTheme.spacingM),
        ModernCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              TextField(
                controller: _commandController,
                decoration: InputDecoration(
                  hintText: 'Enter Linux command (e.g. xdotool click 1)',
                  hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.terminal, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: AppTheme.primaryColor),
                    onPressed: () => _runCommand(_commandController.text),
                  ),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                onSubmitted: _runCommand,
              ),
              SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  SizedBox(width: AppTheme.spacingXS),
                  const Text(
                    'Note: xdotool is recommended for mouse/keyboard automation.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
