/// Search across the stash.
///
/// Translated from `src/lib/search.ts`. Pure functions over lists the caller
/// has already loaded — no queries in here, so it is fully testable and cheap
/// to re-run on every keystroke.
///
/// The rules, and each one is there because of how people actually type:
///
///  - **Substring, not prefix.** Someone hunting a serial types the four
///    characters they can read off the plate, and those are rarely the first
///    four.
///  - **Punctuation is noise in serials and models**, so "shxm-4ay55n" finds
///    SHXM4AY55N.
///  - **Accents fold**, so "Bosch Séries" answers to "series".
///  - **Multiple words are AND**, each free to land in a different field:
///    "bosch kitchen" finds the Bosch in the kitchen.
library;

import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'papers.dart';
import 'warranty.dart';

/// Which field earned a match.
enum MatchField {
  name,
  brand,
  model,
  serial,
  retailer,
  room,
  notes,
  warranty,
  document,

  /* Documents. "Whose" is the one people actually search — a household with
     four passports is four rows with the same label. */
  holder,
  kind,
  issuer,
  stored,
}

/// Field weights. Name dominates; notes are a last resort.
const Map<MatchField, double> _weight = {
  MatchField.name: 40,
  MatchField.serial: 35,
  MatchField.holder: 32,
  MatchField.model: 30,
  MatchField.brand: 28,
  MatchField.kind: 26,
  MatchField.document: 22,
  MatchField.retailer: 20,
  MatchField.issuer: 19,
  MatchField.room: 18,
  MatchField.stored: 16,
  MatchField.warranty: 15,
  MatchField.notes: 10,
};

const Map<MatchField, String> fieldLabel = {
  MatchField.name: 'name',
  MatchField.brand: 'brand',
  MatchField.model: 'model',
  MatchField.serial: 'serial number',
  MatchField.retailer: 'retailer',
  MatchField.room: 'room',
  MatchField.notes: 'notes',
  MatchField.warranty: 'warranty details',
  MatchField.document: 'a document',
  MatchField.holder: 'who it belongs to',
  MatchField.kind: 'what kind it is',
  MatchField.issuer: 'who issued it',
  MatchField.stored: 'where it is kept',
};

/// One result, whatever kind of thing it is.
///
/// ── Why one list rather than three ────────────────────────────────────────
/// The search field lived on the Items tab and only ever looked at items,
/// which was correct when items were all there was. It stopped being correct
/// the day the app grew documents and subscriptions: typing "passport" into the
/// one search box returned nothing, which does not read as "wrong tab", it
/// reads as "the app has lost my passport".
///
/// Ranked together rather than grouped by kind, for the same reason the
/// dashboard timeline is one list: someone searching "golf" wants the closest
/// match to the word, and does not know or care which table it came from.
///
/// ── A small improvement over the TypeScript ───────────────────────────────
/// This is a `sealed` class, so a `switch` over a hit has to handle every kind
/// or it will not compile. The TS used a discriminated union, which is the same
/// idea with the compiler checking less of it.
sealed class SearchHit {
  const SearchHit({
    required this.score,
    required this.fields,
    required this.title,
  });

  final double score;

  /// Which fields earned the match, best first. Drives the "why" line.
  final List<MatchField> fields;

  /// The display name, so ties break alphabetically without a switch.
  final String title;
}

class ItemHit extends SearchHit {
  const ItemHit(this.item,
      {required super.score, required super.fields, required super.title});
  final Item item;
}

class PaperHit extends SearchHit {
  const PaperHit(this.paper,
      {required super.score, required super.fields, required super.title});
  final Paper paper;
}

class SubscriptionHit extends SearchHit {
  const SubscriptionHit(this.sub,
      {required super.score, required super.fields, required super.title});
  final Subscription sub;
}

/* ------------------------------------------------------------ normalising */

/// Accent folding, by table.
///
/// ── An honest divergence, and its limit ───────────────────────────────────
/// The TypeScript calls `String.normalize('NFD')` and strips the combining
/// marks, which is the platform's full Unicode implementation and handles every
/// script. **Dart's core library has no `normalize`.**
///
/// So this is a table, and a table only knows what is in it: Latin-1 and the
/// common parts of Latin Extended-A, which is every accent that appears on a
/// European appliance, brand or name. Anything outside it — Greek, Cyrillic,
/// Vietnamese tone marks — folds to itself and is still matched exactly, just
/// not accent-insensitively.
///
/// `package:diacritic` does this properly and arrives with the UI in phase 3.
/// Adding a dependency to phase 1, whose whole point is that it runs with
/// nothing but `dart test`, is not worth the twelve characters it would buy.
const Map<String, String> _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
  'ě': 'e',
  'ğ': 'g', 'ģ': 'g',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
  'ł': 'l', 'ľ': 'l', 'ļ': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ņ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ő': 'o',
  'ŕ': 'r', 'ř': 'r',
  'ś': 's', 'š': 's', 'ş': 's',
  'ť': 't', 'ţ': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  // The ones that are not one letter.
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss', 'þ': 'th',
};

