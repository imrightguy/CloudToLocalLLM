import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/widgets/settings/settings_search_bar.dart';

void main() {
  group('SettingsSearchBar', () {
    testWidgets('renders search input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('displays clear button when text is entered',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears search when clear button is tapped',
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

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('displays search results when query is entered',
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

      expect(find.text('Theme'), findsWidgets);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('shows result count when showResultCount is true',
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
              showResultCount: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(
              searchResults: results,
              showResultCount: true,
            ),
          ),
        ),
      );

      expect(find.text('Found 2 results'), findsOneWidget);
    });

    testWidgets('calls onSearchChanged callback when text changes',
        (WidgetTester tester) async {
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(
              onSearchChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(
              onSearchChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      expect(changedValue, 'test');
    });

    testWidgets('calls onResultSelected when result is tapped',
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
      expect(selectedResult?.settingName, 'Theme');
    });

    testWidgets('respects maxResults limit', (WidgetTester tester) async {
      final results = List.generate(
        15,
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
              maxResults: 5,
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
              maxResults: 5,
            ),
          ),
        ),
      );

      // Should show only 5 results
      expect(find.text('Found 15 results'), findsOneWidget);
      expect(find.text('Setting 0'), findsOneWidget);
      expect(find.text('Setting 4'), findsOneWidget);
      expect(find.text('Setting 5'), findsNothing);
    });

    testWidgets('disables search when enabled is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSearchBar(
              enabled: false,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // TextField should be disabled
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.enabled, false);
    });
  });

  group('SettingsSearchUtil', () {
    test('search returns empty list for empty query', () {
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

      final searchResults = SettingsSearchUtil.search('', results);
      expect(searchResults, isEmpty);
    });

    test('search finds results by setting name', () {
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

      final searchResults = SettingsSearchUtil.search('theme', results);
      expect(searchResults.length, 1);
      expect(searchResults[0].settingName, 'Theme');
    });

    test('search finds results by category name', () {
      final results = [
        SettingsSearchResult(
          id: '1',
          categoryId: 'general',
          categoryTitle: 'General Settings',
          settingName: 'Theme',
          matchedText: 'General',
          matchPosition: 0,
        ),
      ];

      final searchResults = SettingsSearchUtil.search('general', results);
      expect(searchResults.length, 1);
      expect(searchResults[0].categoryTitle, 'General Settings');
    });

    test('search finds results by description', () {
      final results = [
        SettingsSearchResult(
          id: '1',
          categoryId: 'general',
          categoryTitle: 'General',
          settingName: 'Theme',
          settingDescription: 'Choose your preferred theme',
          matchedText: 'theme',
          matchPosition: 0,
        ),
      ];

      final searchResults = SettingsSearchUtil.search('preferred', results);
      expect(searchResults.length, 1);
      expect(searchResults[0].settingName, 'Theme');
    });

    test('search is case-insensitive', () {
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

      final searchResults1 = SettingsSearchUtil.search('THEME', results);
      final searchResults2 = SettingsSearchUtil.search('theme', results);
      final searchResults3 = SettingsSearchUtil.search('ThEmE', results);

      expect(searchResults1.length, 1);
      expect(searchResults2.length, 1);
      expect(searchResults3.length, 1);
    });

    test('search sorts by relevance', () {
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
          categoryId: 'general',
          categoryTitle: 'Theme Settings',
          settingName: 'Color',
          matchedText: 'Theme',
          matchPosition: 0,
        ),
      ];

      final searchResults = SettingsSearchUtil.search('theme', results);
      expect(searchResults.length, 2);
      // Exact match should come first
      expect(searchResults[0].settingName, 'Theme');
    });

    test('highlightMatch returns original text when no match', () {
      final result = SettingsSearchUtil.highlightMatch('Hello World', 'xyz');
      expect(result, 'Hello World');
    });

    test('highlightMatch highlights matching text', () {
      final result = SettingsSearchUtil.highlightMatch('Hello World', 'World');
      expect(result.contains('**World**'), true);
    });

    test('highlightMatch is case-insensitive', () {
      final result = SettingsSearchUtil.highlightMatch('Hello World', 'world');
      expect(result.contains('**World**'), true);
    });
  });
}
