import 'package:flutter/material.dart';

class RefreshableScreen extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final String? errorMessage;

  const RefreshableScreen({
    required this.child,
    this.onRefresh,
    this.errorMessage,
    super.key,
  });

  @override
  State<RefreshableScreen> createState() => _RefreshableScreenState();
}

class _RefreshableScreenState extends State<RefreshableScreen> {
  bool _isRefreshing = false;
  String? _error;

  @override
  void didUpdateWidget(RefreshableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      setState(() => _error = widget.errorMessage);
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await widget.onRefresh?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childWithError = _error != null
        ? Column(
            children: [
              widget.child,
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
            ],
          )
        : widget.child;

    final content = Stack(
      children: [
        childWithError,
        if (_isRefreshing)
          Positioned(
            top: 8,
            right: 8,
            child: CircularProgressIndicator(),
          ),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: content,
      );
    }

    return content;
  }
}