String normalize(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_fold[ch] ?? ch);
  }
  return out.toString().trim();
}

/// For serials and models, where punctuation is noise.
String _alnum(String s) => normalize(s).replaceAll(RegExp(r'[^a-z0-9]'), '');

final RegExp _spaces = RegExp(r'\s+');

List<String> terms(String query) =>
    normalize(query).split(_spaces).where((t) => t.isNotEmpty).toList();

/* --------------------------------------------------------------- matching */

class _Haystack {
  const _Haystack(this.field, this.text, {this.loose = false});
  final MatchField field;
  final String text;

  /// Also compared with punctuation removed.
  final bool loose;
}

/*
  ── Both sides prepared once, and it is not a micro-optimisation ──────────

  The TypeScript ran `normalize()` and built a `RegExp` inside the innermost
  loop, so a three-word query over a large collection normalised the same eight
  strings three times each and compiled one regex per field per record per
  keystroke. Measured over 2000 items: 21ms a keystroke in Node, which is
  several times that on a mid-range phone — well past the point where typing
  feels behind your finger. Folding both sides flat before the loops took it to
  7ms.

  The same shape is kept here, and it matters more rather than less: this is
  the one function in the app that runs on every character typed, and phones
  are where it runs.
*/
class _Ready {
  const _Ready(this.field, this.text, this.loose);
  final MatchField field;
  final String text;

  /// Punctuation stripped, or null when this field does not do loose matching.
  final String? loose;
}

List<_Ready> _ready(List<_Haystack> hay) => [
      for (final h in hay)
        _Ready(h.field, normalize(h.text), h.loose ? _alnum(h.text) : null),
    ];

class _Needle {
  const _Needle(this.term, this.loose, this.word);
  final String term;
  final String loose;

  /// Word-boundary test, compiled once per query rather than per comparison.
  final RegExp word;
}

List<_Needle> _needles(List<String> words) => [
      for (final term in words)
        _Needle(term, _alnum(term), RegExp('\\b${_escapeRegex(term)}')),
    ];

/// Regex metacharacters are literal here. Someone searching "a.*" means those
/// three characters, and treating it as a pattern would return the whole
/// database — or throw, on a lone bracket.
String _escapeRegex(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]!}');

class _FieldScore {
  const _FieldScore(this.field, this.score);
  final MatchField field;
  final double score;
}

/// Best score a single term can earn against one record, plus the field.
_FieldScore? _scoreTerm(_Needle n, List<_Ready> hay) {
  _FieldScore? best;

  for (final h in hay) {
    final text = h.text;
    final weight = _weight[h.field]!;
    var hit = 0.0;

    if (text == n.term) {
      hit = weight * 2.5;
    } else if (text.startsWith(n.term)) {
      hit = weight * 1.6;
    } else if (n.word.hasMatch(text)) {
      hit = weight * 1.3;
    } else if (text.contains(n.term)) {
      hit = weight;
    } else if (h.loose != null &&
        n.loose.length >= 3 &&
        h.loose!.contains(n.loose)) {
      // Punctuation-stripped comparison, but only for terms long enough to
      // mean something: stripping "a.*" down to "a" would otherwise match half
      // the model numbers in the database.
      hit = weight * 0.9;
    }

    if (hit > 0 && (best == null || hit > best.score)) {
      best = _FieldScore(h.field, hit);
    }
  }

  return best;
}

class _Rank {
  const _Rank(this.score, this.fields);
  final double score;
  final List<MatchField> fields;
}

