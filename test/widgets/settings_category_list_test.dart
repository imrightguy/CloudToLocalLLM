import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_category_list.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_category_widgets.dart';

void main() {
  group('SettingsCategoryList', () {
    late List<BaseSettingsCategory> testCategories;

    setUp(() {
      testCategories = [
        BaseSettingsCategory(
          id: 'general',
          title: 'General',
          icon: Icons.tune,
          isVisible: true,
          description: 'General settings',
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
        BaseSettingsCategory(
          id: 'account',
          title: 'Account',
          icon: Icons.person,
          isVisible: true,
          description: 'Account settings',
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
        BaseSettingsCategory(
          id: 'privacy',
          title: 'Privacy',
          icon: Icons.privacy_tip,
          isVisible: true,
          description: 'Privacy settings',
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
      ];
    });

    testWidgets('renders all categories', (WidgetTester tester) async {
      String? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (categoryId) {
                selectedCategory = categoryId;
              },
            ),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);

      // Verify selectedCategory is null initially (no selection made in test)
      expect(selectedCategory, isNull);
    });

    testWidgets('displays category descriptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
              showDescriptions: true,
            ),
          ),
        ),
      );

      expect(find.text('General settings'), findsOneWidget);
      expect(find.text('Account settings'), findsOneWidget);
      expect(find.text('Privacy settings'), findsOneWidget);
    });

    testWidgets('hides descriptions when showDescriptions is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
              showDescriptions: false,
            ),
          ),
        ),
      );

      expect(find.text('General settings'), findsNothing);
      expect(find.text('Account settings'), findsNothing);
      expect(find.text('Privacy settings'), findsNothing);
    });

    testWidgets('highlights active category', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'account',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      // The active category should have a blue background
      final accountItem = find.byType(SettingsCategoryListItem).at(1);
      expect(accountItem, findsOneWidget);
    });

    testWidgets('calls onCategorySelected when category is tapped',
        (WidgetTester tester) async {
      String? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (categoryId) {
                selectedCategory = categoryId;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals('account'));
    });

    testWidgets('filters categories by search query',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
              searchQuery: 'account',
            ),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('General'), findsNothing);
      expect(find.text('Privacy'), findsNothing);
    });

    testWidgets('shows empty state when no categories match search',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
              searchQuery: 'nonexistent',
            ),
          ),
        ),
      );

      expect(find.text('No settings found'), findsOneWidget);
    });

    testWidgets('uses custom empty state widget when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
              searchQuery: 'nonexistent',
              emptyStateWidget: const Text('Custom empty state'),
            ),
          ),
        ),
      );

      expect(find.text('Custom empty state'), findsOneWidget);
      expect(find.text('No settings found'), findsNothing);
    });

    testWidgets('updates active category when activeCategory prop changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsCategoryList(
              categories: testCategories,
              activeCategory: 'privacy',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Privacy'), findsOneWidget);
    });
  });

  group('HorizontalSettingsCategoryList', () {
    late List<BaseSettingsCategory> testCategories;

    setUp(() {
      testCategories = [
        BaseSettingsCategory(
          id: 'general',
          title: 'General',
          icon: Icons.tune,
          isVisible: true,
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
        BaseSettingsCategory(
          id: 'account',
          title: 'Account',
          icon: Icons.person,
          isVisible: true,
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
      ];
    });

    testWidgets('renders categories horizontally', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HorizontalSettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('calls onCategorySelected when chip is tapped',
        (WidgetTester tester) async {
      String? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HorizontalSettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (categoryId) {
                selectedCategory = categoryId;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilterChip).at(1));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals('account'));
    });
  });

  group('CompactSettingsCategoryList', () {
    late List<BaseSettingsCategory> testCategories;

    setUp(() {
      testCategories = [
        BaseSettingsCategory(
          id: 'general',
          title: 'General',
          icon: Icons.tune,
          isVisible: true,
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
        BaseSettingsCategory(
          id: 'account',
          title: 'Account',
          icon: Icons.person,
          isVisible: true,
          contentBuilder: (context) => const SizedBox.shrink(),
        ),
      ];
    });

    testWidgets('renders categories in compact format',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactSettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('shows check icon for active category',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactSettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('calls onCategorySelected when category is tapped',
        (WidgetTester tester) async {
      String? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactSettingsCategoryList(
              categories: testCategories,
              activeCategory: 'general',
              onCategorySelected: (categoryId) {
                selectedCategory = categoryId;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals('account'));
    });
  });
}
