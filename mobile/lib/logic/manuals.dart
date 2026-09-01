/// Where to look for a product's manual.
///
/// ── What this is not ──────────────────────────────────────────────────────
/// It does not fetch anything. There is no manual API worth the name — the
/// aggregator sites scrape and forbid scraping, and manufacturers publish
/// nothing machine-readable — so a feature that promised to retrieve a PDF
/// would need a server, a licence to redistribute somebody else's document,
/// and a hit rate nobody can guarantee on a fifteen-year-old dishwasher.
///
/// What it does is build a URL and hand it to the browser. The app opens no
/// connection: `url_launcher` starts a different app, which is the difference
/// between "we looked this up for you" and "we sent your data somewhere".
/// That distinction is the whole reason this is possible at all — see the
/// privacy policy, which now says exactly where the app's one network
/// permission comes from.
///
/// ── The table, and why it earns its upkeep ────────────────────────────────
/// A generic web search for "Bosch SMV4HCX40G manual" returns a page of
/// aggregator sites carrying the wrong revision behind an advert wall. The
/// manufacturer's own support page carries the right one. So the common brands
/// are listed here with the search URL their own site uses, and everything
/// else falls back to a plain web search.
///
/// It will rot — support sites are redesigned and these patterns break. That
/// is the honest cost of the approach, and it is bounded: a broken entry
/// degrades to a page on the right manufacturer's site rather than to nothing.
library;

/// One manufacturer's manual search.
class ManualSource {
  const ManualSource(this.brand, this.url);

  /// Shown on the button, so it is the brand as somebody would write it.
  final String brand;

  /// `{q}` is replaced by the model, already URL-encoded.
  final String url;
}

/*
  Keyed on the brand folded to lower case with punctuation removed, because
  people type "GE", "G.E." and "ge". The value keeps the spelling worth showing
  back to them.

  Ordered by how often the brand turns up in a household rather than
  alphabetically, so adding to it means thinking about coverage.
*/
const Map<String, ManualSource> manualSources = {
  // ── kitchen and laundry ─────────────────────────────────────────────────
  'bosch': ManualSource(
      'Bosch', 'https://www.bosch-home.com/us/service/manuals?q={q}'),
  'samsung': ManualSource(
      'Samsung', 'https://www.samsung.com/us/support/search/?q={q}'),
  'lg': ManualSource('LG', 'https://www.lg.com/us/support/search?search={q}'),
  'whirlpool': ManualSource(
      'Whirlpool', 'https://www.whirlpool.com/services/manuals.html?q={q}'),
  'ge': ManualSource(
      'GE', 'https://www.geappliances.com/search?text={q}%20manual'),
  'maytag':
      ManualSource('Maytag', 'https://www.maytag.com/search?Ntt={q}%20manual'),
  'kitchenaid': ManualSource(
      'KitchenAid', 'https://www.kitchenaid.com/search?Ntt={q}%20manual'),
  'frigidaire': ManualSource(
      'Frigidaire', 'https://www.frigidaire.com/en/search?q={q}%20manual'),
  'miele':
      ManualSource('Miele', 'https://www.miele.com/en/us/search.htm?q={q}'),
  'electrolux': ManualSource(
      'Electrolux', 'https://www.electrolux.com/en/search/?q={q}%20manual'),
  'beko': ManualSource('Beko', 'https://www.beko.com/us-en/support?q={q}'),
  'hotpoint': ManualSource(
      'Hotpoint', 'https://www.hotpoint.co.uk/search?text={q}%20manual'),

  // ── small appliances and tools ──────────────────────────────────────────
  'dyson': ManualSource('Dyson', 'https://www.dyson.com/support/search?q={q}'),
  'shark': ManualSource(
      'Shark', 'https://support.sharkclean.com/hc/en-us/search?query={q}'),
  'ninja': ManualSource(
      'Ninja', 'https://support.ninjakitchen.com/hc/en-us/search?query={q}'),
  'breville': ManualSource(
      'Breville', 'https://www.breville.com/us/en/search.html?q={q}%20manual'),
  'delonghi': ManualSource(
      "De'Longhi", 'https://www.delonghi.com/en-us/search?q={q}%20manual'),
  'instantpot': ManualSource(
      'Instant Pot', 'https://instanthome.com/search?q={q}%20manual'),
  'dewalt':
      ManualSource('DeWalt', 'https://www.dewalt.com/search?text={q}%20manual'),
  'makita': ManualSource(
      'Makita', 'https://www.makitatools.com/search?q={q}%20manual'),
  'bosch tools': ManualSource(
      'Bosch Tools', 'https://www.boschtools.com/us/en/search/?q={q}'),
  'ryobi':
      ManualSource('Ryobi', 'https://www.ryobitools.com/search?q={q}%20manual'),
  'karcher': ManualSource(
      'Kärcher', 'https://www.kaercher.com/us/search.html?q={q}%20manual'),

  // ── screens, sound and computing ────────────────────────────────────────
  'sony': ManualSource(
      'Sony', 'https://www.sony.com/electronics/support/search?query={q}'),
  'panasonic': ManualSource(
      'Panasonic', 'https://na.panasonic.com/us/support/search?q={q}'),
  'philips':
      ManualSource('Philips', 'https://www.philips.com/search?q={q}%20manual'),
  'tcl': ManualSource('TCL', 'https://www.tcl.com/us/en/support?q={q}'),
  'hisense': ManualSource(
      'Hisense', 'https://www.hisense-usa.com/support/search?q={q}'),
  'apple':
      ManualSource('Apple', 'https://support.apple.com/en-us/search?q={q}'),
  'dell':
      ManualSource('Dell', 'https://www.dell.com/support/search/en-us#q={q}'),
  'hp':
      ManualSource('HP', 'https://support.hp.com/us-en/search?q={q}%20manual'),
  'lenovo': ManualSource(
      'Lenovo', 'https://support.lenovo.com/us/en/search?query={q}'),
  'canon': ManualSource(
      'Canon', 'https://www.usa.canon.com/support/search?q={q}%20manual'),
  'epson':
      ManualSource('Epson', 'https://epson.com/Support/sl/s?text={q}%20manual'),
  'brother': ManualSource('Brother',
      'https://support.brother.com/g/s/id/htmldoc/search.html?q={q}'),
  'bose': ManualSource('Bose', 'https://www.bose.com/en_us/search.html?q={q}'),
  'sonos':
      ManualSource('Sonos', 'https://support.sonos.com/en-us/search?q={q}'),

  // ── heating, garden and the rest ────────────────────────────────────────
  'honeywell': ManualSource(
      'Honeywell', 'https://www.honeywellhome.com/us/en/search/?q={q}'),
  'nest': ManualSource('Nest', 'https://support.google.com/googlenest/?q={q}'),
  'worcester': ManualSource('Worcester Bosch',
      'https://www.worcester-bosch.co.uk/support/search?q={q}'),
  'vaillant': ManualSource(
      'Vaillant', 'https://www.vaillant.co.uk/searchresults/?q={q}%20manual'),
  'weber': ManualSource(
      'Weber', 'https://www.weber.com/US/en/search?q={q}%20manual'),
  'traeger':
      ManualSource('Traeger', 'https://www.traeger.com/search?q={q}%20manual'),
  'husqvarna': ManualSource(
      'Husqvarna', 'https://www.husqvarna.com/us/search/?q={q}%20manual'),
  'ikea': ManualSource('IKEA', 'https://www.ikea.com/us/en/search/?q={q}'),
};

