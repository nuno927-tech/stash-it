/// The design tokens, ported from `src/styles/tokens.css`.
///
/// ── One source, two apps ──────────────────────────────────────────────────
/// Every colour in the PWA comes from that file and no component hard-codes a
/// hex value. The same rule holds here: nothing outside this file should write
/// a `Color(0x...)`, because the moment two places know what gold is, only one
/// of them gets changed.
///
/// ── Read the slate ramp as elevation, not as colour ───────────────────────
/// `slate900` is always the furthest surface from the reader and `slate600` the
/// nearest, **in both themes**. That is why the light values look like a
/// contradiction — 900 is the palest there, because paper recedes by getting
/// lighter and a screen recedes by getting darker.
///
/// ── The light theme is not an inversion ───────────────────────────────────
/// Gold is darkened to #9a6b0f to hold contrast on white, and the state colours
/// are pulled down so they stay legible as text on their own washes. Inverting
/// the dark palette directly produced a gold that failed contrast on every
/// button it appeared on — which is the note that matters most here, because
/// inverting is exactly what somebody would try first.
library;

import 'package:flutter/material.dart';

import '../models/settings.dart';

/// Everything the tokens file holds that Material's `ColorScheme` has no slot
/// for. Reached with `StashColors.of(context)`.
@immutable
class StashColors extends ThemeExtension<StashColors> {
  const StashColors({
    required this.slate900,
    required this.slate800,
    required this.slate700,
    required this.slate600,
    required this.line,
    required this.gold,
    required this.moss,
    required this.honey,
    required this.ember,
    required this.washMoss,
    required this.washHoney,
    required this.washEmber,
    required this.washGold,
    required this.washGoldLine,
    required this.washGoldSoft,
    required this.text,
    required this.muted,
    required this.onGold,
    required this.scrim,
    required this.hairline,
    required this.sheen,
    required this.goldFall,
  });

  /// Surfaces, furthest to nearest.
  final Color slate900;
  final Color slate800;
  final Color slate700;
  final Color slate600;
  final Color line;

  /// Brand, and the three warranty states.
  final Color gold;
  final Color moss;
  final Color honey;
  final Color ember;

  /// The washes that sit behind chips and notices.
  final Color washMoss;
  final Color washHoney;
  final Color washEmber;
  final Color washGold;
  final Color washGoldLine;
  final Color washGoldSoft;

  final Color text;
  final Color muted;

  /// Ink used on gold — the wordmark, the button labels, the add button's glyph.
  final Color onGold;

  final Color scrim;

  /*
    Two tokens for one effect: a raised surface, lit from above.

    A flat fill on a dark background reads as a hole in the page. Real objects
    catch light on their top edge, so a panel gets a barely-there gradient and
    a hairline that is brightest where the light would land. Both are
    deliberately almost invisible — the moment you can point at the highlight it
    has stopped looking like a material and started looking like a bevel, which
    is the 2009 version of this idea.

    Two values rather than one because the themes need opposite signs: white at
    6% lifts a dark panel, and on paper the same trick is a shadow.
  */
  final Color hairline;
  final Gradient sheen;

  /// The bar fill. Solid at the top, thinning toward the baseline, so a column
  /// reads as a measured quantity rather than a painted block.
  final Gradient goldFall;

  static StashColors of(BuildContext context) =>
      Theme.of(context).extension<StashColors>()!;

  @override
  StashColors copyWith() => this;

  /*
    Themes are switched, not blended.

    Material lerps extensions during a theme animation, and a half-way palette
    is a screen nobody designed — grey-brown surfaces, a gold that is neither
    legible on dark nor on light. Snapping at the midpoint means the transition
    is a single cut, which is what the PWA does by swapping a `data-theme`
    attribute.
  */
  @override
  StashColors lerp(ThemeExtension<StashColors>? other, double t) =>
      t < 0.5 ? this : (other as StashColors? ?? this);
}

const StashColors _dark = StashColors(
  slate900: Color(0xFF0D0F12),
  slate800: Color(0xFF15181D),
  slate700: Color(0xFF1F242B),
  slate600: Color(0xFF2C333C),
  line: Color(0xFF39414B),
  gold: Color(0xFFF2B33D),
  moss: Color(0xFF5FBF7E),
  honey: Color(0xFFF2CE3D),
  ember: Color(0xFFE05A44),
  washMoss: Color(0x265FBF7E),
  washHoney: Color(0x26F2CE3D),
  washEmber: Color(0x26E05A44),
  washGold: Color(0x29F2B33D),
  washGoldLine: Color(0x73F2B33D),
  washGoldSoft: Color(0x14F2B33D),
  text: Color(0xFFEAEDF0),
  muted: Color(0xFF8B949E),
  onGold: Color(0xFF15181D),
  scrim: Color(0xB80D0F12),
  hairline: Color(0x12FFFFFF),
  sheen: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0BFFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.62],
  ),
  goldFall: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF2B33D), Color(0x59F2B33D)],
  ),
);

