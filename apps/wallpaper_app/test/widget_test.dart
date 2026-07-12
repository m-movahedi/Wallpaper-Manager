import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens the add source chooser', (tester) async {
    await tester.pumpWidget(const WallpaperApp());

    expect(find.text('Your space'), findsOneWidget);
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();

    expect(find.text('RSS or Atom feed'), findsOneWidget);
    expect(find.text('JSON feed'), findsOneWidget);
    expect(find.text('Google Photos'), findsOneWidget);
    expect(find.text('Local album'), findsOneWidget);
  });

  testWidgets('adding a source creates a library collection', (tester) async {
    await tester.pumpWidget(const WallpaperApp());

    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON feed'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Daily landscapes');
    await tester.enterText(fields.at(1), 'https://example.com/feed.xml');
    await tester.tap(find.widgetWithText(FilledButton, 'Add source').last);
    await tester.pumpAndSettle();

    expect(find.text('Daily landscapes'), findsOneWidget);
    expect(find.text('0 items • 1 source'), findsOneWidget);
  });

  testWidgets('library sources survive an app restart', (tester) async {
    await tester.pumpWidget(const WallpaperApp());
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON feed'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Persistent collection');
    await tester.enterText(fields.at(1), 'https://example.com/feed.json');
    await tester.tap(find.widgetWithText(FilledButton, 'Add source').last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const WallpaperApp());
    await tester.pumpAndSettle();

    expect(find.text('Persistent collection'), findsOneWidget);
  });
}
