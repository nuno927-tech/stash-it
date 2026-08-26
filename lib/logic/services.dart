/// The services people actually subscribe to, with their marks.
///
/// Generated from `src/lib/services.ts` rather than retyped, so the two apps
/// cannot drift into showing different logos for the same service. If a mark
/// changes, it changes there first.
///
/// ── Bundled, not fetched ──────────────────────────────────────────────────
/// A logo API would be one line of code and would also send a list of every
/// service somebody pays for to a third party, from an app whose whole promise
/// is that nothing leaves the device. Logos fetched on demand are requests
/// saying what you watch, what you listen to and which gym you go to.
///
/// So the common ones are here as path data. They come from Simple Icons,
/// published under CC0 — the shapes are free to redistribute. The trademarks
/// belong to their owners and are used only to identify the service the person
/// chose, which is what a logo is for.
///
/// There was briefly a way to fetch a logo for anything unlisted, from that
/// company's own site, once, on a button press. It is gone. It worked badly —
/// most sites refuse a cross-origin favicon — and the small print it needed
/// was a poor trade for a picture. **Nothing in this app makes a network
/// request**, which is a sentence worth being able to say without a footnote.
/// Anything unlisted gets its initials.
///
/// Each entry is a 24x24 path and the brand's own colour: a monochrome mark on
/// a coloured tile rather than full artwork. A fifth of the bytes, legible at
/// 22px in a list, and it does not go muddy on a dark card.
library;

class ServiceDef {
  const ServiceDef({
    required this.id,
    required this.name,
    required this.colour,
    required this.path,
    this.domain = '',
  });

  final String id;
  final String name;

  /// Brand colour, as the tile behind the glyph. `0xAARRGGBB`.
  final int colour;

  /// 24x24 path data.
  final String path;

  /// Kept for reference; nothing fetches from it.
  final String domain;
}