/// Every term has to land somewhere, and the best landing counts.
_Rank? _rank(List<_Needle> words, List<_Haystack> hay) {
  final prepared = _ready(hay);
  var total = 0.0;
  final scored = <_FieldScore>[];

  for (final word in words) {
    final best = _scoreTerm(word, prepared);
    if (best == null) return null;
    total += best.score;
    scored.add(best);
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return _Rank(total, {for (final f in scored) f.field}.toList());
}

/* ------------------------------------------------------------- haystacks */

List<_Haystack> _itemHay(Item item, String? roomName, List<String> docTitles) {
  final out = <_Haystack>[_Haystack(MatchField.name, item.name)];

  void maybe(MatchField field, String? text, {bool loose = false}) {
    if (text != null && text.isNotEmpty) {
      out.add(_Haystack(field, text, loose: loose));
    }
  }

  maybe(MatchField.brand, item.brand);
  maybe(MatchField.model, item.model, loose: true);
  maybe(MatchField.serial, item.serial, loose: true);
  maybe(MatchField.retailer, item.retailer);
  maybe(MatchField.room, roomName);
  maybe(MatchField.notes, item.notes);

  // Every policy, not just the first two fields: "sinuous spring" is a
  // perfectly reasonable thing to search a couch for, and it only exists on
  // the coverage that says so.
  final w = coveragesOf(item)
      .expand((c) => [c.label, c.covers, c.provider, c.policyNumber])
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');
  maybe(MatchField.warranty, w, loose: true);

  for (final t in docTitles) {
    out.add(_Haystack(MatchField.document, t));
  }

  return out;
}

/// A document's searchable text. No numbers, because there are none to hold —
/// see the note on `Paper`.
List<_Haystack> _paperHay(Paper paper) {
  final out = <_Haystack>[_Haystack(MatchField.name, paper.label)];

  final holder = paper.holder;
  if (holder != null && holder.isNotEmpty) {
    out.add(_Haystack(MatchField.holder, holder));
  }

  // The kind, in the words the app shows: a row called "Mine" should still
  // answer to "driving license".
  out.add(_Haystack(MatchField.kind, kindLabel[paper.kind]!));

  final authority = paper.authority;
  if (authority != null && authority.isNotEmpty) {
    out.add(_Haystack(MatchField.issuer, authority));
  }

  final stored = paper.storedAt;
  if (stored != null && stored.isNotEmpty) {
    out.add(_Haystack(MatchField.stored, stored));
  }

  final notes = paper.notes;
  if (notes != null && notes.isNotEmpty) {
    out.add(_Haystack(MatchField.notes, notes));
  }

  return out;
}

List<_Haystack> _subHay(Subscription sub) {
  final out = <_Haystack>[_Haystack(MatchField.name, sub.name)];
  final notes = sub.notes;
  if (notes != null && notes.isNotEmpty) {
    out.add(_Haystack(MatchField.notes, notes));
  }
  return out;
}

/* ------------------------------------------------------------ the search */

class SearchInput {
  const SearchInput({
    this.items = const [],
    this.docs = const [],
    this.rooms = const [],
    this.papers = const [],
    this.subs = const [],
  });

  final List<Item> items;
  final List<Doc> docs;
  final List<Room> rooms;
  final List<Paper> papers;
  final List<Subscription> subs;
}

List<SearchHit> searchAll(String query, SearchInput input) {
  final words = _needles(terms(query));
  if (words.isEmpty) return [];

  final roomById = {for (final r in input.rooms) r.id: r.name};

  final titlesByItem = <String, List<String>>{};
  for (final d in input.docs) {
    final title = d.title;
    if (d.deletedAt != null || title == null || title.isEmpty) continue;
    titlesByItem.putIfAbsent(d.itemId, () => []).add(title);
  }

  final hits = <SearchHit>[];

  for (final item in input.items) {
    if (item.deletedAt != null) continue;
    final roomId = item.roomId;
    final got = _rank(
      words,
      _itemHay(
        item,
        roomId == null ? null : roomById[roomId],
        titlesByItem[item.id] ?? const [],
      ),
    );
    if (got != null) {
      hits.add(ItemHit(item,
          score: got.score, fields: got.fields, title: item.name));
    }
  }

  for (final paper in input.papers) {
    if (paper.deletedAt != null) continue;
    final got = _rank(words, _paperHay(paper));
    if (got != null) {
      hits.add(PaperHit(paper,
          score: got.score, fields: got.fields, title: paper.label));
    }
  }

  for (final sub in input.subs) {
    if (sub.deletedAt != null) continue;
    final got = _rank(words, _subHay(sub));
    if (got != null) {
      hits.add(SubscriptionHit(sub,
          score: got.score, fields: got.fields, title: sub.name));
    }
  }

  // Ties break alphabetically so the order never jitters between keystrokes.
  hits.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.title.compareTo(b.title);
  });
  return hits;
}

/// "Matched on serial number and notes" — omitted entirely when the only match
/// was the name, since that is self-evident from the row itself.
String? matchSummary(SearchHit hit) {
  final other = hit.fields.where((f) => f != MatchField.name).toList();
  if (other.isEmpty) return null;
  final labels = other.take(2).map((f) => fieldLabel[f]!);
  return 'Matched on ${labels.join(' and ')}';
}
