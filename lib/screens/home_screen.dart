import 'package:flutter/material.dart';
import '../../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;
  final bool hermesEnabled;

  const HomeScreen({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
    this.hermesEnabled = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    // Initialize screens list
    _screens.addAll([
      const ConversationsScreen(),
      const PipelineScreen(),
      const SettingsScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudToLocalLLM'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              // Show app info
            },
            tooltip: 'App Info',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.work),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Conversations',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Start new conversation
              },
              child: const Text('New Conversation'),
            ),
          ],
        ),
      ),
    );
  }
}

class PipelineScreen extends StatelessWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Work Pipeline',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // View pipeline
              },
              child: const Text('View Pipeline'),
            ),
          ],
        ),
      ),
    );
  }
}