/// Ordered roughly by how many people have one, because this is shown as a
/// grid and the first row should cover most people without scrolling.
const List<ServiceDef> services = [
  ServiceDef(
    id: 'netflix',
    name: 'Netflix',
    colour: 0xFFE50914,
    domain: 'netflix.com',
    path: 'M5.398 0v.006c3.028 8.556 5.37 15.175 8.348 23.596 2.344.058 4.85.398 4.854.398-2.8-7.924-5.923-16.747-8.487-24zm8.489 0v9.63L18.6 22.951c-.043-7.86-.004-15.913.002-22.95zM5.398 1.05V24c1.873-.225 2.81-.312 4.715-.398v-9.22z',
  ),
  ServiceDef(
    id: 'spotify',
    name: 'Spotify',
    colour: 0xFF1DB954,
    domain: 'spotify.com',
    path: 'M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z',
  ),
  ServiceDef(
    id: 'youtube',
    name: 'YouTube Premium',
    colour: 0xFFFF0000,
    domain: 'youtube.com',
    path: 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z',
  ),
  ServiceDef(
    id: 'prime',
    name: 'Amazon Prime',
    colour: 0xFF00A8E1,
    domain: 'amazon.com',
    path: 'M.045 18.02c.072-.116.187-.124.348-.022 3.636 2.11 7.594 3.166 11.87 3.166 2.852 0 5.668-.533 8.447-1.595l.315-.14c.138-.06.234-.1.293-.13.226-.088.39-.046.525.13.12.174.09.336-.12.48-.256.19-.6.41-1.006.654-1.244.743-2.64 1.316-4.185 1.726a17.617 17.617 0 0 1-4.83.615c-2.4 0-4.67-.42-6.81-1.26-2.14-.84-4.06-2.02-5.76-3.54-.1-.086-.15-.17-.15-.25 0-.05.02-.1.06-.15zm6.61-3.36c0-.99.24-1.84.73-2.54.49-.7 1.16-1.23 2.01-1.59.78-.33 1.74-.57 2.88-.71.39-.05 1.02-.1 1.9-.17v-.37c0-.92-.1-1.54-.3-1.86-.3-.43-.78-.64-1.42-.64h-.18c-.47.04-.88.19-1.22.44-.35.26-.57.61-.67 1.06-.06.28-.2.44-.42.48l-2.42-.3c-.24-.05-.36-.18-.36-.37 0-.04.01-.09.02-.14.24-1.24.82-2.16 1.75-2.76.93-.6 2.01-.94 3.25-1.02h.52c1.59 0 2.83.41 3.72 1.24.15.15.28.31.4.48.12.17.21.32.28.46.07.14.13.33.18.59.05.26.08.43.1.53.02.1.03.3.03.62v5.9c0 .42.06.8.19 1.15.12.35.24.6.36.75l.58.77c.1.15.16.28.16.4 0 .13-.07.25-.2.35-1.36 1.18-2.1 1.82-2.21 1.92-.19.14-.41.16-.67.05-.22-.18-.4-.36-.57-.53l-.34-.38-.36-.47c-.99 1.08-1.97 1.75-2.93 2.02-.6.17-1.35.26-2.24.26-1.37 0-2.49-.42-3.37-1.27-.88-.85-1.32-2.05-1.32-3.61zm3.85-.45c0 .7.17 1.26.52 1.68.35.42.82.63 1.41.63.05 0 .13-.01.22-.02.09-.02.15-.02.19-.02.75-.2 1.33-.68 1.74-1.45.2-.34.35-.71.45-1.11.1-.4.15-.73.16-.98.01-.25.02-.66.02-1.24v-.67c-.84 0-1.48.06-1.92.18-1.26.36-1.89 1.16-1.89 2.4zm9.6 4.98c.03-.05.08-.1.14-.15.38-.26.75-.43 1.1-.52.58-.15 1.15-.23 1.7-.25.15-.01.3 0 .44.03.7.06 1.12.18 1.26.35.06.09.09.23.09.41v.16c0 .54-.15 1.17-.44 1.9-.29.73-.7 1.32-1.22 1.77-.08.07-.15.1-.21.1-.04 0-.07-.01-.1-.02-.09-.04-.11-.12-.07-.24.49-1.16.74-1.97.74-2.42 0-.14-.03-.25-.08-.31-.13-.16-.51-.24-1.13-.24-.23 0-.5.02-.81.05-.34.04-.65.09-.93.13-.08 0-.14-.01-.17-.04-.03-.03-.04-.05-.03-.08 0-.02.01-.04.02-.06z',
  ),
  ServiceDef(
    id: 'disneyplus',
    name: 'Disney+',
    colour: 0xFF113CCF,
    domain: 'disneyplus.com',
    path: 'M2 6h20v12H2z M4.5 9h3v1.2h-.9V15H5.4v-4.8h-.9zm5 0h1.2v6H9.5zm3 0h2.4c.7 0 1.2.6 1.2 1.4v3.2c0 .8-.5 1.4-1.2 1.4h-2.4zm1.2 1.2v3.6h.9v-3.6zm4.3-1.2h1.2v2.4h1.3V9h1.2v6h-1.2v-2.4H20V15h-1.2z',
  ),
  ServiceDef(
    id: 'hulu',
    name: 'Hulu',
    colour: 0xFF1CE783,
    domain: 'hulu.com',
    path: 'M3 4h3v6.2c.6-.8 1.5-1.3 2.7-1.3 2 0 3.3 1.3 3.3 3.5V20H9v-6.7c0-1.1-.6-1.8-1.6-1.8S6 12.2 6 13.3V20H3zm11 5.1h3v6.6c0 1.1.6 1.8 1.5 1.8s1.5-.7 1.5-1.8V9.1h3V16c0 2.5-1.7 4.2-4.5 4.2S14 18.5 14 16z',
  ),
  ServiceDef(
    id: 'max',
    name: 'Max',
    colour: 0xFF0026FF,
    domain: 'max.com',
    path: 'M1 7h3.2l2.1 6 2.1-6H11.6v10H9.1v-6.1L7.1 17H5.5L3.5 10.9V17H1zm12.4 0h2.6l2 3.3L20 7h2.6l-3.3 5 3.4 5h-2.7l-2-3.4-2 3.4h-2.7l3.4-5z',
  ),
  ServiceDef(
    id: 'appletv',
    name: 'Apple TV+',
    colour: 0xFF000000,
    domain: 'tv.apple.com',
    path: 'M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701',
  ),
  ServiceDef(
    id: 'applemusic',
    name: 'Apple Music',
    colour: 0xFFFA243C,
    domain: 'music.apple.com',
    path: 'M23.994 6.124a9.23 9.23 0 00-.24-2.19c-.317-1.31-1.062-2.31-2.18-3.043a5.022 5.022 0 00-1.877-.726 10.496 10.496 0 00-1.564-.15c-.04-.003-.083-.01-.124-.013H5.988c-.152.01-.303.017-.455.026-.747.043-1.49.123-2.193.4-1.336.53-2.3 1.452-2.865 2.78-.192.448-.292.925-.363 1.408-.056.392-.088.785-.1 1.18 0 .032-.007.062-.01.093v12.223c.01.14.017.283.027.424.05.815.154 1.624.497 2.373.65 1.42 1.738 2.353 3.234 2.802.42.127.856.187 1.293.228.555.053 1.11.06 1.667.06h11.03a12.5 12.5 0 001.57-.1c.822-.106 1.596-.35 2.295-.81a5.046 5.046 0 001.88-2.207c.186-.42.293-.87.37-1.324.113-.675.138-1.358.137-2.04-.002-3.8 0-7.595-.003-11.393zm-6.423 3.99v5.712c0 .417-.058.827-.244 1.206-.29.59-.76.962-1.388 1.14-.35.1-.706.157-1.07.173-.95.045-1.773-.6-1.943-1.536-.142-.773.227-1.624 1.038-2.022.323-.16.67-.25 1.018-.324.378-.082.758-.153 1.134-.24.274-.063.457-.23.51-.516a.855.855 0 00.02-.193v-5.62c0-.096-.024-.196-.076-.276a.5.5 0 00-.55-.196c-.11.02-.216.05-.324.075l-5.7 1.15c-.017.003-.032.01-.05.014-.28.087-.42.28-.44.57-.002.03 0 .062 0 .093-.002 2.777 0 5.555-.003 8.332 0 .418-.06.827-.245 1.206-.29.59-.76.962-1.388 1.14-.35.1-.706.157-1.07.173-.95.045-1.773-.6-1.943-1.536-.14-.774.23-1.624 1.04-2.022.322-.16.67-.25 1.017-.324.378-.082.758-.153 1.134-.24.274-.063.457-.23.51-.516a.87.87 0 00.02-.193V6.51c0-.108.012-.217.05-.318a.65.65 0 01.5-.42c.16-.033.32-.06.48-.093 1.7-.344 3.4-.687 5.098-1.03l1.4-.283c.148-.03.297-.052.447-.037.313.03.53.24.567.554.005.04.006.08.006.12.002 1.71.002 3.42.002 5.13z',
  ),
  ServiceDef(
    id: 'paramountplus',
    name: 'Paramount+',
    colour: 0xFF0064FF,
    domain: 'paramountplus.com',
    path: 'M12 2 4 20h4l1.4-3.4h5.2L16 20h4zm0 5.6 1.7 4.4h-3.4z',
  ),
  ServiceDef(
    id: 'peacock',
    name: 'Peacock',
    colour: 0xFF000000,
    domain: 'peacocktv.com',
    path: 'M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm0 3.5c1 0 1.8.8 1.8 1.8S13 9.1 12 9.1s-1.8-.8-1.8-1.8S11 5.5 12 5.5zM7.4 8.9c1 0 1.8.8 1.8 1.8s-.8 1.8-1.8 1.8-1.8-.8-1.8-1.8.8-1.8 1.8-1.8zm9.2 0c1 0 1.8.8 1.8 1.8s-.8 1.8-1.8 1.8-1.8-.8-1.8-1.8.8-1.8 1.8-1.8zM12 12.6c1 0 1.8.8 1.8 1.8s-.8 1.8-1.8 1.8-1.8-.8-1.8-1.8.8-1.8 1.8-1.8z',
  ),
  ServiceDef(
    id: 'audible',
    name: 'Audible',
    colour: 0xFFF8991C,
    domain: 'audible.com',
    path: 'M12 2.4 1.5 9v2.1L12 4.5l10.5 6.6V9zM1.5 13.2v2.1L12 21.9l10.5-6.6v-2.1L12 19.8zm0-2.1 10.5 6.6 10.5-6.6-1.6-1L12 16 3.1 10.1z',
  ),
  ServiceDef(
    id: 'dropbox',
    name: 'Dropbox',
    colour: 0xFF0061FF,
    domain: 'dropbox.com',
    path: 'M6 1.807 0 5.629l6 3.822 6.001-3.822L6 1.807zM18 1.807l-6 3.822 6 3.822 6-3.822-6-3.822zM0 13.274l6 3.822 6.001-3.822L6 9.452l-6 3.822zM18 9.452l-6 3.822 6 3.822 6-3.822-6-3.822zM6 18.371l6.001 3.822 6-3.822-6-3.822L6 18.371z',
  ),
  ServiceDef(
    id: 'googleone',
    name: 'Google One',
    colour: 0xFF4285F4,
    domain: 'one.google.com',
    path: 'M12 2 2 19h20zm0 4.2 6.2 10.6H5.8z',
  ),
  ServiceDef(
    id: 'icloud',
    name: 'iCloud+',
    colour: 0xFF3693F3,
    domain: 'icloud.com',
    path: 'M13.762 4.29a6.51 6.51 0 0 0-5.669 3.332 3.571 3.571 0 0 0-1.558-.36 3.571 3.571 0 0 0-3.516 3A4.918 4.918 0 0 0 0 14.796a4.918 4.918 0 0 0 4.92 4.914 4.93 4.93 0 0 0 .617-.045h14.42c2.305-.272 4.041-2.258 4.043-4.589v-.009a4.594 4.594 0 0 0-3.727-4.508 6.51 6.51 0 0 0-6.511-6.27z',
  ),
  ServiceDef(
    id: 'microsoft365',
    name: 'Microsoft 365',
    colour: 0xFFD83B01,
    domain: 'microsoft365.com',
    path: 'M2 3.5 14 1v22L2 20.5zm13 3.2h7V17h-7zm0-1.2V1l7 1.2v2.3zm0 13.5v4.3l7-1.2v-2.3z',
  ),
  ServiceDef(
    id: 'adobecc',
    name: 'Adobe Creative Cloud',
    colour: 0xFFDA1F26,
    domain: 'adobe.com',
    path: 'M13.966 22.624l-1.69-4.281H8.122l3.892-9.144 5.662 13.425zM8.884 1.376H0v21.248zm15.116 0h-8.884L24 22.624z',
  ),
  ServiceDef(
    id: 'playstationplus',
    name: 'PlayStation Plus',
    colour: 0xFF0070D1,
    domain: 'playstation.com',
    path: 'M8.985 2.596v17.548l3.918 1.243V6.688c0-.63.284-1.06.734-.915.599.183.717.774.717 1.404v5.85c2.457 1.185 4.397-.006 4.397-3.147 0-3.246-1.14-4.688-4.493-5.833-1.324-.452-3.78-1.203-5.273-1.451zm4.678 16.633l6.28-2.239c.713-.257.822-.621.242-.809-.58-.189-1.63-.135-2.343.123l-4.179 1.475v-2.363l.24-.083s1.208-.427 2.906-.615c1.699-.188 3.778.026 5.411.646 1.838.582 2.045 1.438 1.576 2.026-.469.588-1.615 1.007-1.615 1.007l-8.518 3.062v-2.23zM2.63 18.667c-1.884-.53-2.198-1.634-1.339-2.27.795-.589 2.147-1.031 2.147-1.031l5.588-1.987v2.264l-4.024 1.44c-.71.257-.82.621-.24.81.58.188 1.63.134 2.34-.124l1.925-.695v2.026c-.122.02-.257.04-.384.06-1.925.315-3.977.183-6.013-.493z',
  ),
  ServiceDef(
    id: 'xboxgamepass',
    name: 'Xbox Game Pass',
    colour: 0xFF107C10,
    domain: 'xbox.com',
    path: 'M4.102 21.033A11.947 11.947 0 0 0 12 24a11.96 11.96 0 0 0 7.902-2.967c1.877-1.912-4.316-8.709-7.902-11.417-3.582 2.708-9.779 9.505-7.898 11.417zm11.16-14.406c2.5 2.961 7.484 10.313 6.076 12.912A11.942 11.942 0 0 0 24 12.004a11.95 11.95 0 0 0-3.57-8.536s-.027-.022-.082-.042a.824.824 0 0 0-.281-.052c-.408 0-1.144.213-2.192.9-.976.64-2.01 1.634-2.61 2.353zm-8.144 0c-.6-.719-1.633-1.712-2.61-2.352-1.047-.687-1.784-.9-2.191-.9a.813.813 0 0 0-.281.052c-.055.02-.082.042-.082.042A11.95 11.95 0 0 0 0 12.004c0 3.156 1.222 6.023 3.219 8.157-1.406-2.598 3.578-9.95 6.078-12.911zM12 3.647s-2.153-1.331-3.844-1.728A11.928 11.928 0 0 1 12 0c1.363 0 2.673.227 3.895.646-1.692.397-3.845 1.728-3.845 1.728z',
  ),
  ServiceDef(
    id: 'nintendo',
    name: 'Nintendo Switch Online',
    colour: 0xFFE60012,
    domain: 'nintendo.com',
    path: 'M2.5 1h7.2c.8 0 1.4.6 1.4 1.4v19.2c0 .8-.6 1.4-1.4 1.4H2.5c-.8 0-1.4-.6-1.4-1.4V2.4C1.1 1.6 1.7 1 2.5 1zm1 2.4v17.2h5.2V3.4zm3 1.6c1 0 1.8.8 1.8 1.8S7.5 8.6 6.5 8.6 4.7 7.8 4.7 6.8 5.5 5 6.5 5zM14.3 1h7.2c.8 0 1.4.6 1.4 1.4v19.2c0 .8-.6 1.4-1.4 1.4h-7.2c-.8 0-1.4-.6-1.4-1.4V2.4c0-.8.6-1.4 1.4-1.4zm3.2 14c1 0 1.8.8 1.8 1.8s-.8 1.8-1.8 1.8-1.8-.8-1.8-1.8.8-1.8 1.8-1.8z',
  ),
  ServiceDef(
    id: 'googlehome',
    name: 'Google Home Premium',
    colour: 0xFF4285F4,
    domain: 'home.google.com',
    path: 'M12 2 2 11h3v9h6v-6h2v6h6v-9h3zm0 2.8 5 4.5V18h-2v-6H9v6H7V9.3z',
  ),
  ServiceDef(
    id: 'googletv',
    name: 'YouTube TV',
    colour: 0xFFFF0000,
    domain: 'tv.youtube.com',
    path: 'M2 5h20a1 1 0 011 1v10a1 1 0 01-1 1H2a1 1 0 01-1-1V6a1 1 0 011-1zm8 3v6l5-3zM7 20h10v1.5H7z',
  ),
  ServiceDef(
    id: 'ring',
    name: 'Ring Protect',
    colour: 0xFF1D6EF6,
    domain: 'ring.com',
    path: 'M12 2a7 7 0 00-7 7v4.6l-2 3.4h18l-2-3.4V9a7 7 0 00-7-7zm0 20a3 3 0 002.8-2H9.2A3 3 0 0012 22z',
  ),
  ServiceDef(
    id: 'nest',
    name: 'Nest Aware',
    colour: 0xFF00A0A0,
    domain: 'nest.com',
    path: 'M12 2a10 10 0 100 20 10 10 0 000-20zm0 3.5A6.5 6.5 0 1112 18.5 6.5 6.5 0 0112 5.5zm0 3A3.5 3.5 0 1012 15.5 3.5 3.5 0 0012 8.5z',
  ),
  ServiceDef(
    id: 'kindle',
    name: 'Kindle Unlimited',
    colour: 0xFFFF9900,
    domain: 'amazon.com',
    path: 'M4 3.5h7a2 2 0 012 2V21a2.5 2.5 0 00-2-1H4zm16 0h-7a2 2 0 00-2 2V21a2.5 2.5 0 012-1h7z',
  ),
  ServiceDef(
    id: 'water',
    name: 'Water delivery',
    colour: 0xFF6AA9FF,
    path: 'M12 2.5S5.5 10 5.5 14.5a6.5 6.5 0 0013 0C18.5 10 12 2.5 12 2.5zm0 3.9c1.6 2.1 4.5 6.3 4.5 8.1a4.5 4.5 0 01-9 0c0-1.8 2.9-6 4.5-8.1z',
  ),
  ServiceDef(
    id: 'appleone',
    name: 'Apple One',
    colour: 0xFF333333,
    domain: 'apple.com',
    path: 'M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701',
  ),
  ServiceDef(
    id: 'appleicloud',
    name: 'Apple Arcade',
    colour: 0xFFFF2D55,
    domain: 'apple.com',
    path: 'M6 4h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zm1.5 4v2h-2v2h2v2h2v-2h2v-2h-2V8zm8 1a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zm2.5 3.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
  ),
  ServiceDef(
    id: 'crunchyroll',
    name: 'Crunchyroll',
    colour: 0xFFF47521,
    domain: 'crunchyroll.com',
    path: 'M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm-1.2 4.8a7.2 7.2 0 0 1 7.2 7.2 4.8 4.8 0 0 1-4.8 4.8 2.4 2.4 0 0 0 2.4-2.4 7.2 7.2 0 0 1-7.2-7.2 4.8 4.8 0 0 1 4.8-4.8 2.4 2.4 0 0 0-2.4 2.4z',
  ),
  ServiceDef(
    id: 'espn',
    name: 'ESPN+',
    colour: 0xFFCC0000,
    domain: 'espn.com',
    path: 'M2 8h6v1.6H4v1.4h3.4v1.6H4V14h4v1.6H2zm7.4 0h4.3c1.3 0 2 .7 2 1.8 0 .8-.4 1.4-1.1 1.6.9.2 1.4.9 1.4 1.9 0 1.4-.9 2.3-2.4 2.3H9.4zm2 1.5v1.5h1.8c.5 0 .8-.3.8-.8s-.3-.7-.8-.7zm0 3v1.6h2c.6 0 .9-.3.9-.8s-.3-.8-.9-.8zM17 8h2v7.6h-2z',
  ),
  ServiceDef(
    id: 'nordvpn',
    name: 'NordVPN',
    colour: 0xFF4687FF,
    domain: 'nordvpn.com',
    path: 'M12 1 2 20h6.5l3.5-6.6 3.5 6.6H22zm0 5.6 2.3 4.3-2.3 4.3-2.3-4.3z',
  ),
  ServiceDef(
    id: 'chatgpt',
    name: 'ChatGPT Plus',
    colour: 0xFF10A37F,
    domain: 'openai.com',
    path: 'M22.282 9.821a5.985 5.985 0 0 0-.516-4.91 6.046 6.046 0 0 0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a5.985 5.985 0 0 0-3.998 2.9 6.046 6.046 0 0 0 .743 7.097 5.98 5.98 0 0 0 .51 4.911 6.051 6.051 0 0 0 6.515 2.9A5.985 5.985 0 0 0 13.26 24a6.056 6.056 0 0 0 5.772-4.206 5.99 5.99 0 0 0 3.997-2.9 6.056 6.056 0 0 0-.747-7.073zM13.26 22.43a4.476 4.476 0 0 1-2.876-1.04l.141-.081 4.779-2.758a.795.795 0 0 0 .392-.681v-6.737l2.02 1.168a.071.071 0 0 1 .038.052v5.583a4.504 4.504 0 0 1-4.494 4.494zM3.6 18.304a4.47 4.47 0 0 1-.535-3.014l.142.085 4.783 2.759a.771.771 0 0 0 .78 0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 1-6.14-1.646zM2.34 7.896a4.485 4.485 0 0 1 2.366-1.973V11.6a.766.766 0 0 0 .388.676l5.815 3.355-2.02 1.168a.076.076 0 0 1-.071 0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 3.855-5.833-3.387L15.119 7.2a.076.076 0 0 1 .071 0l4.83 2.791a4.494 4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 0-.407-.667zm2.01-3.023-.141-.085-4.774-2.782a.776.776 0 0 0-.785 0L9.409 9.23V6.897a.066.066 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 6.68 4.66zm-12.64 4.135-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.795.795 0 0 0-.393.681zm1.097-2.365 2.602-1.5 2.607 1.5v2.999l-2.597 1.5-2.607-1.5z',
  ),
  ServiceDef(
    id: 'strava',
    name: 'Strava',
    colour: 0xFFFC4C02,
    domain: 'strava.com',
    path: 'M15.387 17.944l-2.089-4.116h-3.065L15.387 24l5.15-10.172h-3.066m-7.008-5.599l2.836 5.598h4.172L10.463 0l-7 13.828h4.169',
  ),
  ServiceDef(
    id: 'peloton',
    name: 'Peloton',
    colour: 0xFFDF1C2F,
    domain: 'onepeloton.com',
    path: 'M12 1 2 6.5v11L12 23l10-5.5v-11zm0 2.6 7.4 4.1-7.4 4-7.4-4zm-8 6 7 3.8v7.5l-7-3.8zm16 0v7.5l-7 3.8V13.4z',
  ),
  ServiceDef(
    id: 'notion',
    name: 'Notion',
    colour: 0xFF000000,
    domain: 'notion.so',
    path: 'M4.459 4.208c.746.606 1.026.56 2.428.466l13.215-.793c.28 0 .047-.28-.046-.326L17.86 1.968c-.42-.326-.981-.7-2.055-.607L3.01 2.295c-.466.046-.56.28-.374.466zm.793 3.08v13.904c0 .747.373 1.027 1.214.98l14.523-.84c.841-.046.935-.56.935-1.167V6.354c0-.606-.233-.933-.748-.887l-15.177.887c-.56.047-.747.327-.747.933zm14.337.745c.093.42 0 .84-.42.888l-.7.14v10.264c-.608.327-1.168.514-1.635.514-.748 0-.935-.234-1.495-.933l-4.577-7.186v6.952L12.21 19s0 .84-1.168.84l-3.222.186c-.093-.186 0-.653.327-.746l.84-.233V9.854L7.822 9.76c-.094-.42.14-1.026.793-1.073l3.456-.233 4.764 7.279v-6.44l-1.215-.139c-.093-.514.28-.887.747-.933z',
  ),
  ServiceDef(
    id: 'canva',
    name: 'Canva',
    colour: 0xFF00C4CC,
    domain: 'canva.com',
    path: 'M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm2.4 15.6c-.9 1.2-2.2 1.9-3.5 1.9-2.1 0-3.5-1.6-3.5-4 0-3.4 2.3-6.6 5-6.6 1.3 0 2.2.7 2.2 1.8 0 .9-.5 1.5-1.2 1.5-.5 0-.9-.3-.9-.8 0-.3.1-.5.3-.8.1-.2.2-.3.2-.5 0-.3-.3-.5-.7-.5-1.6 0-3.1 2.6-3.1 5.2 0 1.5.7 2.5 1.8 2.5.9 0 1.8-.6 2.5-1.6.2-.3.4-.4.6-.4.3 0 .5.2.5.5 0 .2-.1.5-.2.8z',
  ),
  ServiceDef(
    id: 'linkedin',
    name: 'LinkedIn Premium',
    colour: 0xFF0A66C2,
    domain: 'linkedin.com',
    path: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z',
  ),
  ServiceDef(
    id: 'nyt',
    name: 'New York Times',
    colour: 0xFF000000,
    domain: 'nytimes.com',
    path: 'M3 4h18v2H3zm0 4h11v1.4H3zm0 3.2h11v1.4H3zm0 3.2h18V16H3zm0 3.4h18V20H3z',
  ),
  ServiceDef(
    id: 'medium',
    name: 'Medium',
    colour: 0xFF000000,
    domain: 'medium.com',
    path: 'M13.54 12a6.8 6.8 0 01-6.77 6.82A6.8 6.8 0 010 12a6.8 6.8 0 016.77-6.82A6.8 6.8 0 0113.54 12zm7.42 0c0 3.54-1.51 6.42-3.38 6.42-1.87 0-3.39-2.88-3.39-6.42s1.52-6.42 3.39-6.42 3.38 2.88 3.38 6.42zM24 12c0 3.17-.53 5.75-1.19 5.75-.66 0-1.19-2.58-1.19-5.75s.53-5.75 1.19-5.75C23.47 6.25 24 8.83 24 12z',
  ),
  ServiceDef(
    id: 'patreon',
    name: 'Patreon',
    colour: 0xFFFF424D,
    domain: 'patreon.com',
    path: 'M0 .48v23.04h4.22V.48zm15.385 0c-4.764 0-8.641 3.88-8.641 8.65 0 4.755 3.877 8.623 8.641 8.623 4.75 0 8.615-3.868 8.615-8.623C24 4.36 20.136.48 15.385.48z',
  ),
  ServiceDef(
    id: 'twitch',
    name: 'Twitch',
    colour: 0xFF9146FF,
    domain: 'twitch.tv',
    path: 'M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z',
  ),
  ServiceDef(
    id: 'discord',
    name: 'Discord Nitro',
    colour: 0xFF5865F2,
    domain: 'discord.com',
    path: 'M20.317 4.37a19.79 19.79 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.331c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z',
  ),
  ServiceDef(
    id: 'onedrive',
    name: 'OneDrive',
    colour: 0xFF0078D4,
    domain: 'onedrive.com',
    path: 'M10.5 5.5a6 6 0 0 1 5.5 3.6 4.5 4.5 0 0 1 4 4.4 4.5 4.5 0 0 1-4.5 4.5H6a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 10.5 5.5z',
  ),
  ServiceDef(
    id: 'proton',
    name: 'Proton',
    colour: 0xFF6D4AFF,
    domain: 'proton.me',
    path: 'M3 3h13a5 5 0 0 1 0 10h-4v8H3zm4 3.4v3.2h8a1.6 1.6 0 0 0 0-3.2z',
  ),
  ServiceDef(
    id: 'lastpass',
    name: '1Password',
    colour: 0xFF0572EC,
    domain: '1password.com',
    path: 'M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm1.2 5.4v7.1l-1.6-1.6-1.6 1.6V5.4zm-2.4 13.2v-2.9l1.6 1.6 1.6-1.6v2.9z',
  ),
  ServiceDef(
    id: 'grammarly',
    name: 'Grammarly',
    colour: 0xFF15C39A,
    domain: 'grammarly.com',
    path: 'M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm0 4.5a7.5 7.5 0 0 1 6 3l-2 1.5a5 5 0 1 0 .9 4.5H12v-2.4h7.4A7.5 7.5 0 1 1 12 4.5z',
  ),
  ServiceDef(
    id: 'duolingo',
    name: 'Duolingo',
    colour: 0xFF58CC02,
    domain: 'duolingo.com',
    path: 'M12 2C7 2 3 6 3 11c0 4 2.5 7.4 6 8.6V22l2.2-1.6c.3 0 .5.1.8.1 5 0 9-4 9-9s-4-9-9-9zm-2.6 7.2a1.4 1.4 0 1 1 0 2.8 1.4 1.4 0 0 1 0-2.8zm5.2 0a1.4 1.4 0 1 1 0 2.8 1.4 1.4 0 0 1 0-2.8z',
  ),
  ServiceDef(
    id: 'headspace',
    name: 'Headspace',
    colour: 0xFFF47D31,
    domain: 'headspace.com',
    path: 'M12 3C6.5 3 2 7 2 12s4.5 9 10 9 10-4 10-9-4.5-9-10-9zm0 3c3.9 0 7 2.7 7 6s-3.1 6-7 6-7-2.7-7-6 3.1-6 7-6z',
  ),
  ServiceDef(
    id: 'calm',
    name: 'Calm',
    colour: 0xFF2F6BFF,
    domain: 'calm.com',
    path: 'M12 2a10 10 0 1 0 10 10A8 8 0 0 1 12 2z',
  ),
  ServiceDef(
    id: 'masterclass',
    name: 'MasterClass',
    colour: 0xFFE4002B,
    domain: 'masterclass.com',
    path: 'M3 5h4l5 9 5-9h4v14h-3.2V10.6L13.3 19h-2.6L6.2 10.6V19H3z',
  ),
  ServiceDef(
    id: 'coursera',
    name: 'Coursera',
    colour: 0xFF0056D2,
    domain: 'coursera.org',
    path: 'M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c2.7 0 5.1-1 6.9-2.7l-2.6-2.6A6.3 6.3 0 1 1 18.3 9l2.6-2.6A9.96 9.96 0 0 0 12 2z',
  ),
  ServiceDef(
    id: 'skillshare',
    name: 'Skillshare',
    colour: 0xFF00FF84,
    domain: 'skillshare.com',
    path: 'M4 6h6v3H7v2h3v7H4v-3h3v-2H4zm10 0h6v3h-3v2h3v7h-6v-3h3v-2h-3z',
  ),
  ServiceDef(
    id: 'gym',
    name: 'Gym membership',
    colour: 0xFF5FBF7E,
    path: 'M4 9h2v6H4zm14 0h2v6h-2zM2 10.5h2v3H2zm18 0h2v3h-2zM7 11h10v2H7z',
  ),
  ServiceDef(
    id: 'phone',
    name: 'Phone plan',
    colour: 0xFF8B949E,
    path: 'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm0 3v13h10V5zm4 14.2h2v1.2h-2z',
  ),
  ServiceDef(
    id: 'internet',
    name: 'Internet',
    colour: 0xFF6AA9FF,
    path: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm0 2c1.3 0 2.6 2.3 3 5.3H9c.4-3 1.7-5.3 3-5.3zM5.2 10.3h2.6a17 17 0 0 0-.2 5.4H5.6a7 7 0 0 1-.4-5.4zm4.6 0h4.4c.2 1.7.2 3.7 0 5.4H9.8c-.2-1.7-.2-3.7 0-5.4zm6.4 0h2.6a7 7 0 0 1-.4 5.4h-2c.2-1.7.1-3.7-.2-5.4z',
  ),
  ServiceDef(
    id: 'insurance',
    name: 'Insurance',
    colour: 0xFFF2CE3D,
    path: 'M12 2 4 5.5v6c0 4.6 3.2 8.9 8 10.5 4.8-1.6 8-5.9 8-10.5v-6zm0 2.2 6 2.6v4.7c0 3.5-2.4 6.9-6 8.3-3.6-1.4-6-4.8-6-8.3V6.8z',
  ),
  ServiceDef(
    id: 'other',
    name: 'Something else',
    colour: 0xFF8B949E,
    path: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4.5a3.2 3.2 0 0 1 3.2 3.2c0 1.3-.8 2-1.8 2.7-.7.5-1 .8-1 1.5v.4h-1.8v-.6c0-1.3.7-2 1.6-2.7.8-.5 1.2-.9 1.2-1.4a1.4 1.4 0 0 0-2.8 0H9.2A3.2 3.2 0 0 1 12 6.5zm-1.2 10.2h2.4v2.1h-2.4z',
  ),
];

/// The catalogue by id, built once.
final Map<String, ServiceDef> serviceById = {
  for (final s in services) s.id: s,
};

/// The known service with this id, or null for one somebody typed themselves.
ServiceDef? serviceFor(String? id) => id == null ? null : serviceById[id];

/// Everything matching what has been typed so far.
///
/// Matches anywhere in the name rather than only at the start: people type
/// "prime" for Amazon Prime and "tv" for Apple TV+, and a prefix search
/// answers neither.
List<ServiceDef> searchServices(String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return services;

  return [
    for (final s in services)
      if (s.name.toLowerCase().contains(text) || s.id.contains(text)) s,
  ];
}

/// What to draw when the service is not one of the listed ones.
///
/// One letter or two, never three: at 22px a third letter is the width of the
/// other two and reads as noise. "Water delivery" gives "WD", "Gym" gives "G".
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  if (words.isEmpty) return '?';

  String first(String word) => word.substring(0, 1).toUpperCase();

  if (words.length == 1) return first(words.first);
  return first(words[0]) + first(words[1]);
}
