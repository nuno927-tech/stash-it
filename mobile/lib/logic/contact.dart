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
/// The studio's address rather than a personal one. Two reasons, and the
/// second is the one that matters: it can be handed to somebody else without
/// changing the app, and it does not put a private inbox on the Play Store
/// listing for anybody who wants to shout at a squirrel.
///
/// Read by `contactUri` and by nothing else, so changing it here changes every
/// link in the app: the three contact buttons and the problem report that
/// carries the diagnostics.
const String developerEmail = 'FLuXappStudios@gmail.com';

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

/// How much evidence may ride along.
///
/// ── A `mailto:` body is not a file ─────────────────────────────────────────
/// The whole thing becomes one percent-encoded URI handed to whatever mail app
/// answers the intent, and clients differ on how much they will take: some
/// truncate silently in the middle of a word, and a truncated stack trace is
/// worse than none because it looks complete.
///
/// So the app decides what to cut rather than leaving it to a mail client. The
/// newest crash is worth more than the twentieth, and the full log is one
/// screen away for anybody who wants it.
const int evidenceLimit = 3000;

/// The line above anything gathered automatically.
///
/// ── Between the message and the machinery ──────────────────────────────────
/// Somebody writes at the top and sends. What is underneath has to be
/// unmistakably not theirs, and has to say — before they scroll past it — that
/// deleting it is allowed. An email that quietly carries a stack trace naming
/// one of their documents is the thing this app exists not to do.
const String evidenceRule = '——— for the developer ———';

String contactBody(ContactKind kind, String version, {String? evidence}) {
  // Two newlines first, so the cursor lands above the context and not below.
  final message = '\n\n${_opener[kind]}\n\n${contextLine(version)}';

  final gathered = (evidence ?? '').trim();
  if (gathered.isEmpty) return message;

  return '$message\n\n'
      '$evidenceRule\n'
      'Gathered from this phone so you do not have to be asked for it. '
      'Read it, and delete anything you would rather not send.\n\n'
      '${_within(gathered, evidenceLimit)}';
}

/// Cut at a line boundary, and say so.
///
/// Mid-word is where a mail client would cut it. A whole line short of the
/// limit, with a sentence saying what is missing and where the rest lives, is
/// the difference between evidence and a puzzle.
String _within(String text, int limit) {
  if (text.length <= limit) return text;

  final kept = text.substring(0, limit);
  final lastBreak = kept.lastIndexOf('\n');

  return '${kept.substring(0, lastBreak < 0 ? limit : lastBreak)}\n\n'
      '(cut here. The rest is in Settings, Developer, Crashes.)';
}

/// A `mailto:` URI.
///
/// Every part is percent-encoded. A subject with an ampersand in it would
/// otherwise truncate the body at that point — the sort of bug that only shows
/// up once somebody's mail client is stricter than yours.
Uri contactUri(ContactKind kind, String version, {String? evidence}) => Uri(
      scheme: 'mailto',
      path: developerEmail,
      query: [
        'subject=${Uri.encodeComponent(_subject[kind]!)}',
        'body=${Uri.encodeComponent(contactBody(
          kind,
          version,
          evidence: evidence,
        ))}',
      ].join('&'),
    );
