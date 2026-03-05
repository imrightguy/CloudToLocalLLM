/// Pop-Out Window Model
///
/// Represents a pop-out window state for OpenClaw Gateway sections.
/// Each window can be independently positioned and sized by the user.
///
/// Features:
/// - Window identification via unique ID
/// - Section name mapping to Gateway sections
/// - Branch index for multiple instances of same section
/// - Visibility state management
/// - Position and size persistence
library;

import 'package:flutter/widgets.dart';

/// Model representing a pop-out window state
class PopOutWindow {
  /// Unique identifier for this window (typically sectionName)
  final String id;

  /// Name of the section this window displays
  final String sectionName;

  /// Branch index for multiple instances of the same section
  final int branchIndex;

  /// Whether the window is currently visible
  final bool isVisible;

  /// Optional window position (relative to screen)
  final Offset? position;

  /// Optional window size
  final Size? size;

  const PopOutWindow({
    required this.id,
    required this.sectionName,
    required this.branchIndex,
    this.isVisible = true,
    this.position,
    this.size,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sectionName': sectionName,
      'branchIndex': branchIndex,
      'isVisible': isVisible,
      'position': position != null
          ? {
              'dx': position!.dx,
              'dy': position!.dy,
            }
          : null,
      'size': size != null
          ? {
              'width': size!.width,
              'height': size!.height,
            }
          : null,
    };
  }

  /// Create from JSON
  factory PopOutWindow.fromJson(Map<String, dynamic> json) {
    return PopOutWindow(
      id: json['id'] as String,
      sectionName: json['sectionName'] as String,
      branchIndex: json['branchIndex'] as int,
      isVisible: json['isVisible'] as bool? ?? true,
      position: json['position'] != null
          ? Offset(
              (json['position']['dx'] as num).toDouble(),
              (json['position']['dy'] as num).toDouble(),
            )
          : null,
      size: json['size'] != null
          ? Size(
              (json['size']['width'] as num).toDouble(),
              (json['size']['height'] as num).toDouble(),
            )
          : null,
    );
  }

  /// Create a copy with updated values
  PopOutWindow copyWith({
    String? id,
    String? sectionName,
    int? branchIndex,
    bool? isVisible,
    Offset? position,
    Size? size,
    bool clearPosition = false,
    bool clearSize = false,
  }) {
    return PopOutWindow(
      id: id ?? this.id,
      sectionName: sectionName ?? this.sectionName,
      branchIndex: branchIndex ?? this.branchIndex,
      isVisible: isVisible ?? this.isVisible,
      position: clearPosition ? null : (position ?? this.position),
      size: clearSize ? null : (size ?? this.size),
    );
  }

  @override
  String toString() {
    return 'PopOutWindow(id: $id, sectionName: $sectionName, '
        'branchIndex: $branchIndex, isVisible: $isVisible, '
        'position: $position, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PopOutWindow &&
        other.id == id &&
        other.sectionName == sectionName &&
        other.branchIndex == branchIndex &&
        other.isVisible == isVisible;
  }

  @override
  int get hashCode {
    return Object.hash(id, sectionName, branchIndex, isVisible);
  }
}
