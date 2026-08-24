/// The one widget test, and it is deliberately small.
///
///   flutter test test/widget_test.dart
///
/// `main()` opens an encrypted database through the platform keystore, which
/// does not exist in a test harness — so the app cannot be booted here, and
/// pretending otherwise with a pile of mocks would be testing the mocks. What
/// is worth checking is that the screen renders against a real in-memory
/// database, because that is where a null-safety mistake or a bad `switch`
/// would show up.
///
/// ── Two harness rules this file has to obey ───────────────────────────────
/// **No `pumpAndSettle`.** The screen shows a spinner while its query runs,
/// and a spinner is an animation that never settles — `pumpAndSettle` waits
/// for the frames to stop and they never do. Explicit `pump`s with durations
/// advance the clock a known amount instead.
///
/// **The database is closed inside the test, not in `tearDown`.** The widget
/// harness asserts that no timer outlives the widget tree, and it does that
/// check at the end of the test body — before `tearDown` runs. A database left
/// open is a timer left pending, and the failure names neither.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/main.dart';
import 'package:stash_it/models/types.dart';

void main() {
  /// Renders the app, lets the stream and the query land, and hands back the
  /// database so the caller can close it before the harness checks.
  Future<StashDatabase> show(WidgetTester tester, {Item? item}) async {
    final db = openInMemory();
    if (item != null) await Repository(db).createItem(item);

    await tester.pumpWidget(StashItApp(db: db));

    // One frame to build, then enough time for the stream and the FutureBuilder
    // behind it to deliver.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    return db;
  }

  testWidgets('an empty database says so rather than showing an empty list',
      (tester) async {
    final db = await show(tester);

    expect(find.textContaining('Nothing here yet'), findsOneWidget);

    await db.close();
  });

  testWidgets('and an item that is in it appears', (tester) async {
    final db = await show(
      tester,
      item: const Item(id: '', propertyId: 'default', name: 'Bosch Dishwasher'),
    );

    expect(find.text('Bosch Dishwasher'), findsOneWidget);
    // No purchase date and no term, so there is nothing to count down to —
    // and the tile has to say that rather than showing a blank subtitle.
    expect(find.text('No cover recorded'), findsOneWidget);

    await db.close();
  });

  testWidgets('the restore button is reachable', (tester) async {
    final db = await show(tester);

    expect(find.byIcon(Icons.download), findsOneWidget);

    await db.close();
  });
}
