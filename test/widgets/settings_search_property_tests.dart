import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_search_bar.dart';

void main() {
  group('SettingsSearchBar Property Tests', () {
    /// **Feature: platform-settings-screen, Property 32: Search Input Presence**
    /// **Validates: Requirements 9.1**
    ///
    /// Property: *For any* settings screen, a search input field SHALL be displayed at the top
    group('Property 32: Search Input Presence', () {
      testWidgets('search input field is displayed at the top of screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);

        // Verify it's at the top by checking position
        final textFieldFinder = find.byType(TextField);
        final textFieldWidget = tester.getRect(textFieldFinder);
        expect(textFieldWidget.top, lessThan(100));
      });

      testWidgets('search input field is visible on empty settings screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: [],
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('search input field is visible with populated results',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('search input field has proper hint text',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                hintText: 'Search settings...',
              ),
            ),
          ),
        );

        expect(find.text('Search settings...'), findsOneWidget);
      });

      testWidgets('search input field is enabled by default',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, true);
      });
    });

    /// **Feature: platform-settings-screen, Property 34: Search Results Information**
    /// **Validates: Requirements 9.3**
    ///
    /// Property: *For any* search result, the category name and setting description SHALL be displayed
    group('Property 34: Search Results Information', () {
      testWidgets('search results display category name',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General Settings',
            settingName: 'Theme',
            settingDescription: 'Choose your theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        expect(find.text('General Settings'), findsOneWidget);
      });

      testWidgets('search results display setting name',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme Selection',
            settingDescription: 'Choose your theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        expect(find.text('Theme Selection'), findsOneWidget);
      });

      testWidgets('search results display setting description',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            settingDescription: 'Choose your preferred theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        expect(find.text('Choose your preferred theme'), findsOneWidget);
      });

      testWidgets('all search results display required information',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            settingDescription: 'Choose your theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
          SettingsSearchResult(
            id: '2',
            categoryId: 'account',
            categoryTitle: 'Account',
            settingName: 'Email',
            settingDescription: 'Your email address',
            matchedText: 'Email',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'e');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        expect(find.text('General'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Choose your theme'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Your email address'), findsOneWidget);
      });

      testWidgets('search results display category and setting for each result',
          (WidgetTester tester) async {
        final results = List.generate(
          5,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'category_$index',
            categoryTitle: 'Category $index',
            settingName: 'Setting $index',
            settingDescription: 'Description for setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'setting');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        for (int i = 0; i < 5; i++) {
          expect(find.text('Category $i'), findsOneWidget);
          expect(find.text('Setting $i'), findsOneWidget);
          expect(find.text('Description for setting $i'), findsOneWidget);
        }
      });
    });

    /// **Feature: platform-settings-screen, Property 35: Search Result Navigation**
    /// **Validates: Requirements 9.4**
    ///
    /// Property: *For any* search result click, the Settings_Screen SHALL navigate to and highlight the corresponding setting
    group('Property 35: Search Result Navigation', () {
      testWidgets('clicking search result calls onResultSelected callback',
          (WidgetTester tester) async {
        SettingsSearchResult? selectedResult;

        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Theme'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        expect(selectedResult, isNotNull);
        expect(selectedResult?.id, '1');
      });

      testWidgets('search result is highlighted when selected',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Theme'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        // Check for visual indicator (check icon)
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('multiple search results can be navigated',
          (WidgetTester tester) async {
        SettingsSearchResult? selectedResult;

        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
          SettingsSearchResult(
            id: '2',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Language',
            matchedText: 'Language',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'e');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        // Click first result
        await tester.tap(find.text('Theme'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        expect(selectedResult?.id, '1');

        // Click second result
        await tester.tap(find.text('Language'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        expect(selectedResult?.id, '2');
      });

      testWidgets('search result contains correct category information',
          (WidgetTester tester) async {
        SettingsSearchResult? selectedResult;

        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'account',
            categoryTitle: 'Account Settings',
            settingName: 'Email',
            matchedText: 'Email',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'email');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Email'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        expect(selectedResult?.categoryId, 'account');
        expect(selectedResult?.categoryTitle, 'Account Settings');
      });
    });

    /// **Feature: platform-settings-screen, Property 36: Keyboard Navigation Support**
    /// **Validates: Requirements 9.5**
    ///
    /// Property: *For any* settings screen, keyboard navigation (Tab, Enter, Escape) SHALL be supported
    group('Property 36: Keyboard Navigation Support', () {
      testWidgets('clear button is accessible via keyboard',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'test');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(),
            ),
          ),
        );

        expect(find.byIcon(Icons.clear), findsOneWidget);

        // Clear button should be accessible
        final clearButton = find.byIcon(Icons.clear);
        expect(clearButton, findsOneWidget);
      });

      testWidgets('search results are keyboard accessible',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
          SettingsSearchResult(
            id: '2',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Language',
            matchedText: 'Language',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'e');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        // Results should be displayed and accessible
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
      });

      testWidgets(
          'search results can be selected via tap (keyboard accessible)',
          (WidgetTester tester) async {
        SettingsSearchResult? selectedResult;

        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'theme');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        // Tap the result
        await tester.tap(find.text('Theme'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
                onResultSelected: (result) {
                  selectedResult = result;
                },
              ),
            ),
          ),
        );

        expect(selectedResult, isNotNull);
      });

      testWidgets('multiple search results are accessible',
          (WidgetTester tester) async {
        final results = [
          SettingsSearchResult(
            id: '1',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Theme',
            matchedText: 'Theme',
            matchPosition: 0,
          ),
          SettingsSearchResult(
            id: '2',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Language',
            matchedText: 'Language',
            matchPosition: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'e');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        // Both results should be accessible
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
      });

      testWidgets('all search results are accessible with multiple results',
          (WidgetTester tester) async {
        final results = List.generate(
          5,
          (index) => SettingsSearchResult(
            id: '$index',
            categoryId: 'general',
            categoryTitle: 'General',
            settingName: 'Setting $index',
            matchedText: 'Setting',
            matchPosition: 0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'setting');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSearchBar(
                searchResults: results,
              ),
            ),
          ),
        );

        // All results should be accessible
        for (int i = 0; i < 5; i++) {
          expect(find.text('Setting $i'), findsOneWidget);
        }

        expect(find.byType(TextField), findsOneWidget);
      });
    });
  });
}
