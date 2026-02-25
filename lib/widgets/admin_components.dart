/// Admin Center UI Components
///
/// This file exports all reusable admin UI components for easy importing.
///
/// Usage:
/// ```dart
/// import 'package:CloudToLocalLLM/widgets/admin_components.dart';
/// ```
///
/// This gives you access to:
/// - AdminCard
/// - AdminTable, AdminTableColumn
/// - AdminSearchBar
/// - AdminFilterChip, AdminDropdownFilter
/// - AdminStatCard, AdminStatCardGrid
/// - AdminStyles
/// - AdminAccessibility
/// - AdminResponsive and all responsive components

library;

// Core components
export 'admin_card.dart';
export 'admin_table.dart';
export 'admin_search_bar.dart';
export 'admin_filter_chip.dart';
export 'admin_stat_card.dart';

// Utilities
export 'admin_styles.dart';
export 'admin_accessibility.dart';
export 'admin_responsive.dart';

// Also export theme for convenience
export '../config/theme.dart';
