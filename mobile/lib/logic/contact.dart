/// Getting in touch.
///
/// Ported from `src/lib/contact.ts`.
///
/// ── A `mailto:` link, not a form ──────────────────────────────────────────
/// A form would need somewhere to post to, and a server is the one thing this
/// app has spent its life not having. A mail link opens the person's own client
/// with the message already addressed — they can see every word before they
/// send it, and nothing leaves the phone until they do.
library;

enum ContactKind { question, idea, bug }

/// Where the contact links go.
///
/// The app's own address rather than a personal one. Two reasons, and the
/// second is the one that matters: it can be handed to somebody else without
/// changing the app, and it does not put a private inbox on the Play Store
/// listing for anybody who wants to shout at a squirrel.
const String developerEmail = 'StashitScout@gmail.com';

const Map<ContactKind, String> _subject = {
  ContactKind.question: 'Stash it — a question',
  ContactKind.idea: 'Stash it — an idea',
  ContactKind.bug: 'Stash it — something is wrong',
};

/// The line under the cursor, telling somebody what the email opens with.
const Map<ContactKind, String> _opener = {
  ContactKind.question: 'Ask away.',
  ContactKind.idea: 'What should it do?',
  ContactKind.bug: 'What happened, and what did you expect instead?',
};

/// The footer. Short enough that nobody minds it, specific enough to save a
/// round trip.
///
/// Deliberately plain text at the end of the body rather than a hidden header:
/// **anything a user cannot see before they press send is a thing they did not
/// agree to send.**
String contextLine(String version) => '— Stash it v$version · Android';

String contactBody(ContactKind kind, String version) =>
    // Two newlines first, so the cursor lands above the context and not below.
    '\n\n${_opener[kind]}\n\n${contextLine(version)}';

/// A `mailto:` URI.
///
/// Every part is percent-encoded. A subject with an ampersand in it would
/// otherwise truncate the body at that point — the sort of bug that only shows
/// up once somebody's mail client is stricter than yours.
Uri contactUri(ContactKind kind, String version) => Uri(
      scheme: 'mailto',
      path: developerEmail,
      query: [
        'subject=${Uri.encodeComponent(_subject[kind]!)}',
        'body=${Uri.encodeComponent(contactBody(kind, version))}',
      ].join('&'),
    );
