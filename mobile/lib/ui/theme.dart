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
    required this.card,
    required this.field,
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

  /*
    ── Card and field, and why they are not slate700 and slate800 ────────────

    Every card in the app was `slate700` with a hairline border round it, and
    every field inside one was `slate800`. Three separate devices — a fill, an
    outline and a shadow — all saying the same thing, which is why the borders
    could come off without anything looking unfinished.

    Taking the outline away leaves the fill doing the work alone, so the fill
    has to be worth looking at. `card` is one step brighter than `slate700` and
    `field` one step darker than the page, which turns the pair into a raised
    thing with a recess in it. That reads at arm's length; a 4% difference with
    a 12%-white line around it does not.

    Separate tokens rather than retuning `slate700` because that colour is also
    the sheet background, the bin rows and the segmented control's track, and
    those want to stay where they are.
  */
  final Color card;
  final Color field;

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
  card: Color(0xFF232932),
  field: Color(0xFF12151A),
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
  // Paper inverts the trick: the card is the white one and the field is the
  // tint, because on a light theme a recess is darker than what surrounds it
  // and a raised thing is lighter.
  card: Color(0xFFFFFFFF),
  field: Color(0xFFF4F2ED),
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

/// The shadow under a card.
///
/// ── Two layers, both nearly invisible ─────────────────────────────────────
/// A flat card on a plain surface relies entirely on its fill being a different
/// colour from the page, and in the light theme that difference is #f1efe9
/// against white — about four per cent. On a phone in daylight that is not a
/// difference at all, and the screen reads as one undivided sheet.
///
/// One tight shadow to seat the card, one soft one to lift it. The moment you
/// can point at the shadow it has stopped looking like a raised surface and
/// started looking like a drop-shadow, which is the 2009 version of this idea —
/// the same trap the `hairline` and `sheen` tokens are written about.
///
/// Darker in the dark theme, not lighter. A shadow on a near-black surface has
/// almost nowhere to go, so it needs more opacity to register at all.
List<BoxShadow> cardShadow(StashColors c, {required bool dark}) => [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, dark ? 0.34 : 0.05),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, dark ? 0.28 : 0.055),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

/*
  ── Radii ───────────────────────────────────────────────────────────────────

  These came from the `:root` block of tokens.css, which was written for a web
  app in a browser window. On a phone the app is the whole screen and the only
  frame is the handset's own rounded corner, which is nearer 44 than 22 — a
  card at 22 inside a screen at 44 reads as a slightly-softened rectangle
  rather than as something that belongs to the device.

  Raised across the board, and the ratio between them kept: a field inside a
  card should be visibly rounder than a box, and visibly less round than the
  card holding it.
*/
class Radii {
  static const double lg = 26;
  static const double md = 18;
  static const double sm = 14;
  static const double pill = 99;
}

/*
  ── Type: two faces ─────────────────────────────────────────────────────────

  Bricolage Grotesque for display, Inter for everything read as words. Bundled
  as files rather than fetched, because a first launch that shows the system
  face and then reflows is worse than a slightly larger download.

  ── There used to be a third, and it was never real ─────────────────────────

  `fontMono` named 'JetBrainsMono', which was never added to pubspec.yaml and
  never existed in assets/fonts. Flutter does not complain about an unknown
  family; it silently substitutes the platform default. So five places that
  asked for a monospaced face — the diagnostics values, the backup date, the
  version string, the ERASE confirmation and the date fields — had been drawn
  in Roboto since the port began, and nothing anywhere said so.

  The comment that used to sit here predicted it exactly: "Until they are
  added, Flutter falls back silently." It was written as a note to self during
  the port, and then nobody came back. A note describing a thing that is not
  true yet ages into a note describing a thing that is not true.

  Two ways out: add the font, or stop asking for it. Stopping is the honest
  one — the app is a two-font app, has been for its whole life, and the five
  sites have looked fine that way. `fontMono` stays as a NAME, aliased to the
  body face, because those five places are genuinely different in kind: they
  are read character by character rather than as words. If a mono face is ever
  added, changing this one line puts it everywhere it belongs.
*/
const String fontDisplay = 'BricolageGrotesque';
const String fontBody = 'Inter';

/// Where digits and codes are read one character at a time.
///
/// Aliased to the body face today. It is a separate name so the intent
/// survives — see the note above.
const String fontMono = fontBody;

