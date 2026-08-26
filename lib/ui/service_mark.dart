/// A service's logo, on its own brand colour.
///
/// The catalogue is `logic/services.dart`, generated from the PWA's. This is
/// only the drawing.
///
/// ── White on the brand colour, not the brand colour on white ──────────────
/// The marks are monochrome paths, so they are painted white on a tile filled
/// with the brand's own colour rather than the other way round. Netflix red on
/// a cream card is a red smear at 22px; a red tile with a white N is a Netflix
/// icon. It also means one path covers both themes — the tile carries the
/// colour, and the tile looks the same on either.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logic/services.dart';
import 'theme.dart';

class ServiceMark extends StatelessWidget {
  const ServiceMark({
    required this.serviceId,
    required this.name,
    this.size = 44,
    super.key,
  });

  /// Null, or something not in the catalogue, falls back to initials.
  final String? serviceId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final service = serviceFor(serviceId);

    final fill = service == null ? c.slate600 : Color(service.colour);
    final glyph = size * 0.58;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        // A squircle rather than a circle. Every one of these marks was drawn
        // for an app icon, and an app icon in a circle is a cropped app icon.
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: service == null
          ? Text(
              initialsFor(name),
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                color: c.text,
              ),
            )
          : SvgPicture.string(
              '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="$glyph" height="$glyph">
  <path d="${service.path}" fill="#FFFFFF" />
</svg>
''',
              width: glyph,
              height: glyph,
            ),
    );
  }
}
