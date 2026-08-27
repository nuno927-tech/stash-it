/// Where a notification points.
///
/// ── Why a reminder needs one at all ───────────────────────────────────────
/// A notification that opens the app on whatever screen you left it on has
/// wasted the one moment it had. Somebody tapped it because of the thing it
/// named, and landing them on Settings — or on the Items tab scrolled halfway
/// down — makes them go and find it themselves. The tap is the whole point of
/// sending it.
///
/// ── What it can and cannot carry ──────────────────────────────────────────
/// A payload is a string the OS keeps for us until the tap. It survives a
/// reboot, an app being killed, and being read weeks later, so it has to be
/// something that still resolves then — which means an id, not an object.
///
/// It also has to be something that costs nothing if read. Android stores it
/// where a determined person with the phone unlocked could reach it, and the
/// same reasoning that keeps names off the lock screen applies: `item:a3f9c1`
/// is a row number, `item:Nuno's passport` is not.
///
/// ── And a day can hold several things ─────────────────────────────────────
/// `reminderSchedule` groups by day, so one notification often stands for four
/// records — "Passport — Nuno, and 3 more". There is no single record to open,
/// and picking the alphabetically-first one would be arbitrary in a way
/// somebody would notice. Those go to the dashboard, which is already sorted
/// soonest-first and is exactly the list the notification was summarising.
library;

/// The kinds a link can name. Home is not a record; it is the fallback.
enum LinkKind { item, paper, sub, home }

class DeepLink {
  const DeepLink(this.kind, [this.id]);

  const DeepLink.home()
      : kind = LinkKind.home,
        id = null;

  final LinkKind kind;

  /// Null for [LinkKind.home], set for everything else.
  final String? id;

  @override
  String toString() => encodeLink(this);

  @override
  bool operator ==(Object other) =>
      other is DeepLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/*
  ── The format ──────────────────────────────────────────────────────────────

  `kind:id`, or bare `home`. Deliberately not JSON: this string is written by
  one function and read by one function, it is never seen by a human, and a
  format that cannot fail to parse is worth more here than one that could
  carry a field nobody has thought of yet.

  Ids are the app's own — see `newId` — and contain no colon, so splitting on
  the first one is safe. Splitting on the FIRST rather than the only one
  anyway, so an id that ever gains a colon degrades to a wrong id rather than
  to a crash.
*/
String encodeLink(DeepLink link) =>
    link.kind == LinkKind.home ? 'home' : '${link.kind.name}:${link.id}';

/// Reads a payload back, or null if it is not one of ours.
///
/// Null for anything unrecognised rather than a throw or a guess. A payload
/// can arrive from a notification scheduled by a much older version of the
/// app — the OS held it for sixty days across an update — and the honest
/// response to a string this version does not understand is to open the app
/// normally.
DeepLink? parseLink(String? payload) {
  final text = payload?.trim();
  if (text == null || text.isEmpty) return null;

  if (text == 'home') return const DeepLink.home();

  final colon = text.indexOf(':');
  if (colon <= 0 || colon == text.length - 1) return null;

  final kind = text.substring(0, colon);
  final id = text.substring(colon + 1);

  return switch (kind) {
    'item' => DeepLink(LinkKind.item, id),
    'paper' => DeepLink(LinkKind.paper, id),
    'sub' => DeepLink(LinkKind.sub, id),
    _ => null,
  };
}
