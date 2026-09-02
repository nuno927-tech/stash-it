/// When the app splits itself in two, and when it must not.
///
///   flutter test test/tablet_layout_test.dart
///
/// The whole tablet layout hangs off one predicate. Get it wrong in the
/// generous direction and a phone held sideways shows a list of eight rows
/// beside a record with none of it visible; get it wrong in the mean direction
/// and the feature never appears on the device it was built for.
///
/// It is also the sort of rule that is quietly rewritten by the next person to
/// touch it — `width` instead of `shortestSide` looks like a tidy-up and turns
/// every phone in landscape into a tablet. So the four cases are pinned.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/ui/layout.dart';

void main() {
  /// Asks the predicates about a screen of exactly this size.
  Future<(bool tablet, bool split)> at(WidgetTester tester, Size size) async {
    late bool tablet;
    late bool split;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            tablet = isTablet(context);
            split = splitView(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    return (tablet, split);
  }

  group('what counts as a tablet', () {
    testWidgets('a phone is not one, whichever way up it is', (tester) async {
      // A Pixel 8, both ways. The landscape case is the one that matters:
      // 844 across is wider than a small tablet and it is still a phone.
      expect(await at(tester, const Size(412, 915)), (false, false));
      expect(await at(tester, const Size(915, 412)), (false, false));
    });

    testWidgets('a tablet is one in portrait too', (tester) async {
      /*
        Tablet, but not split.

        Both halves of that are deliberate. `isTablet` is about the DEVICE, so
        it cannot change when somebody turns it over — it is measured on the
        shortest side for exactly that reason.

        The split is about the SPACE, and a tablet stood upright is a column.
        A column of full-width rows is the right way to read a list you are
        scanning, and cutting it in half to put a record beside it would be
        using the width because it is there rather than because it helps.
      */
      expect(await at(tester, const Size(800, 1280)), (true, false));
    });

    testWidgets('a tablet turned sideways is where the split happens',
        (tester) async {
      expect(await at(tester, const Size(1280, 800)), (true, true));
    });
  });

  group('the boundary', () {
    testWidgets('600 on the short edge is a tablet, 599 is not',
        (tester) async {
      /*
        Android's own line, so a device this app calls a tablet is the same
        device the Play Console does. Pinned because the number is arbitrary
        the way a border is arbitrary: nothing about 599 is different, and
        everything about disagreeing with the platform is.
      */
      expect(await at(tester, const Size(1000, 600)), (true, true));
      expect(await at(tester, const Size(1000, 599)), (false, false));
    });

    testWidgets('exactly square is not sideways', (tester) async {
      // `width > height`, not `>=`. A square is not landscape, and a foldable
      // opened flat should not get a layout built for a stand.
      expect(await at(tester, const Size(900, 900)), (true, false));
    });
  });
}
