import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/app_initialization_service.dart';
import '../services/auth_service.dart';
import '../services/streaming_chat_service.dart';
import 'home/home_layout.dart';

/// Modern ChatGPT-like chat interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _initializedWithContext = false;
  StreamingChatService? _chatService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedWithContext) return;
    _initializedWithContext = true;

    try {
      _chatService = context.read<StreamingChatService>();
      _chatService?.addListener(_onChatChanged);
    } catch (e) {
      debugPrint(
          '[HomeScreen] StreamingChatService not available, using null: $e');
    }

    final appInit = context.read<AppInitializationService>();
    scheduleMicrotask(() => appInit.initializeWithContext(context));
  }

  @override
  void dispose() {
    _chatService?.removeListener(_onChatChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    // Automatically scroll to bottom on new messages or streaming updates
    if (_scrollController.hasClients && (_chatService?.isStreaming ?? false)) {
      scheduleMicrotask(() {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return ValueListenableBuilder<bool>(
      valueListenable: authService.areAuthenticatedServicesLoaded,
      builder: (context, areServicesLoaded, child) {
        debugPrint(
            '[HomeScreen] areAuthenticatedServicesLoaded: $areServicesLoaded');
        if (!areServicesLoaded) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < AppConfig.mobileBreakpoint;

            return HomeLayout(
              isCompact: isCompact,
              scrollController: _scrollController,
              onSendMessage: _handleSendMessage,
            );
          },
        );
      },
    );
  }

  Future<void> _handleSendMessage(
    StreamingChatService chatService,
    String message,
  ) async {
    await chatService.sendMessage(message);
    scheduleMicrotask(() {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0, // Bottom is 0 when ListView is reversed
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
