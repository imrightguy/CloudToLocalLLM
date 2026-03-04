import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// UnifiedSettingsScreen - Acts as a redirect to default settings category
/// This screen redirects to /settings/general when accessed via /settings
/// It's kept for backwards compatibility with existing navigation code
class UnifiedSettingsScreen extends StatefulWidget {
  final String? initialCategory;

  const UnifiedSettingsScreen({super.key, this.initialCategory});

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect to appropriate category route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final category = widget.initialCategory ?? 'general';
        context.go('/settings/$category');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while redirecting
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
