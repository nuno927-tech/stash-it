/// Adding and editing an item, as the sheet the PWA uses.
///
/// The rules live in `logic/item_form.dart` and the vocabulary beside them.
/// This is the boxes.
///
/// ── Why this replaced a perfectly working screen ──────────────────────────
/// The old form was a `Scaffold` of `TextFormField`s with an app bar and a
/// Save action — correct, testable, and visibly a different app from the one
/// it was ported out of. Everything it asked was in one flat column, so the
/// warranty was eleven fields down and the receipt was nowhere, and a form
/// with no shape gives no clue which parts matter.
///
/// Five cards, in the order somebody actually knows the answers: what it is,
/// where it lives, what covers it, what proves it, when to be told.
///
/// ── Two thirds, and draggable ─────────────────────────────────────────────
/// Every other question in this app is asked in a sheet over the screen you
/// were on, and the add form was the one place that took the whole screen. The
/// form is longer than two thirds, so it opens there and pulls up — the height
/// is a starting position, not a cage.
library;

import 'dart:async';
// For `Uint8List` — the staged photograph. Was coming in via
// `flutter/services.dart`, which this file no longer needs for anything else.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/format.dart';
import '../logic/item_form.dart';
import '../logic/notify_offer.dart';
import '../logic/prefs.dart';
import '../models/types.dart';
import '../notify/sync.dart';
import '../logic/auto_advance.dart';
import 'auto_advance.dart';
import 'confirm_delete.dart';
import 'doc_tiles.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'pick_doc.dart';
import 'scout.dart';
import 'stash_the_paper.dart';
import 'theme.dart';
import 'thumb.dart';
import 'unlock_sheet.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showItemForm(
  BuildContext context, {
  required Repository repo,
  Item? existing,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _ItemFormSheet(repo: repo, existing: existing),
  );
}

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({required this.repo, this.existing});

  final Repository repo;
  final Item? existing;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  late final ItemDraft _draft =
      widget.existing == null ? ItemDraft() : draftOf(widget.existing!);

  /// Read once. A `FutureBuilder` handed a fresh future every frame reloads
  /// for ever.
  late Future<List<Room>> _rooms = widget.repo.rooms();

  /*
    ── Staged, then written ───────────────────────────────────────────────────

    A document row points at an item, and on the add form the item does not
    exist yet. See the note on `PendingDoc` for the two worse options.

    On an edit these are written the moment they are picked, so this list stays
    empty and `_filed` holds what is already there.
  */
  final List<PendingDoc> _pending = [];
  late Future<List<Doc>> _filed = widget.existing == null
      ? Future.value(const <Doc>[])
      : widget.repo.docsForItem(widget.existing!.id);

  /// The item's own picture, before there is an item to hang it on.
  Uint8List? _photo;

  String? _problem;
  bool _saving = false;

  /// Which policies have their extra fields open. By index, because a freshly
  /// added policy has no id yet.
  final Set<int> _detailed = {};

  final GlobalKey _roomCardKey = GlobalKey();
  final GlobalKey _warrantyCardKey = GlobalKey();
  final GlobalKey _attachmentsCardKey = GlobalKey();
  final GlobalKey _warningCardKey = GlobalKey();

  late final AutoAdvance _toRoom = AutoAdvance(_roomCardKey);
  late final AutoAdvance _toWarranty = AutoAdvance(_warrantyCardKey);
  late final AutoAdvance _toAttachments = AutoAdvance(_attachmentsCardKey);
  late final AutoAdvance _toWarning = AutoAdvance(_warningCardKey);

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();

    /*
      A form that opens with nothing selected is a form asking a question it
      could have answered. Every item has at least one policy — the add screen
      is mostly *about* the warranty — so the row is there from the start with
      the app's own default name on it, which is also what an unnamed policy is
      called everywhere it is displayed.

      It is dropped again on save if nobody touched it: `isBlank` covers a row
      with a label and nothing else. So the helpful default costs nothing when
      it was wrong.
    */
    if (_draft.coverages.isEmpty) {
      _draft.coverages.add(CoverageDraft(label: 'Warranty', unit: CoverageUnit.months));
    }

    /*
      And two weeks of warning, unless this item already says otherwise.

      The row used to offer "Default" — follow the global setting — and open on
      it. That option is gone, so a draft carrying null would open with nothing
      lit at all, which is worse than either. Every item now leaves this form
      with a real number on it.

      This does pin an older item that was following the setting, the first
      time it is edited. Accepted deliberately: the alternative is a lit button
      that does not match what is stored.
    */
    _draft.leadDays ??= itemLeadChoices.first.days;
  }

  @override
  void dispose() {
    _toRoom.dispose();
    _toWarranty.dispose();
    _toAttachments.dispose();
    _toWarning.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------- saving */

  Future<void> _save() async {
    final problem = whyNotSaveable(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      // The item's picture, written first so its id can go on the record.
      if (_photo != null) {
        final id = newId();
        await widget.repo.putBlob(id, _photo!, 'image/jpeg');
        _draft.photoBlobId = id;
        _draft.thumbBlobId = id;
      }

      final item = toItem(
        _draft,
        propertyId: widget.repo.propertyId,
        createdAt: widget.existing?.createdAt,
      );

      /*
        The id comes back from the insert, it is not on the draft.

        `toItem` leaves `id` empty for something new and the repository mints
        one — so writing the staged documents against `item.id` would file every
        one of them against an item called "", which is not an error anywhere:
        the insert succeeds, and the receipt simply never appears on anything.
      */
      final String itemId;
      if (_isNew) {
        itemId = await widget.repo.createItem(item);
      } else {
        await widget.repo.saveItem(item);
        itemId = item.id;
      }

      // And now there is something for the staged documents to point at.
      final attached = _pending.isNotEmpty;
      for (final doc in _pending) {
        await _write(doc, itemId);
      }
      _pending.clear();

      /*
        A saved item can move a reminder in either direction — adding cover
        creates one, deleting the purchase date removes one — so the schedule
        is rebuilt rather than added to. Not awaited: the form should close on
        the save, not on the notification tray.
      */
      unawaited(syncReminders(widget.repo));

      if (datedSave(
        purchaseDate: _draft.purchaseDate,
        hasCover: _draft.realCoverages.any((c) => c.hasTerm),
      )) {
        armNotifyOffer();
      }

      // Not `save` — that is what a settings toggle gets. This is the app
      // doing the one thing it is for. See the note on `Cue.stashed`.
      feedback(Cue.stashed);

      /*
        The paper reminder, on a new item only, and only when nothing was
        attached.

        Being told to go and file the receipt immediately after filing the
        receipt is the kind of nagging that gets an app's own advice ignored —
        and the tiles are right there on this form now, which is the whole
        reason the check is worth making.
      */
      if (_isNew && !attached && mounted) {
        await showStashThePaper(context);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      /*
        The wall, and the way through it, in the same moment.

        Showing the sentence alone leaves somebody holding a filled-in form
        with nowhere to go — and the form is still filled in behind this
        sheet, so unlocking and pressing Save again works with nothing
        retyped. That is the whole reason the offer opens here rather than
        sending them to Settings.
      */
      setState(() => _problem = e.message);
      if (!mounted) return;

      final unlocked = await showUnlock(
        context,
        repo: widget.repo,
        billing: appBilling,
        count: e.count,
      );

      // Straight back into the save they were already trying to make.
      if (unlocked && mounted) {
        setState(() => _problem = null);
        await _save();
      }
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// One staged document, onto an item that now exists.
  Future<void> _write(PendingDoc doc, String itemId) async {
    String? blobId;

    if (doc.bytes != null) {
      blobId = newId();
      await widget.repo.putBlob(blobId, doc.bytes!, doc.mime ?? 'application/octet-stream');
    }

    await widget.repo.createDoc(Doc(
      id: '',
      itemId: itemId,
      kind: doc.kind,
      title: doc.title,
      blobId: blobId,
      url: doc.url,
    ));
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.name);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeleteItem(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /* ---------------------------------------------------------- attaching */

  Future<void> _attach(DocKind kind) async {
    // The tile said what kind of thing this is; this asks where it comes from.
    final source = await askPickSource(
      context,
      title: 'Add a ${docKindLabels[kind]!.toLowerCase()}',
    );
    if (source == null || source == PickSource.remove || !mounted) return;

    final picked = await pickDocs(kind, source);
    if (picked.isEmpty || !mounted) return;

    // Nothing to point at yet, so hold them. Written in `_save`.
    if (_isNew) {
      setState(() => _pending.addAll(picked));
      return;
    }

    for (final doc in picked) {
      await _write(doc, widget.existing!.id);
    }
    if (mounted) setState(() => _filed = widget.repo.docsForItem(widget.existing!.id));
  }

  Future<void> _attachLink() async {
    final doc = await askForLink(context);
    if (doc == null || !mounted) return;

    if (_isNew) {
      setState(() => _pending.add(doc));
      return;
    }

    await _write(doc, widget.existing!.id);
    if (mounted) setState(() => _filed = widget.repo.docsForItem(widget.existing!.id));
  }

  /*
    Asked after the tap, not before it.

    The tile used to be two controls in one shape — the body opened the file
    picker and a corner opened the camera — which meant guessing which of two
    identical camera glyphs did which. One target, then one question.
  */
  Future<void> _pickPhoto() async {
    final source = await askPickSource(
      context,
      title: 'Take or upload photo',
      canRemove: _photo != null || _draft.thumbBlobId != null,
      removeLabel: 'Remove the photo',
      removeNote: 'The item keeps everything else',
    );
    if (source == null || !mounted) return;

    switch (source) {
      case PickSource.camera:
        await _takePhoto();
      case PickSource.files:
        await _choosePhoto();
      case PickSource.remove:
        setState(() {
          _photo = null;
          // Both, because they are the same blob — see `_save`. Clearing one
          // would leave the list drawing a thumbnail for a photograph the
          // detail screen no longer has.
          _draft.photoBlobId = null;
          _draft.thumbBlobId = null;
        });
    }
  }

  Future<void> _takePhoto() async {
    final shots = await pickDocs(DocKind.photo, PickSource.camera);
    if (shots.isEmpty || shots.first.bytes == null || !mounted) return;

    setState(() => _photo = shots.first.bytes);
  }

  Future<void> _choosePhoto() async {
    final picked = await pickDocs(DocKind.photo, PickSource.files);

    // Only a picture. The file picker will happily return a PDF, and a PDF as
    // an item's thumbnail is a grey box on every row it appears on.
    final images = picked.where((d) => isImage(d.mime) && d.bytes != null).toList();
    if (images.isEmpty || !mounted) return;

    setState(() => _photo = images.first.bytes);
  }

  /* -------------------------------------------------------------- dates */

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_draft.purchaseDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      // A purchase date in the future is not a purchase date.
      lastDate: now,
    );

    if (picked == null) return;
    feedback(Cue.tap);
    setState(() {
      _draft.purchaseDate = '${picked.year.toString().padLeft(4, '0')}'
          '-${picked.month.toString().padLeft(2, '0')}'
          '-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  /* --------------------------------------------------------------- room */

  Future<void> _newRoom() async {
    final name = await _askName(context, title: 'New room', hint: 'Kitchen, garage, loft');
    if (name == null || name.trim().isEmpty) return;

    final id = await widget.repo.createRoom(name.trim());
    if (!mounted) return;

    setState(() {
      _rooms = widget.repo.rooms();
      _draft.roomId = id;
    });
  }

  /* -------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      Just under the tab heading — see `sheetTop`.

      This one was missed when the other two were changed: it had a comment
      sitting between `minChildSize` and `maxChildSize` that the other two did
      not, so the edit that found them by their exact shape walked straight
      past it. Three files that should say the same thing, and the only reason
      two matched was that they had been typed the same way.
    */
    final top = sheetTop(context);

    /*
      ── Four hand-offs, and the first will hardly ever fire ─────────────────

      Product information lists nine things, one of which is a Notes box
      nobody fills in. That card will almost never advance, and that is the
      design rather than a shortfall — see `cardFilled`. Watching only the name
      would throw somebody past the price, the date and the serial number the
      moment they typed "Kettle".

      The three after it are short enough to complete in passing, which is
      where this earns its keep.
    */
    _toRoom.update(
      context,
      complete: cardFilled([
        _draft.name,
        _draft.purchaseDate,
        _draft.priceText,
        _draft.brand,
        _draft.model,
        _draft.serial,
        _draft.retailer,
        _draft.notes,
        _photo ?? _draft.thumbBlobId,
      ]),
    );

    _toWarranty.update(context, complete: cardFilled([_draft.roomId]));

    // Every policy on the card, not just the first: adding a second one means
    // the card is unfinished again until it has a length too.
    _toAttachments.update(
      context,
      complete: _draft.coverages.isNotEmpty &&
          _draft.coverages.every((cov) => cardFilled([
                cov.label,
                if (cov.unit != CoverageUnit.lifetime) cov.amountText,
              ])),
    );

    // Attachments has no fields, so "finished" is "something was attached".
    // Nothing is required here — the card is skippable and usually skipped —
    // so this only ever helps the person who did stop to file a receipt.
    _toWarning.update(context, complete: _pending.isNotEmpty);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: top,
      minChildSize: 0.4,
      maxChildSize: top,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                _productCard(c),
                const SizedBox(height: 14),
                KeyedSubtree(key: _roomCardKey, child: _roomCard(c)),
                const SizedBox(height: 14),
                KeyedSubtree(key: _warrantyCardKey, child: _warrantyCard(c)),
                const SizedBox(height: 14),
                KeyedSubtree(key: _attachmentsCardKey, child: _attachmentsCard(c)),
                const SizedBox(height: 14),
                KeyedSubtree(key: _warningCardKey, child: _warningCard(c)),

                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: Icon(Icons.delete_outline, size: 18, color: c.ember),
                      label: Text(
                        'Delete this item',
                        style: TextStyle(fontFamily: fontBody, color: c.ember),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _footer(c),
        ],
      ),
    );
  }

  /* ------------------------------------------------- product information */

  Widget _productCard(StashColors c) {
    return SheetCard(
      title: 'Product information',
      // Glasses on, taking it down. Top right, out of the way of the fields.
      trailing: const Scout(
        pose: ScoutPose.clipboard,
        height: 74,
        motion: [ScoutMotion.breathe],
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
              The staged bytes win over the saved blob, because they are what
              will be written on save. Without the FutureBuilder an edit opened
              on an empty tile for an item that plainly had a photograph, which
              reads as the app having lost it.
            */
            if (_photo != null)
              _PhotoTile(image: MemoryImage(_photo!), onTap: _pickPhoto)
            else
              FutureBuilder<ImageProvider?>(
                future: thumbFor(widget.repo, _draft.thumbBlobId),
                builder: (context, snap) =>
                    _PhotoTile(image: snap.data, onTap: _pickPhoto),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Product name'),
                  TextBox(
                    initial: _draft.name,
                    hint: 'What is it?',
                    autofocus: _isNew,
                    big: true,
                    onChanged: (v) => _draft.name = v,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const FieldLabel('When did you buy it?'),
        DateBox(value: _draft.purchaseDate, onTap: _pickDate),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Price'),
                  TextBox(
                    initial: _draft.priceText,
                    hint: '0.00',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    // Formats as you type rather than on blur. Correcting a
                    // field afterwards makes people wonder whether they typed
                    // it wrong.
                    format: (v) => formatMoneyInput(v, _draft.currency),
                    onChanged: (v) => _draft.priceText = v,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Brand'),
                  TextBox(
                    initial: _draft.brand,
                    hint: 'Optional',
                    onChanged: (v) => _draft.brand = v,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Model'),
                  TextBox(
                    initial: _draft.model,
                    hint: 'Optional',
                    onChanged: (v) => _draft.model = v,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*
                    Serial is on the face of the form rather than behind a
                    "more" disclosure, because it is the field people come back
                    for. Somebody making a claim is reading it off a plate with
                    a torch, and the search matches on any four characters of
                    it — see logic/search.dart.
                  */
                  const FieldLabel('Serial number'),
                  TextBox(
                    initial: _draft.serial,
                    hint: 'Optional',
                    onChanged: (v) => _draft.serial = v,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const FieldLabel('Retailer'),
        TextBox(
          initial: _draft.retailer,
          hint: 'Optional',
          onChanged: (v) => _draft.retailer = v,
        ),
        const SizedBox(height: 12),

        const FieldLabel('Notes'),
        TextBox(
          initial: _draft.notes,
          hint: 'Optional',
          lines: 4,
          onChanged: (v) => _draft.notes = v,
        ),
      ],
    );
  }

  /* --------------------------------------------------------------- room */

  Widget _roomCard(StashColors c) {
    return SheetCard(
      title: 'Room',
      action: _Pill(label: 'New room', onTap: _newRoom),
      children: [
        FutureBuilder<List<Room>>(
          future: _rooms,
          builder: (context, snap) {
            final rooms = snap.data ?? const <Room>[];

            // A roomId pointing at a room that no longer exists must not be
            // handed to the dropdown — it throws rather than showing blank.
            final known = rooms.any((r) => r.id == _draft.roomId);

            return WhiteField(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: known ? _draft.roomId : null,
                  isExpanded: true,
                  dropdownColor: c.slate700,
                  icon: Icon(Icons.expand_more, color: c.muted),
                  style: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.text),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Not assigned',
                        style: TextStyle(fontFamily: fontBody, color: c.text),
                      ),
                    ),
                    for (final room in rooms)
                      DropdownMenuItem(value: room.id, child: Text(room.name)),
                  ],
                  onChanged: (v) {
                    feedback(Cue.tap);
                    setState(() => _draft.roomId = v);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /* ----------------------------------------------------------- warranty */

  Widget _warrantyCard(StashColors c) {
    return SheetCard(
      title: 'Warranty information',
      children: [
        for (var i = 0; i < _draft.coverages.length; i++) ...[
          if (i > 0) Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(height: 1, color: c.line),
          ),
          _coverage(c, i),
        ],
        const SizedBox(height: 14),

        /*
          A list, not two fixed slots.

          A couch has a lifetime frame, ten years on the cushions, five on the
          springs and one on the fabric. Two slots hold two of those and quietly
          lose the rest — and the one that matters is the shortest, because that
          is the one that will actually stop covering you.
        */
        _Pill(
          label: '+ Add another policy',
          onTap: () => setState(() => _draft.coverages.add(CoverageDraft(
                label: 'Warranty',
                unit: CoverageUnit.months,
              ))),
        ),
      ],
    );
  }

  Widget _coverage(StashColors c, int i) {
    final cov = _draft.coverages[i];
    final custom = isCustomLabel(cov.label);
    final presets = coveragePresets[cov.unit]!;
    final lifetime = cov.unit == CoverageUnit.lifetime;
    final customTerm = isCustomTerm(cov.unit, cov.amountText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Warranty',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const Spacer(),
            if (_draft.coverages.length > 1)
              IconButton(
                onPressed: () => setState(() {
                  _draft.coverages.removeAt(i);
                  _detailed.remove(i);
                }),
                icon: Icon(Icons.close, size: 18, color: c.muted),
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove this policy',
              ),
          ],
        ),
        const SizedBox(height: 10),

        /*
          ── The name is chosen, not typed ─────────────────────────────────

          A free-text box asked people to invent the vocabulary and got back
          "warranty", "Warranty" and "3yr warr" for the same idea. Six buttons
          are the vocabulary; Custom is the way out, and it asks properly
          rather than leaving an empty field in front of everybody who did not
          need one.
        */
        SegRow<String?>(
          // Null when the name came from Custom, so neither row lights up
          // something the person did not choose.
          value: custom ? null : cov.label,
          options: [
            for (final name in coverageLabels.take(3)) (name, name),
          ],
          onPick: (v) => setState(() => cov.label = v!),
        ),
        const SizedBox(height: 8),
        SegRow<String>(
          value: custom ? '' : cov.label,
          options: [
            for (final name in coverageLabels.skip(3)) (name, name),
            // Shows the custom name once there is one, so the row still says
            // what it is without a separate field repeating it back.
            ('', custom ? cov.label : 'Custom'),
          ],
          onPick: (v) async {
            if (v.isNotEmpty) {
              setState(() => cov.label = v);
              return;
            }

            final name = await _askName(
              context,
              title: 'Call it what it is',
              hint: 'Roof guarantee, screen cover',
              initial: custom ? cov.label : '',
            );
            if (name == null || name.trim().isEmpty) return;
            setState(() => cov.label = name.trim());
          },
        ),
        const SizedBox(height: 8),

        SegRow<CoverageUnit>(
          value: cov.unit,
          options: [
            for (final unit in CoverageUnit.values) (unit, coverageUnitLabels[unit]!),
          ],
          onPick: (v) => setState(() => cov.unit = v),
        ),

        /*
          The quick numbers, and they are not round ones.

          14, 30, 90, 180 — 3, 6, 12, 18, 24 — 1, 2, 3, 5, 10. These are what
          is printed on warranties. A row of 10/20/30 would be tidy and would
          be a number nobody has to enter.
        */
        if (!lifetime) ...[
          const SizedBox(height: 12),
          // Wrap rather than Row. Six items whose widths depend on the numbers
          // in them ("180", "Custom", and whatever somebody typed) will
          // eventually not fit, and a Row's answer to that is a yellow
          // overflow bar across the form.
          // Full width, or `spaceBetween` has nothing to space against — a
          // Wrap sizes to its content inside a Column that aligns to the start.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 2,
              children: [
                for (final n in presets)
                  _Number(
                    label: '$n',
                    on: !customTerm && int.tryParse(cov.amountText.trim()) == n,
                    onTap: () => setState(() => cov.amountText = '$n'),
                  ),
                _Number(
                  label: customTerm ? cov.amountText.trim() : 'Custom',
                  on: customTerm,
                  onTap: () async {
                    final typed = await _askName(
                      context,
                      title: 'How long?',
                      hint: 'A number of ${coverageUnitLabels[cov.unit]!.toLowerCase()}',
                      initial: cov.amountText,
                      number: true,
                    );
                    if (typed == null) return;
                    setState(() => cov.amountText = typed.trim());
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        /*
          The rest of a policy behind one press.

          Who underwrites it, a policy number, a phone number, what it actually
          covers — real fields that matter at claim time and that nobody has to
          hand while they are photographing a kettle. Shown open when there is
          already something in them, so an edit never hides what is there.
        */
        _Pill(
          label: 'Additional details',
          on: _detailed.contains(i) || _hasDetails(cov),
          onTap: () => setState(() {
            if (!_detailed.remove(i)) _detailed.add(i);
          }),
        ),

        if (_detailed.contains(i) || _hasDetails(cov)) ...[
          const SizedBox(height: 12),
          const FieldLabel('What it covers'),
          TextBox(
            initial: cov.covers,
            hint: 'Parts and labor, not accidental damage',
            onChanged: (v) => cov.covers = v,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Who covers it'),
                    TextBox(
                      initial: cov.provider,
                      hint: 'Optional',
                      onChanged: (v) => cov.provider = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Policy number'),
                    TextBox(
                      initial: cov.policyNumber,
                      hint: 'Optional',
                      onChanged: (v) => cov.policyNumber = v,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _hasDetails(CoverageDraft cov) =>
      cov.covers.trim().isNotEmpty ||
      cov.provider.trim().isNotEmpty ||
      cov.policyNumber.trim().isNotEmpty;

  /* -------------------------------------------------------- attachments */

  Widget _attachmentsCard(StashColors c) {
    return SheetCard(
      title: 'Attachments',
      children: [
        Text(
          'The receipt and the warranty are the two a claim will ask for. Tap '
          'to choose a file, the camera to photograph it, or the last one to '
          'link to something on the web.',
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 14),
        DocTiles(onPick: _attach, onLink: _attachLink),

        // What is already on the item, on an edit.
        FutureBuilder<List<Doc>>(
          future: _filed,
          builder: (context, snap) {
            final docs = snap.data ?? const <Doc>[];
            if (docs.isEmpty) return const SizedBox.shrink();

            return Column(
              children: [
                const SizedBox(height: 14),
                for (final doc in docs)
                  _DocRow(
                    kind: doc.kind,
                    title: doc.title ?? docKindLabels[doc.kind]!,
                    note: doc.isLocal ? 'On this phone' : 'A link',
                  ),
              ],
            );
          },
        ),

        // And what is staged, on a new one.
        if (_pending.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < _pending.length; i++)
            _DocRow(
              kind: _pending[i].kind,
              title: _pending[i].title,
              note: _pending[i].isLink
                  ? 'A link'
                  : '${(_pending[i].sizeBytes / 1024).round()} KB',
              onRemove: () => setState(() => _pending.removeAt(i)),
            ),
        ],
      ],
    );
  }

  /* ------------------------------------------------------------ warning */

  Widget _warningCard(StashColors c) {
    return SheetCard(
      title: 'How much warning',
      children: [
        /*
          Per-item notice. A roof and a kettle do not deserve the same warning,
          and thirty days is useless for anything needing a quote and a
          tradesman.

          "Default" is a real, selectable option rather than an absence, or
          there is no way back once somebody has picked a number.
        */
        SegRow<int?>(
          value: _draft.leadDays,
          options: [
            for (final choice in itemLeadChoices) (choice.days, choice.label),
          ],
          lines: 1,
          onPick: (v) => setState(() => _draft.leadDays = v),
        ),
        const SizedBox(height: 12),
        Text(
          'Turns the item amber on the dashboard, and sends a notification if '
          'you have them on.',
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
      ],
    );
  }

  /* ------------------------------------------------------------- footer */

  Widget _footer(StashColors c) => SheetFooter(
        label: _isNew ? 'Save item' : 'Save changes',
        // Said before the button is pressed rather than after. The one refusal
        // this form makes, in the one place somebody is already looking.
        problem: _problem ?? whyNotSaveable(_draft),
        onSave: _saving ? null : _save,
      );

}

/* ------------------------------------------------------------- the pieces */

/// A titled card, with an optional control or a squirrel in the corner.


/// The white rounded shape every input sits in.



/// A row of choices in one pill, one of them lit.

/// One of the quick lengths. Bare text, not a button — the row is a scale, and
/// six outlined boxes would weigh more than the field they are filling in.
class _Number extends StatelessWidget {
  const _Number({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: () {
        feedback(Cue.tap);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 15,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? c.gold : c.muted,
          ),
        ),
      ),
    );
  }
}

/// An outlined chip. "New room", "Additional details", "+ Add another policy".
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.on = false});

  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          feedback(Cue.tap);
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? c.washGold : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? c.washGoldLine : c.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: on ? c.gold : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The item's own picture. Dashed while empty, because an empty dashed box is
/// the one shape everybody already reads as "put something here".
/// The item's own picture.
///
/// ── One camera, one tap ───────────────────────────────────────────────────
/// This had two: a camera in the middle of the tile that opened the file
/// picker, and a second camera in the corner that opened the actual camera.
/// Two identical glyphs doing different things is worse than either one alone,
/// and the one that looked most like "take a photo" was the one that did not.
///
/// So the tile is a single target and the question is asked afterwards, which
/// is also the honest order: the decision is "put a picture here", and where
/// it comes from is a detail of that.
///
/// Deliberately unlike the attachment tiles below, which keep their split
/// control — those are six tiles and asking twice per tile would be twelve
/// taps of overhead. This is one.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.image, required this.onTap});

  /// The staged bytes, or the saved photograph on an edit. Null for neither.
  final ImageProvider? image;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 104,
        height: 104,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.slate800,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: c.line),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 24, color: c.muted),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Take or upload photo',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 11,
                        height: 1.25,
                        color: c.muted,
                      ),
                    ),
                  ),
                ],
              )
            : Image(image: image!, fit: BoxFit.cover),
      ),
    );
  }
}

/// One attached document, staged or filed.
class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.kind,
    required this.title,
    required this.note,
    this.onRemove,
  });

  final DocKind kind;
  final String title;
  final String note;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          DocGlyph(kind, color: c.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(fontFamily: fontBody, fontSize: 11.5, color: c.muted),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 16, color: c.muted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Asks for one short string.
///
/// A sheet rather than an `AlertDialog`, so the keyboard has somewhere to go
/// and it matches every other question the app asks.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
  bool number = false,
}) async {
  final c = StashColors.of(context);
  final field = TextEditingController(text: initial);

  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: field,
            autofocus: true,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            textCapitalization:
                number ? TextCapitalization.none : TextCapitalization.sentences,
            style: TextStyle(fontFamily: fontBody, fontSize: 16, color: c.text),
            onSubmitted: (_) => Navigator.of(context).pop(true),
            // Filled, and nothing else. Setting only `border` leaves the
            // theme's `enabledBorder` in place — see `bareInput`.
            decoration: sunkenInput(hint: hint, fill: c.slate600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.onGold,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: c.onGold,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  final text = ok == true ? field.text : null;
  field.dispose();
  return text;
}
