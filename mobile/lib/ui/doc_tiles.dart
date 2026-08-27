/// Six tiles, one tap per document.
///
/// The glyphs are copied verbatim from `GLYPH` in `src/components/DocTiles.tsx`
/// for the same reason as the nav icons: a receipt with a torn edge and a
/// shield with a tick are this app's, and Material's nearest equivalents are a
/// different app's.
///
/// ── One target, and the question comes after ──────────────────────────────
/// A tile used to be two controls in one shape: the body opened the file
/// picker and a corner opened the camera. Two tap targets inside one 84-pixel
/// square, one of them fifteen pixels across, and no way to tell from looking
/// which half you were about to hit.
///
/// Tapping a tile now asks. Same as the photograph tile at the top of the item
/// form, and the same reason: the decision is "file a receipt", and where the
/// bytes come from is a detail of that, not a thing to aim at.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logic/attachments.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'theme.dart';

const Map<DocKind, String> _glyphs = {
  DocKind.receipt: 'M6 3.5h12v17l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4z M9 8h6M9 11.5h6',
  DocKind.warranty: 'M12 3l7 3v5.5c0 4.2-2.9 7.9-7 9-4.1-1.1-7-4.8-7-9V6z M9 12l2 2 4-4',
  DocKind.manual:
      'M4 4.5h6a2 2 0 012 2v13a2 2 0 00-2-2H4z M20 4.5h-6a2 2 0 00-2 2v13a2 2 0 012-2h6z',
  DocKind.photo: 'M3 5.5h18v13H3z M8 11a2 2 0 100-4 2 2 0 000 4z M4 17l5-4.5 4 3.5 3-2.5 4 3.5',
  DocKind.other:
      'M14 3v5h5M14 3H6.5A1.5 1.5 0 005 4.5v15A1.5 1.5 0 006.5 21h11a1.5 1.5 0 001.5-1.5V8z',
};

/// The odd one out: not a file, so not a DocKind glyph.
const String _linkGlyph = '''
<path d="M10 13.5a3.5 3.5 0 005 0l3-3a3.5 3.5 0 00-5-5l-1 1" />
<path d="M14 10.5a3.5 3.5 0 00-5 0l-3 3a3.5 3.5 0 005 5l1-1" />
''';

Widget _svg(String body, Color color, double size, double stroke) {
  final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  return SvgPicture.string(
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="$size" height="$size"
     fill="none" stroke="$hex" stroke-width="$stroke"
     stroke-linecap="round" stroke-linejoin="round">
$body
</svg>
''',
    width: size,
    height: size,
  );
}

/// A document's glyph, at whatever size. Used by the staged list too.
class DocGlyph extends StatelessWidget {
  const DocGlyph(this.kind, {required this.color, this.size = 22, super.key});

  final DocKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _svg('<path d="${_glyphs[kind]}" />', color, size, 1.7);
}

class DocTiles extends StatelessWidget {
  const DocTiles({required this.onPick, required this.onLink, super.key});

  /// The kind that was tapped. Where the bytes come from is asked afterwards.
  final void Function(DocKind kind) onPick;

  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    /*
      Three across, so six fall into two even rows.

      Five in a row of five was legible in the web version and the labels were
      down to nine pixels — which is legible in a screenshot and not on a bus.
    */
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final width = (box.maxWidth - gap * 2) / 3;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in docKindOrder)
              SizedBox(
                width: width,
                child: _Tile(
                  label: docKindLabels[kind]!,
                  glyph: '<path d="${_glyphs[kind]}" />',
                  onTap: () => onPick(kind),
                ),
              ),

            /*
              Linking to something on the web is a sixth tile rather than a
              text link underneath, because it is the same decision as the
              other five — what kind of thing is this — and the only difference
              is where the bytes come from. As a link it read as an
              afterthought, which is roughly how often it was used.
            */
            SizedBox(
              width: width,
              child: _Tile(
                label: 'On the web',
                glyph: _linkGlyph,
                onTap: onLink,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.glyph, required this.onTap});

  final String label;
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── Why the height and the fill are on a Positioned.fill ────────────────

      The tile used to be a bare `Material` as the Stack's first child, holding
      a `Container(height: 84)`. A Stack gives its non-positioned children
      LOOSE constraints, and a Container with a height but no width sizes
      itself to its child — so every tile came out as wide as the word inside
      it. Six tiles, six different widths, all hugging the left edge of the
      slot they were given, and nothing about the code said so: the SizedBox
      around it was the right width the whole time.

      A fixed-height SizedBox with the body filled into it is the shape that
      cannot do that.
    */
    /*
      ── Why the height and the fill are on their own box ───────────────────

      The tile used to be a bare `Material` inside a Stack, holding a
      `Container(height: 84)`. A Stack gives its non-positioned children LOOSE
      constraints, and a Container with a height but no width sizes itself to
      its child — so every tile came out as wide as the word inside it. Six
      tiles, six different widths, all hugging the left edge of the slot they
      had been given, and nothing in the code said so: the SizedBox around it
      was the right width the whole time.

      The Stack is gone with the camera corner, so this is now simply a box
      that states both of its dimensions.
    */
    return Material(
      // The field colour, not the card's. These sit on a card that is already
      // `slate700`, so a tile in the same colour was an outline with nothing
      // in it.
      color: c.slate800,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () {
          feedback(Cue.attach);
          onTap();
        },
        child: SizedBox(
          height: 84,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _svg(glyph, c.gold, 22, 1.7),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
