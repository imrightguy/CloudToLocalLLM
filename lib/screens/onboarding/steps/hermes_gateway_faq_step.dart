import 'package:flutter/material.dart';

class HermesGatewayFAQStep extends StatefulWidget {
  const HermesGatewayFAQStep({super.key});

  @override
  State<HermesGatewayFAQStep> createState() => _HermesGatewayFAQStepState();
}

class _HermesGatewayFAQStepState extends State<HermesGatewayFAQStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway FAQ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ExpansionTile(
          title: const Text('What is hermes-agent?'),
          children: const [
            Text(
                'Hermes is a lightweight gateway for serving LLMs locally. It provides a REST/WS API for chat completions, model management, and more.'),
          ],
        ),
        ExpansionTile(
          title: const Text('How is Hermes different from OpenClaw?'),
          children: const [
            Text(
                'OpenClaw is a full-featured personal AI assistant platform with 20+ integrations. Hermes is a simpler, focused gateway specifically for LLM serving.'),
          ],
        ),
        ExpansionTile(
          title: const Text('Can I use both Hermes and OpenClaw?'),
          children: const [
            Text(
                'Yes! CloudToLocalLLM supports multiple backends. You can switch between OpenClaw and Hermes in settings.'),
          ],
        ),
        ExpansionTile(
          title: const Text('What models work with Hermes?'),
          children: const [
            Text(
                'Hermes supports any model that can be run via llama.cpp or similar. This includes Llama 3, Mistral, Mixtral, and many others.'),
          ],
        ),
        ExpansionTile(
          title: const Text('Is Hermes secure?'),
          children: const [
            Text(
                'Hermes supports API key authentication and can be run behind a reverse proxy with HTTPS. For local use, it\'s generally secure.'),
          ],
        ),
      ]).toList(),
    );
  }
}