const StashColors _light = StashColors(
  slate900: Color(0xFFF4F2ED),
  slate800: Color(0xFFFFFFFF),
  slate700: Color(0xFFF1EFE9),
  slate600: Color(0xFFE4E1D8),
  line: Color(0xFFD5D1C6),
  gold: Color(0xFF9A6B0F),
  moss: Color(0xFF2F7D4F),
  honey: Color(0xFF8A6A08),
  ember: Color(0xFFB83C28),
  washMoss: Color(0x212F7D4F),
  washHoney: Color(0x218A6A08),
  washEmber: Color(0x1FB83C28),
  washGold: Color(0x219A6B0F),
  washGoldLine: Color(0x619A6B0F),
  washGoldSoft: Color(0x129A6B0F),
  text: Color(0xFF22252A),
  muted: Color(0xFF6B7079),
  onGold: Color(0xFFFFFFFF),
  scrim: Color(0xD1FFFFFF),
  hairline: Color(0x1722252A),
  sheen: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.70],
  ),
  goldFall: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF9A6B0F), Color(0x669A6B0F)],
  ),
);

/// Radii, from the `:root` block of tokens.css.
class Radii {
  static const double lg = 22;
  static const double md = 16;
  static const double sm = 12;
  static const double pill = 99;
}

/*
  ── Type ────────────────────────────────────────────────────────────────────

  Bricolage Grotesque for display, Inter for body, JetBrains Mono for figures —
  the same three the PWA loads. Bundled as files rather than fetched: this app
  has no network at all, and a first launch that falls back to the system face
  and then reflows is worse than a slightly larger download.

  The names are declared here and the files in pubspec.yaml. Until they are
  added, Flutter falls back silently — which is why `fontFamily` is a constant
  rather than typed at each use.
*/
const String fontDisplay = 'BricolageGrotesque';
const String fontBody = 'Inter';
const String fontMono = 'JetBrainsMono';

ThemeData stashTheme({required bool dark}) {
  final c = dark ? _dark : _light;

  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: c.gold,
    onPrimary: c.onGold,
    secondary: c.moss,
    onSecondary: c.onGold,
    error: c.ember,
    onError: dark ? c.slate900 : Colors.white,
    // `slate800` rather than `slate900`: the app's own body sits one step
    // nearer the reader than the page behind it, which is what gives the
    // 480-wide column its edges on a big screen.
    surface: c.slate800,
    onSurface: c.text,
    surfaceContainerHighest: c.slate700,
    outline: c.line,
  );

  final base = dark ? ThemeData.dark() : ThemeData.light();

  return base.copyWith(
    colorScheme: scheme,

    /*
      `slate800`, not `slate900`.

      The PWA paints `body` with 900 and the `.app` column inside it with 800 —
      but that column is 480 wide with the page showing either side of it,
      which only happens on a desktop browser. On a phone the app IS the
      viewport, so the surface somebody actually sees is 800: white in the
      light theme, and one step nearer than the page behind it in the dark one.

      Using 900 here made every screen the colour of the gap around the app
      rather than the colour of the app.
    */
    scaffoldBackgroundColor: c.slate800,
    canvasColor: c.slate800,
    dividerColor: c.line,
    extensions: [c],

    textTheme: base.textTheme.apply(
      fontFamily: fontBody,
      bodyColor: c.text,
      displayColor: c.text,
    ).copyWith(
      // The masthead and the section headings are the display face; everything
      // else is Inter. Mixing them per-widget is how a screen ends up with
      // three typefaces by accident.
      headlineSmall: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w800,
        fontSize: 27,
        letterSpacing: -0.68,
        height: 1.05,
        color: c.text,
      ),
      titleLarge: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w800,
        fontSize: 25,
        letterSpacing: -0.5,
        color: c.text,
      ),
      titleMedium: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, color: c.text),
      bodySmall: TextStyle(fontFamily: fontBody, color: c.muted),
      labelSmall: TextStyle(fontFamily: fontBody, color: c.muted),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: c.slate800,
      foregroundColor: c.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        letterSpacing: -0.4,
        color: c.text,
      ),
    ),

    cardTheme: CardThemeData(
      color: c.slate700,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.hairline),
      ),
    ),

    listTileTheme: ListTileThemeData(
      textColor: c.text,
      iconColor: c.muted,
      subtitleTextStyle: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.slate700,
      isDense: true,
      labelStyle: TextStyle(color: c.muted),
      hintStyle: TextStyle(color: c.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.gold, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: c.slate700,
      selectedColor: c.washGold,
      side: BorderSide(color: c.line),
      labelStyle: TextStyle(fontFamily: fontBody, color: c.text),
      shape: const StadiumBorder(),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.gold,
      foregroundColor: c.onGold,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.slate800,
      indicatorColor: c.washGold,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: fontBody, fontSize: 11, color: c.muted),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: c.slate700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onGold : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.gold : c.slate600,
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.gold),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
  );
}

/// The user's choice, as Flutter wants it.
///
/// `null` for `system` rather than a third `ThemeData`: Flutter already knows
/// the device setting and will re-resolve when it changes, which is what
/// "match my device" has to mean if it is to keep being true after dusk.
ThemeMode themeModeOf(ThemeChoice? choice) => switch (choice) {
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
      // Null is a record written before the preference existed, and it has no
      // opinion — see the note on the nullable fields in models/settings.dart.
      ThemeChoice.system || null => ThemeMode.system,
    };
