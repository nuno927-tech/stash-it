/// Turning a photograph into lines of text, and nothing else.
///
/// ── The only file in the app that knows ML Kit exists ──────────────────────
/// Same shape as the billing seam, for the same two reasons. The parsing above
/// it — `logic/receipt_read.dart`, which is where all the judgement lives —
/// is tested against fifty receipts with no phone in the room, because what it
/// takes is a list of strings. And the day this plugin changes its API, or is
/// replaced, or has to be dropped for a platform that will not carry it, the
/// change is one file.
///
/// ── On the device, and that is the whole reason it is allowed in ───────────
/// The Latin model ships inside the APK. No network call, no key, no account,
/// nothing to add to the privacy policy that was not already true: the
/// photograph never leaves the phone, and neither does the text read off it.
///
/// The alternative — Play Services fetching the model on first use — would
/// have saved about four megabytes of download and cost the sentence "nothing
/// ever leaves your phone" its "ever".
///
/// ── It is allowed to fail, and failing is not an error ─────────────────────
/// A blurry photograph, a receipt face-down, a phone that will not load the
/// model. All of those come back as no lines, which the screen above reads as
/// "could not make anything of that" and offers the form. None of them is a
/// crash, and none of them stops somebody adding an item by hand.
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// What the app needs from a text recogniser, which is very little.
///
/// An interface rather than a direct call so a test can hand back the lines of
/// a real receipt without a plugin, and so the one place that talks to ML Kit
/// is the one class below it.
abstract class TextReader {
  /// Every line in the image, in reading order. Empty when nothing was found,
  /// which includes every way this can go wrong.
  Future<List<String>> linesIn(String path);

  /// Frees the native recogniser. Cheap to call twice.
  Future<void> close();
}

/// The real one.
class MlKitTextReader implements TextReader {
  TextRecognizer? _recogniser;

  @override
  Future<List<String>> linesIn(String path) async {
    try {
      final recogniser =
          _recogniser ??= TextRecognizer(script: TextRecognitionScript.latin);

      final found = await recogniser.processImage(InputImage.fromFilePath(path));

      /*
        Blocks then lines, rather than splitting `recognisedText.text`.

        ML Kit groups text into blocks and the blocks are not in reading order
        on a receipt — a column of prices down the right becomes its own block.
        Taking the lines out block by block keeps each line whole, which is
        what the parsing needs: "TOTAL" and "821.24" have to arrive on the same
        string or the label means nothing.
      */
      return [
        for (final block in found.blocks)
          for (final line in block.lines) line.text,
      ];
    } catch (_) {
      // A photograph it could not read, or a model that would not load. Both
      // are "nothing found", and the screen above offers the form.
      return const [];
    }
  }

  @override
  Future<void> close() async {
    try {
      await _recogniser?.close();
    } catch (_) {
      // Already closed, or never opened.
    } finally {
      _recogniser = null;
    }
  }
}

/// The one the app uses.
///
/// A variable rather than a constant so a widget test can put a reader in that
/// returns a fixed receipt — the same seam `appBilling` uses.
TextReader appTextReader = MlKitTextReader();