/*
  ── The scale ───────────────────────────────────────────────────────────────

  Everything on a card used to sit between 11.5 and 15, at weights 500 to 700 —
  a label, its value and a hint underneath were within two points of each
  other. Nothing was wrong with any single one, and the effect of all of them
  together was a screen with no hierarchy: the eye has nowhere to land, so it
  reads top to bottom like a form rather than jumping to the answer.

  Three roles, deliberately far apart:

    Field   11, tracked out, uppercase, muted. Small enough that it reads as
            an annotation on the value rather than as a thing to read.
    Figure  22, display face, negative tracking. Big enough to be the thing
            you see first.
    Hint    12.5, muted, and nothing else on a card is this size.

  A tracked-out uppercase label at 11 is legible where 13.5 sentence case was
  merely small — capitals have no descenders and letterspacing buys back what
  the size costs. It is also the one typographic move that unmistakably says
  "this is a label", which is what lets the value grow without the pair
  becoming ambiguous.
*/
TextStyle fieldLabelStyle(StashColors c) => TextStyle(
      fontFamily: fontBody,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.75,
      color: c.muted,
    );

/// The answer to a labelled field. Display face, because at this size Inter
/// starts to look like a paragraph and Bricolage looks like a number.
TextStyle figureStyle(StashColors c, {double size = 22}) => TextStyle(
      fontFamily: fontDisplay,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.45,
      height: 1.15,
      color: c.text,
    );

/// The sentence under a control that explains it.
TextStyle hintStyle(StashColors c) => TextStyle(
      fontFamily: fontBody,
      fontSize: 12.5,
      height: 1.45,
      color: c.muted,
    );

/// The palette on its own, without a BuildContext to ask.
///
/// `StashColors.of(context)` is the normal way in and stays the normal way in.
/// This exists for the one place that has no context worth asking: the home
/// screen widget faces are rendered off-screen, into a picture, by code that is
/// not inside the app's widget tree at all.
///
/// Both are handed out rather than "the current one", because the launcher
/// decides which it needs — the phone can be in dark mode while the app that
/// drew the picture was not running to notice.
StashColors stashColors({required bool dark}) => dark ? _dark : _light;

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
    textTheme: base.textTheme
        .apply(
          fontFamily: fontBody,
          bodyColor: c.text,
          displayColor: c.text,
        )
        .copyWith(
          // The masthead and the section headings are the display face; everything
          // else is Inter. Mixing them per-widget is how a screen ends up with
          // three typefaces by accident.
          /*
        The masthead: the wordmark on Home and the screen's name on every other
        tab, all one style.

        42 against the PWA's 27. A phone screen is held closer than a desktop
        browser window and the app has no page around it to give the heading a
        frame — the extra pixels are what stop it reading as a label on the
        list underneath rather than as the top of the screen.

        One place, five screens. The wordmark on Home reads the same style, so
        changing this number changes every heading in the app together.
      */
          headlineSmall: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 42,
            letterSpacing: -1.05,
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
          titleMedium: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              color: c.text),
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

    /*
      ── A shadow, and why it is this small ─────────────────────────────────

      Flat cards on a plain surface rely entirely on their fill being a
      different colour from the page, and in the light theme that difference is
      #f1efe9 against white — about four per cent. On a phone in daylight that
      is not a difference at all, and the screen reads as one undivided sheet.

      Two elevations of blur at low opacity: one tight shadow to seat the card,
      one soft one to lift it. The moment you can point at the shadow it has
      stopped looking like a raised surface and started looking like a
      drop-shadow, which is the 2009 version of this idea — the same trap the
      `hairline` and `sheen` tokens are written about.
    */
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.transparent,
      /*
        No side. The hairline was doing the job the fill should be doing, and
        an outline plus a shadow plus a fill is three ways of saying the same
        thing — see the note on `card`.
      */
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: c.text,
      iconColor: c.muted,
      subtitleTextStyle:
          TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
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
      // The label takes the colour of the pill above it. A gold icon on a gold
      // wash over a grey word is the selected state saying two different things
      // about the same tab.
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontBody,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? c.gold : c.muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.slate700,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onGold : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.gold : c.slate600,
      ),
    ),

    /*
      Kept for anything that still raises one, but the undo after a delete does
      not — see lib/ui/undo_bar.dart, which owns its own clock because a
      `SnackBar` in this app would not dismiss itself.
    */
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
      backgroundColor: c.slate600,
      contentTextStyle:
          TextStyle(fontFamily: fontBody, fontSize: 13.5, color: c.text),
      actionTextColor: c.gold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
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
