/// Six tiles, one tap per document.
///
/// The glyphs are copied verbatim from `GLYPH` in `src/components/DocTiles.tsx`
/// for the same reason as the nav icons: a receipt with a torn edge and a
/// shield with a tick are this app's, and Material's nearest equivalents are a
/// different app's.
///
/// ── A tile is two targets in one shape ────────────────────────────────────
/// The body opens the file picker; the corner opens the camera. An earlier
/// version relied on the file picker offering "Take photo" itself — it does on
/// some devices and goes straight to the gallery on others, which loses the
/// camera entirely on exactly the phones where photographing a receipt is the
/// only way it will ever get filed.
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

const String _cameraGlyph = '''
<path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5z" />
<circle cx="12" cy="13" r="3.4" />
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

/// Where the bytes come from.
enum DocSource { files, camera }

class DocTiles extends StatelessWidget {
  const DocTiles({required this.onPick, required this.onLink, super.key});

  final void Function(DocKind kind, DocSource source) onPick;
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
                  onTap: () => onPick(kind, DocSource.files),
                  onCamera: () => onPick(kind, DocSource.camera),
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
  const _Tile({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.onCamera,
  });

  final String label;
  final String glyph;
  final VoidCallback onTap;

  /// Null on the link tile, which has nothing to photograph.
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Stack(
      children: [
        Material(
          color: c.slate700,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () {
              feedback(Cue.attach);
              onTap();
            },
            child: Container(
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: c.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _svg(glyph, c.gold, 22, 1.7),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        /*
          The camera corner sits over the tile rather than inside it.

          Two tap targets in one shape: the body picks a file, the corner
          shoots one. Nesting the second inside the first is what the web
          version could not do — nested buttons are invalid HTML — and it is
          not much better here, because an InkWell inside an InkWell gives two
          ripples for one tap.
        */
        if (onCamera != null)
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: () {
                  feedback(Cue.attach);
                  onCamera!();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _svg(_cameraGlyph, c.muted, 15, 1.8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
