import 'package:flutter/material.dart';

class SidebarSection extends StatefulWidget {
  final String title;
  final List<Widget> destinations;
  final bool initiallyExpanded;
  final bool collapsed;

  const SidebarSection({
    required this.title,
    required this.destinations,
    this.initiallyExpanded = true,
    this.collapsed = false,
    super.key,
  });

  @override
  State<SidebarSection> createState() => _SidebarSectionState();
}

class _SidebarSectionState extends State<SidebarSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    // When collapsed, just show destinations without title
    if (widget.collapsed) {
      return Column(
        children: widget.destinations.map((dest) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: dest,
          );
        }).toList(),
      );
    }

    // Normal mode: show title with expand/collapse
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: _isExpanded
              ? Column(
                  children: widget.destinations.map((dest) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: dest,
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
