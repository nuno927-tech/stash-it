/// Which season it is, for the one pose that dresses for it.
///
/// ── Why this is a function and not an `if` in a widget ────────────────────
/// It is four boundaries and a hemisphere assumption, which is exactly the
/// shape of thing that gets written twice and drifts. It is also the only part
/// of the seasonal artwork anybody can be wrong about, so it is the part with
/// tests.
///
/// ── Northern, and said out loud ───────────────────────────────────────────
/// A bobble hat in December is right in Boston and wrong in Sydney. The app has
/// no locale awareness anywhere else — the dates are American, the money picker
/// is manual — and inventing hemisphere detection for a squirrel would be the
/// most sophisticated thing in the codebase.
///
/// So: northern calendar seasons, and this note. If it ever matters, the fix is
/// a device-locale check here and nowhere else, because nothing outside this
/// file knows how the answer was reached.
library;

enum Season { spring, summer, autumn, winter }

/// Meteorological seasons: whole months, three each.
///
/// Not the astronomical ones. Those turn on a solstice that moves between the
/// 20th and the 23rd depending on the year, which would need a table to be
/// right and would be invisible when it was wrong — nobody notices a squirrel
/// changing hats two days late, which is the argument for the simpler rule
/// rather than against caring at all.
Season seasonOf(DateTime when) => switch (when.month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };
