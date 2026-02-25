import 'package:flutter/material.dart';

class ResourceOverviewScreen extends StatelessWidget {
  const ResourceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ResourceCard(
          title: 'Compute (CPU)',
          value: '12%',
          status: 'Healthy',
          icon: Icons.speed,
          color: Colors.green,
        ),
        _ResourceCard(
          title: 'Memory (RAM)',
          value: '45%',
          status: 'Normal',
          icon: Icons.memory,
          color: Colors.blue,
        ),
        _ResourceCard(
          title: 'Storage (Disk)',
          value: '97GB / 952GB',
          status: '11% Used',
          icon: Icons.storage,
          color: Colors.orange,
        ),
        _ResourceCard(
          title: 'Network (Tunnel)',
          value: 'Active',
          status: 'Latency: 45ms',
          icon: Icons.lan,
          color: Colors.green,
        ),
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final Color color;

  const _ResourceCard({
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(status,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
