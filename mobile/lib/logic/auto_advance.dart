/// When a card on a form is finished with.
///
/// Ported from `cardFilled` in `src/components/useAutoAdvance.ts`. The pure
/// half lives here so the rule can be stated and tested; the scrolling is in
/// `ui/auto_advance.dart`.
library;

/// True when every field listed has something in it.
///
/// ── Call it with the card's whole contents, optionals included ────────────
/// This is the rule the web version got wrong first time. Each caller watched
/// the field that mattered most — the expiry date, the service, the room — so
/// setting that one field threw you forward past three others you had not
/// touched yet.
///
/// "Answering the last question" has to mean the last question, and a card is
/// not finished because its most important answer arrived. Passing the whole
/// inventory makes the predicate a list anybody can check rather than somebody's
/// judgement about which fields count — and adding a field to a card and
/// forgetting it here shows up in the diff instead of on the phone.
///
/// The cost is real and worth it: a card holding an optional Notes box will
/// almost never advance. **A convenience that fires rarely is strictly better
/// than one that fires while you are still working.**
///
/// Strings are trimmed, so the space bar is not an answer. Everything else is
/// judged on being non-null — a chosen room, a picked date, a set of bytes.
bool cardFilled(List<Object?> fields) {
  return fields.every((f) => f is String ? f.trim().isNotEmpty : f != null && f != false);
}
