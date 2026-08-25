/// Scout's world, at 26px.
///
/// The paths are copied verbatim from `ICONS` in `src/components/BottomNav.tsx`
/// and rendered as SVG rather than swapped for the nearest Material glyph. That
/// is the whole point: the Material set had a house, a drawer, a calendar and a
/// cog — correct, and from a different app. **These are an oak, a hoard, a
/// season and a nut, which is the same four ideas told by a squirrel.**
///
/// ── The size and the stroke go together ───────────────────────────────────
/// A stroke scales with its viewBox, so drawing an icon larger buys no detail
/// at all — everything grows in proportion and the composition is exactly as
/// legible as it was. What buys detail is the *ratio* of pen to picture, which
/// is why these are 26 at stroke 1.7 rather than 21 at 2.0. That ratio is what
/// makes the hollow in the tree a hollow rather than a filled dot, and it is
/// the reason `_svg` takes the size and hard-codes the stroke.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logic/swipe.dart';

/// An oak with a hollow in it — where a squirrel actually lives, rather than a
/// house with a chimney.
const String _home = '''
<path d="M12 3.2c-3.1 0-5.4 2.2-5.4 4.8 0 .8.2 1.5.7 2.1-1.3.8-2 1.9-2 3.1 0 2.2 2 3.9 4.6 3.9h4.2c2.6 0 4.6-1.7 4.6-3.9 0-1.2-.7-2.3-2-3.1.5-.6.7-1.3.7-2.1 0-2.6-2.3-4.8-5.4-4.8z" />
<circle cx="12" cy="12" r="2.4" />
<path d="M12 17.1V21" />
''';

/// The hoard. Two acorns, not three: at 26px each one is nine pixels tall and a
/// pile reads as texture. Two still say "several".
const String _items = '''
<path d="M4.2 10.6c0-1.5 1.7-2.7 3.8-2.7s3.8 1.2 3.8 2.7z" />
<path d="M4.2 10.6h7.6" />
<path d="M5.4 10.6c0 3.3 1.2 5.7 2.6 5.7s2.6-2.4 2.6-5.7" />
<path d="M12.6 15.2c0-1.3 1.4-2.3 3.2-2.3s3.2 1 3.2 2.3z" />
<path d="M12.6 15.2h6.4" />
<path d="M13.6 15.2c0 2.8 1 4.8 2.2 4.8s2.2-2 2.2-4.8" />
''';

/// An acorn that comes round again.
///
/// There is no squirrel-native symbol for "every month", so the two-arrow cycle
/// carries the meaning — everyone already reads it — and the acorn inside makes
/// it ours without touching the part doing the work.
const String _subs = '''
<path d="M20.4 12a8.4 8.4 0 01-13.6 6.6" />
<path d="M3.6 12a8.4 8.4 0 0113.6-6.6" />
<path d="M3.4 8.2v3.8h3.8M20.6 15.8V12h-3.8" />
<path d="M9.4 10.4c0-1.2 1.2-2.1 2.6-2.1s2.6.9 2.6 2.1z" />
<path d="M9.4 10.4h5.2M10.3 10.4c0 2.4.8 4.1 1.7 4.1s1.7-1.7 1.7-4.1" />
''';

/// Scout himself, face on.
///
/// An ID card with a squirrel in the photo box was drawn first and thrown away
/// on arithmetic: the card needs eighteen of the twenty-four units, the photo
/// box gets a third of that, and the squirrel inside lands at about five pixels
/// — a grey smudge in a rectangle. **Anything drawn inside something else at
/// 26px is drawn at nothing.**
///
/// The eyes and nose are filled rather than stroked, because a 2px circle
/// outlined with a 1.7px pen is a solid dot anyway and filling it makes that a
/// decision instead of an accident.
const String _papers = '''
<path d="M8.7 7.1C7.5 5.4 7.1 3.7 7.8 3.1c.8-.6 2.3.3 3.3 1.9" />
<path d="M15.3 7.1c1.2-1.7 1.6-3.4.9-4-.8-.6-2.3.3-3.3 1.9" />
<path d="M12 4.6c-4 0-7.1 3-7.1 7 0 4.3 3.2 7.7 7.1 7.7s7.1-3.4 7.1-7.7c0-4-3.1-7-7.1-7z" />
<circle cx="9.4" cy="11.2" r="1.1" fill="CURRENT" stroke="none" />
<circle cx="14.6" cy="11.2" r="1.1" fill="CURRENT" stroke="none" />
<circle cx="12" cy="14.4" r=".9" fill="CURRENT" stroke="none" />
''';

/// A nut, in both senses. The pun is free, and the hexagon is the most robust
/// shape in the set — legible at 21px and still legible at 12.
const String _settings = '''
<path d="M12 2.8 20 7.4v9.2L12 21.2 4 16.6V7.4z" />
<circle cx="12" cy="12" r="3" />
''';

const Map<Tab, String> _paths = {
  Tab.home: _home,
  Tab.items: _items,
  Tab.subs: _subs,
  Tab.papers: _papers,
  Tab.settings: _settings,
};

/// One of Scout's five, in a given colour.
///
/// The colour is baked into the SVG string rather than applied with a
/// `ColorFilter`, because three of these shapes are filled and the rest are
/// stroked — a blanket filter would flatten the papers icon's eyes into the
/// same weight as its outline and lose the distinction the note above is about.
class NavIcon extends StatelessWidget {
  const NavIcon(this.tab, {required this.color, this.size = 26, super.key});

  final Tab tab;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final body = _paths[tab]!.replaceAll('CURRENT', hex);

    return SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="$size" height="$size"
     fill="none" stroke="$hex" stroke-width="1.7"
     stroke-linecap="round" stroke-linejoin="round">
$body
</svg>
''',
      width: size,
      height: size,
    );
  }
}