/// Folded for lookup: lower case, and nothing but letters and digits.
///
/// "G.E.", "GE" and "ge " are one brand; so are "De'Longhi" and "delonghi".
String foldBrand(String brand) =>
    brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

/// The manufacturer's own manual search, or null when the brand is unknown.
ManualSource? sourceFor(String? brand) {
  final key = foldBrand(brand ?? '');
  if (key.isEmpty) return null;

  final exact = manualSources[key];
  if (exact != null) return exact;

  /*
    "Bosch Serie 6" should still find Bosch.

    First word only, and only when it is long enough to mean something — a
    two-letter first word would match half the table by accident, and the
    genuinely two-letter brands ("LG", "GE", "HP") are caught by the exact
    lookup above before this runs.
  */
  final first = key.split(' ').first;
  return first.length >= 3 ? manualSources[first] : null;
}

/// Where to send somebody looking for a manual.
///
/// The manufacturer's site when the brand is known, and a plain web search
/// otherwise. Never null: "no idea" is still worth a search, and a button that
/// disappears for unknown brands would be a button nobody learns to expect.
Uri manualSearch({String? brand, String? model}) {
  final source = sourceFor(brand);
  final query = [
    if ((brand ?? '').trim().isNotEmpty) brand!.trim(),
    if ((model ?? '').trim().isNotEmpty) model!.trim(),
  ].join(' ');

  if (source != null) {
    // The manufacturer already knows its own brand; sending it back makes the
    // model harder to match, so their site gets the model alone where there is
    // one.
    final term = (model ?? '').trim().isNotEmpty ? model!.trim() : query;
    return Uri.parse(source.url.replaceAll('{q}', Uri.encodeComponent(term)));
  }

  return Uri.parse(
    'https://duckduckgo.com/?q=${Uri.encodeComponent('$query manual')}',
  );
}

/// What the button should say.
///
/// Naming the manufacturer is the whole value of the table: "Look on Bosch"
/// promises the right document, where "Search the web" promises a page of
/// results.
String manualButtonLabel(String? brand) {
  final source = sourceFor(brand);
  return source == null ? 'Search the web' : 'Look on ${source.brand}';
}
