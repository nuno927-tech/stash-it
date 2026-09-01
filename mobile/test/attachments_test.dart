/// Filing paperwork: the decisions, without the picker.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/attachments.dart';
import 'package:stash_it/models/types.dart';

void main() {
  group('the six tiles', () {
    test('every kind on the grid has a label', () {
      for (final kind in docKindOrder) {
        expect(docKindLabels[kind], isNotNull, reason: '$kind');
      }
    });

    /*
      Every kind the model can hold has to be reachable from the form.

      A DocKind added to the enum and not to this list is a kind that arrives
      by restore, shows up in the list, and can never be created on the phone —
      which is not a crash and not a test failure, only a quiet asymmetry
      nobody notices until somebody asks why they cannot add one.
    */
    test('and every kind the model has is on the grid', () {
      expect(docKindOrder.toSet(), DocKind.values.toSet());
    });

    test('"other" is called Document, not Other', () {
      // A tile labelled Other describes the app's filing system rather than
      // the thing in your hand, and is the tile nobody presses.
      expect(docKindLabels[DocKind.other], 'Document');
    });
  });

  group('titleFromFilename', () {
    test('drops the path and the extension', () {
      expect(titleFromFilename('/storage/emulated/0/Download/Sony TV.pdf'),
          'Sony TV');
      expect(titleFromFilename(r'C:\Users\nuno\receipt.PDF'), 'receipt');
    });

    test('turns separators into spaces', () {
      expect(titleFromFilename('john-lewis_receipt-2024.pdf'),
          'john lewis receipt 2024');
    });

    test('leaves a camera filename alone', () {
      // Decoding it into a date was tried and dropped: a camera filename is
      // meaningless either way, and a wrong date is worse than an ugly one.
      expect(
          titleFromFilename('IMG_20240817_101233.jpg'), 'IMG 20240817 101233');
    });

    test('a dotfile keeps its name rather than becoming empty', () {
      expect(titleFromFilename('.gitignore'), '.gitignore');
    });

    test('gives back nothing when there is nothing', () {
      expect(titleFromFilename('___.pdf'), '');
      expect(titleFromFilename(''), '');
    });
  });

  group('docTitle', () {
    test('uses the file name when there is one', () {
      expect(docTitle(DocKind.receipt, 'Currys order'), 'Currys order');
    });

    test('falls back to what kind of thing it is', () {
      expect(docTitle(DocKind.receipt, ''), 'Receipt');
      expect(docTitle(DocKind.other, '   '), 'Document');
    });
  });

  group('mimeFor', () {
    test('knows the handful that matter', () {
      expect(mimeFor('a.PNG'), 'image/png');
      expect(mimeFor('a.jpeg'), 'image/jpeg');
      expect(mimeFor('a.heic'), 'image/heic');
      expect(mimeFor('receipt.pdf'), 'application/pdf');
    });

    /*
      Everything else is not a picture.

      The mime decides whether the app tries to draw the bytes, so an unknown
      guessing "image" produces a broken thumbnail on a row. Guessing the other
      way produces a document icon, which is correct often enough and harmless
      when it is not.
    */
    test('and everything else is bytes', () {
      expect(mimeFor('warranty.docx'), 'application/octet-stream');
      expect(mimeFor('noextension'), 'application/octet-stream');
    });
  });

  group('isImage', () {
    test('is true only for pictures', () {
      expect(isImage('image/png'), isTrue);
      expect(isImage('application/pdf'), isFalse);
      expect(isImage(null), isFalse);
    });
  });

  group('tidyUrl', () {
    /*
      People paste a bare host constantly, and a URL with no scheme opens
      nothing at all — `launchUrl` refuses it and the tile does nothing, which
      reads as the app being broken rather than the link being incomplete.
    */
    test('adds the scheme somebody did not paste', () {
      expect(tidyUrl('drive.google.com/file/d/abc'),
          'https://drive.google.com/file/d/abc');
    });

    test('leaves a real one alone', () {
      expect(tidyUrl('https://example.com/x'), 'https://example.com/x');
      expect(tidyUrl('  http://example.com  '), 'http://example.com');
    });

    test('refuses what could not possibly be an address', () {
      expect(tidyUrl(''), isNull);
      expect(tidyUrl('   '), isNull);
      expect(tidyUrl('my receipt'), isNull, reason: 'no dot, so no host');
      expect(tidyUrl('localhost'), isNull);
    });
  });

  group('PendingDoc', () {
    test('a link carries no bytes', () {
      const doc = PendingDoc(
        kind: DocKind.receipt,
        title: 'In my email',
        url: 'https://mail.example.com/x',
      );

      expect(doc.isLink, isTrue);
      expect(doc.sizeBytes, 0);
    });
  });
}
