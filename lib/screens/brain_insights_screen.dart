import 'package:flutter/material.dart';
import '../components/brain_insight_widget.dart';
import '../components/app_logo.dart';

/// Screen for visualizing the internal "thoughts" and relational logs of the Local Brain.
class BrainInsightsScreen extends StatelessWidget {
  const BrainInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            const AppLogo.small(),
            const SizedBox(width: 12),
            const Text('Brain Insights'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: const BrainInsightWidget(),
    );
  }
}
