// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tables.dart';

// ignore_for_file: type=lint
class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _propertyIdMeta =
      const VerificationMeta('propertyId');
  @override
  late final GeneratedColumn<String> propertyId = GeneratedColumn<String>(
      'property_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
      'serial', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
      'room_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchaseDateMeta =
      const VerificationMeta('purchaseDate');
  @override
  late final GeneratedColumn<String> purchaseDate = GeneratedColumn<String>(
      'purchase_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchasePriceCentsMeta =
      const VerificationMeta('purchasePriceCents');
  @override
  late final GeneratedColumn<int> purchasePriceCents = GeneratedColumn<int>(
      'purchase_price_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retailerMeta =
      const VerificationMeta('retailer');
  @override
  late final GeneratedColumn<String> retailer = GeneratedColumn<String>(
      'retailer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coveragesJsonMeta =
      const VerificationMeta('coveragesJson');
  @override
  late final GeneratedColumn<String> coveragesJson = GeneratedColumn<String>(
      'coverages_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _warrantyJsonMeta =
      const VerificationMeta('warrantyJson');
  @override
  late final GeneratedColumn<String> warrantyJson = GeneratedColumn<String>(
      'warranty_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _extendedWarrantyJsonMeta =
      const VerificationMeta('extendedWarrantyJson');
  @override
  late final GeneratedColumn<String> extendedWarrantyJson =
      GeneratedColumn<String>('extended_warranty_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leadDaysMeta =
      const VerificationMeta('leadDays');
  @override
  late final GeneratedColumn<int> leadDays = GeneratedColumn<int>(
      'lead_days', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thumbBlobIdMeta =
      const VerificationMeta('thumbBlobId');
  @override
  late final GeneratedColumn<String> thumbBlobId = GeneratedColumn<String>(
      'thumb_blob_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _photoBlobIdMeta =
      const VerificationMeta('photoBlobId');
  @override
  late final GeneratedColumn<String> photoBlobId = GeneratedColumn<String>(
      'photo_blob_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        propertyId,
        name,
        brand,
        model,
        serial,
        roomId,
        purchaseDate,
        purchasePriceCents,
        currency,
        retailer,
        coveragesJson,
        warrantyJson,
        extendedWarrantyJson,
        leadDays,
        notes,
        thumbBlobId,
        photoBlobId,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(Insertable<ItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('property_id')) {
      context.handle(
          _propertyIdMeta,
          propertyId.isAcceptableOrUnknown(
              data['property_id']!, _propertyIdMeta));
    } else if (isInserting) {
      context.missing(_propertyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('serial')) {
      context.handle(_serialMeta,
          serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    }
    if (data.containsKey('room_id')) {
      context.handle(_roomIdMeta,
          roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta));
    }
    if (data.containsKey('purchase_date')) {
      context.handle(
          _purchaseDateMeta,
          purchaseDate.isAcceptableOrUnknown(
              data['purchase_date']!, _purchaseDateMeta));
    }
    if (data.containsKey('purchase_price_cents')) {
      context.handle(
          _purchasePriceCentsMeta,
          purchasePriceCents.isAcceptableOrUnknown(
              data['purchase_price_cents']!, _purchasePriceCentsMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('retailer')) {
      context.handle(_retailerMeta,
          retailer.isAcceptableOrUnknown(data['retailer']!, _retailerMeta));
    }
    if (data.containsKey('coverages_json')) {
      context.handle(
          _coveragesJsonMeta,
          coveragesJson.isAcceptableOrUnknown(
              data['coverages_json']!, _coveragesJsonMeta));
    }
    if (data.containsKey('warranty_json')) {
      context.handle(
          _warrantyJsonMeta,
          warrantyJson.isAcceptableOrUnknown(
              data['warranty_json']!, _warrantyJsonMeta));
    }
    if (data.containsKey('extended_warranty_json')) {
      context.handle(
          _extendedWarrantyJsonMeta,
          extendedWarrantyJson.isAcceptableOrUnknown(
              data['extended_warranty_json']!, _extendedWarrantyJsonMeta));
    }
    if (data.containsKey('lead_days')) {
      context.handle(_leadDaysMeta,
          leadDays.isAcceptableOrUnknown(data['lead_days']!, _leadDaysMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('thumb_blob_id')) {
      context.handle(
          _thumbBlobIdMeta,
          thumbBlobId.isAcceptableOrUnknown(
              data['thumb_blob_id']!, _thumbBlobIdMeta));
    }
    if (data.containsKey('photo_blob_id')) {
      context.handle(
          _photoBlobIdMeta,
          photoBlobId.isAcceptableOrUnknown(
              data['photo_blob_id']!, _photoBlobIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      propertyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}property_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand']),
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model']),
      serial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial']),
      roomId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_id']),
      purchaseDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purchase_date']),
      purchasePriceCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}purchase_price_cents']),
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency']),
      retailer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}retailer']),
      coveragesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}coverages_json'])!,
      warrantyJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}warranty_json']),
      extendedWarrantyJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}extended_warranty_json']),
      leadDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lead_days']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      thumbBlobId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumb_blob_id']),
      photoBlobId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_blob_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String propertyId;
  final String name;
  final String? brand;
  final String? model;
  final String? serial;
  final String? roomId;

  /// `YYYY-MM-DD`, kept as text.
  ///
  /// A purchase date is a calendar date, not a moment — 15 January is 15
  /// January in every timezone the phone is ever carried through. Storing it
  /// as an instant would make it shift when someone flies, and every countdown
  /// in the app is measured from it.
  final String? purchaseDate;
  final int? purchasePriceCents;
  final String? currency;
  final String? retailer;
  final String coveragesJson;

  /// The two pre-`coverages` fields, still stored so older records keep their
  /// warranty. Read through `coveragesOf`, never directly.
  final String? warrantyJson;
  final String? extendedWarrantyJson;

  /// How much notice this item wants. Null means "use the setting"; zero is a
  /// real answer meaning "tell me on the day".
  final int? leadDays;
  final String? notes;
  final String? thumbBlobId;
  final String? photoBlobId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Set rather than deleted. The bin is a thirty-day recovery window, and it
  /// only works because nothing is actually removed until the sweep runs.
  final DateTime? deletedAt;
  const ItemRow(
      {required this.id,
      required this.propertyId,
      required this.name,
      this.brand,
      this.model,
      this.serial,
      this.roomId,
      this.purchaseDate,
      this.purchasePriceCents,
      this.currency,
      this.retailer,
      required this.coveragesJson,
      this.warrantyJson,
      this.extendedWarrantyJson,
      this.leadDays,
      this.notes,
      this.thumbBlobId,
      this.photoBlobId,
      this.createdAt,
      this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['property_id'] = Variable<String>(propertyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || serial != null) {
      map['serial'] = Variable<String>(serial);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    if (!nullToAbsent || purchaseDate != null) {
      map['purchase_date'] = Variable<String>(purchaseDate);
    }
    if (!nullToAbsent || purchasePriceCents != null) {
      map['purchase_price_cents'] = Variable<int>(purchasePriceCents);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || retailer != null) {
      map['retailer'] = Variable<String>(retailer);
    }
    map['coverages_json'] = Variable<String>(coveragesJson);
    if (!nullToAbsent || warrantyJson != null) {
      map['warranty_json'] = Variable<String>(warrantyJson);
    }
    if (!nullToAbsent || extendedWarrantyJson != null) {
      map['extended_warranty_json'] = Variable<String>(extendedWarrantyJson);
    }
    if (!nullToAbsent || leadDays != null) {
      map['lead_days'] = Variable<int>(leadDays);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || thumbBlobId != null) {
      map['thumb_blob_id'] = Variable<String>(thumbBlobId);
    }
    if (!nullToAbsent || photoBlobId != null) {
      map['photo_blob_id'] = Variable<String>(photoBlobId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      propertyId: Value(propertyId),
      name: Value(name),
      brand:
          brand == null && nullToAbsent ? const Value.absent() : Value(brand),
      model:
          model == null && nullToAbsent ? const Value.absent() : Value(model),
      serial:
          serial == null && nullToAbsent ? const Value.absent() : Value(serial),
      roomId:
          roomId == null && nullToAbsent ? const Value.absent() : Value(roomId),
      purchaseDate: purchaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseDate),
      purchasePriceCents: purchasePriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePriceCents),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      retailer: retailer == null && nullToAbsent
          ? const Value.absent()
          : Value(retailer),
      coveragesJson: Value(coveragesJson),
      warrantyJson: warrantyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyJson),
      extendedWarrantyJson: extendedWarrantyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extendedWarrantyJson),
      leadDays: leadDays == null && nullToAbsent
          ? const Value.absent()
          : Value(leadDays),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      thumbBlobId: thumbBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbBlobId),
      photoBlobId: photoBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(photoBlobId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      propertyId: serializer.fromJson<String>(json['propertyId']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      model: serializer.fromJson<String?>(json['model']),
      serial: serializer.fromJson<String?>(json['serial']),
      roomId: serializer.fromJson<String?>(json['roomId']),
      purchaseDate: serializer.fromJson<String?>(json['purchaseDate']),
      purchasePriceCents: serializer.fromJson<int?>(json['purchasePriceCents']),
      currency: serializer.fromJson<String?>(json['currency']),
      retailer: serializer.fromJson<String?>(json['retailer']),
      coveragesJson: serializer.fromJson<String>(json['coveragesJson']),
      warrantyJson: serializer.fromJson<String?>(json['warrantyJson']),
      extendedWarrantyJson:
          serializer.fromJson<String?>(json['extendedWarrantyJson']),
      leadDays: serializer.fromJson<int?>(json['leadDays']),
      notes: serializer.fromJson<String?>(json['notes']),
      thumbBlobId: serializer.fromJson<String?>(json['thumbBlobId']),
      photoBlobId: serializer.fromJson<String?>(json['photoBlobId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'propertyId': serializer.toJson<String>(propertyId),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'model': serializer.toJson<String?>(model),
      'serial': serializer.toJson<String?>(serial),
      'roomId': serializer.toJson<String?>(roomId),
      'purchaseDate': serializer.toJson<String?>(purchaseDate),
      'purchasePriceCents': serializer.toJson<int?>(purchasePriceCents),
      'currency': serializer.toJson<String?>(currency),
      'retailer': serializer.toJson<String?>(retailer),
      'coveragesJson': serializer.toJson<String>(coveragesJson),
      'warrantyJson': serializer.toJson<String?>(warrantyJson),
      'extendedWarrantyJson': serializer.toJson<String?>(extendedWarrantyJson),
      'leadDays': serializer.toJson<int?>(leadDays),
      'notes': serializer.toJson<String?>(notes),
      'thumbBlobId': serializer.toJson<String?>(thumbBlobId),
      'photoBlobId': serializer.toJson<String?>(photoBlobId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ItemRow copyWith(
          {String? id,
          String? propertyId,
          String? name,
          Value<String?> brand = const Value.absent(),
          Value<String?> model = const Value.absent(),
          Value<String?> serial = const Value.absent(),
          Value<String?> roomId = const Value.absent(),
          Value<String?> purchaseDate = const Value.absent(),
          Value<int?> purchasePriceCents = const Value.absent(),
          Value<String?> currency = const Value.absent(),
          Value<String?> retailer = const Value.absent(),
          String? coveragesJson,
          Value<String?> warrantyJson = const Value.absent(),
          Value<String?> extendedWarrantyJson = const Value.absent(),
          Value<int?> leadDays = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<String?> thumbBlobId = const Value.absent(),
          Value<String?> photoBlobId = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      ItemRow(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        name: name ?? this.name,
        brand: brand.present ? brand.value : this.brand,
        model: model.present ? model.value : this.model,
        serial: serial.present ? serial.value : this.serial,
        roomId: roomId.present ? roomId.value : this.roomId,
        purchaseDate:
            purchaseDate.present ? purchaseDate.value : this.purchaseDate,
        purchasePriceCents: purchasePriceCents.present
            ? purchasePriceCents.value
            : this.purchasePriceCents,
        currency: currency.present ? currency.value : this.currency,
        retailer: retailer.present ? retailer.value : this.retailer,
        coveragesJson: coveragesJson ?? this.coveragesJson,
        warrantyJson:
            warrantyJson.present ? warrantyJson.value : this.warrantyJson,
        extendedWarrantyJson: extendedWarrantyJson.present
            ? extendedWarrantyJson.value
            : this.extendedWarrantyJson,
        leadDays: leadDays.present ? leadDays.value : this.leadDays,
        notes: notes.present ? notes.value : this.notes,
        thumbBlobId: thumbBlobId.present ? thumbBlobId.value : this.thumbBlobId,
        photoBlobId: photoBlobId.present ? photoBlobId.value : this.photoBlobId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      propertyId:
          data.propertyId.present ? data.propertyId.value : this.propertyId,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      serial: data.serial.present ? data.serial.value : this.serial,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      purchaseDate: data.purchaseDate.present
          ? data.purchaseDate.value
          : this.purchaseDate,
      purchasePriceCents: data.purchasePriceCents.present
          ? data.purchasePriceCents.value
          : this.purchasePriceCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      retailer: data.retailer.present ? data.retailer.value : this.retailer,
      coveragesJson: data.coveragesJson.present
          ? data.coveragesJson.value
          : this.coveragesJson,
      warrantyJson: data.warrantyJson.present
          ? data.warrantyJson.value
          : this.warrantyJson,
      extendedWarrantyJson: data.extendedWarrantyJson.present
          ? data.extendedWarrantyJson.value
          : this.extendedWarrantyJson,
      leadDays: data.leadDays.present ? data.leadDays.value : this.leadDays,
      notes: data.notes.present ? data.notes.value : this.notes,
      thumbBlobId:
          data.thumbBlobId.present ? data.thumbBlobId.value : this.thumbBlobId,
      photoBlobId:
          data.photoBlobId.present ? data.photoBlobId.value : this.photoBlobId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('serial: $serial, ')
          ..write('roomId: $roomId, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('purchasePriceCents: $purchasePriceCents, ')
          ..write('currency: $currency, ')
          ..write('retailer: $retailer, ')
          ..write('coveragesJson: $coveragesJson, ')
          ..write('warrantyJson: $warrantyJson, ')
          ..write('extendedWarrantyJson: $extendedWarrantyJson, ')
          ..write('leadDays: $leadDays, ')
          ..write('notes: $notes, ')
          ..write('thumbBlobId: $thumbBlobId, ')
          ..write('photoBlobId: $photoBlobId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        propertyId,
        name,
        brand,
        model,
        serial,
        roomId,
        purchaseDate,
        purchasePriceCents,
        currency,
        retailer,
        coveragesJson,
        warrantyJson,
        extendedWarrantyJson,
        leadDays,
        notes,
        thumbBlobId,
        photoBlobId,
        createdAt,
        updatedAt,
        deletedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.propertyId == this.propertyId &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.serial == this.serial &&
          other.roomId == this.roomId &&
          other.purchaseDate == this.purchaseDate &&
          other.purchasePriceCents == this.purchasePriceCents &&
          other.currency == this.currency &&
          other.retailer == this.retailer &&
          other.coveragesJson == this.coveragesJson &&
          other.warrantyJson == this.warrantyJson &&
          other.extendedWarrantyJson == this.extendedWarrantyJson &&
          other.leadDays == this.leadDays &&
          other.notes == this.notes &&
          other.thumbBlobId == this.thumbBlobId &&
          other.photoBlobId == this.photoBlobId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> propertyId;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> model;
  final Value<String?> serial;
  final Value<String?> roomId;
  final Value<String?> purchaseDate;
  final Value<int?> purchasePriceCents;
  final Value<String?> currency;
  final Value<String?> retailer;
  final Value<String> coveragesJson;
  final Value<String?> warrantyJson;
  final Value<String?> extendedWarrantyJson;
  final Value<int?> leadDays;
  final Value<String?> notes;
  final Value<String?> thumbBlobId;
  final Value<String?> photoBlobId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.propertyId = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.serial = const Value.absent(),
    this.roomId = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.purchasePriceCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.retailer = const Value.absent(),
    this.coveragesJson = const Value.absent(),
    this.warrantyJson = const Value.absent(),
    this.extendedWarrantyJson = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.notes = const Value.absent(),
    this.thumbBlobId = const Value.absent(),
    this.photoBlobId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String propertyId,
    required String name,
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.serial = const Value.absent(),
    this.roomId = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.purchasePriceCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.retailer = const Value.absent(),
    this.coveragesJson = const Value.absent(),
    this.warrantyJson = const Value.absent(),
    this.extendedWarrantyJson = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.notes = const Value.absent(),
    this.thumbBlobId = const Value.absent(),
    this.photoBlobId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        propertyId = Value(propertyId),
        name = Value(name);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? propertyId,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<String>? serial,
    Expression<String>? roomId,
    Expression<String>? purchaseDate,
    Expression<int>? purchasePriceCents,
    Expression<String>? currency,
    Expression<String>? retailer,
    Expression<String>? coveragesJson,
    Expression<String>? warrantyJson,
    Expression<String>? extendedWarrantyJson,
    Expression<int>? leadDays,
    Expression<String>? notes,
    Expression<String>? thumbBlobId,
    Expression<String>? photoBlobId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (propertyId != null) 'property_id': propertyId,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (serial != null) 'serial': serial,
      if (roomId != null) 'room_id': roomId,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
      if (purchasePriceCents != null)
        'purchase_price_cents': purchasePriceCents,
      if (currency != null) 'currency': currency,
      if (retailer != null) 'retailer': retailer,
      if (coveragesJson != null) 'coverages_json': coveragesJson,
      if (warrantyJson != null) 'warranty_json': warrantyJson,
      if (extendedWarrantyJson != null)
        'extended_warranty_json': extendedWarrantyJson,
      if (leadDays != null) 'lead_days': leadDays,
      if (notes != null) 'notes': notes,
      if (thumbBlobId != null) 'thumb_blob_id': thumbBlobId,
      if (photoBlobId != null) 'photo_blob_id': photoBlobId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? propertyId,
      Value<String>? name,
      Value<String?>? brand,
      Value<String?>? model,
      Value<String?>? serial,
      Value<String?>? roomId,
      Value<String?>? purchaseDate,
      Value<int?>? purchasePriceCents,
      Value<String?>? currency,
      Value<String?>? retailer,
      Value<String>? coveragesJson,
      Value<String?>? warrantyJson,
      Value<String?>? extendedWarrantyJson,
      Value<int?>? leadDays,
      Value<String?>? notes,
      Value<String?>? thumbBlobId,
      Value<String?>? photoBlobId,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return ItemsCompanion(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serial: serial ?? this.serial,
      roomId: roomId ?? this.roomId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
      currency: currency ?? this.currency,
      retailer: retailer ?? this.retailer,
      coveragesJson: coveragesJson ?? this.coveragesJson,
      warrantyJson: warrantyJson ?? this.warrantyJson,
      extendedWarrantyJson: extendedWarrantyJson ?? this.extendedWarrantyJson,
      leadDays: leadDays ?? this.leadDays,
      notes: notes ?? this.notes,
      thumbBlobId: thumbBlobId ?? this.thumbBlobId,
      photoBlobId: photoBlobId ?? this.photoBlobId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (propertyId.present) {
      map['property_id'] = Variable<String>(propertyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (purchaseDate.present) {
      map['purchase_date'] = Variable<String>(purchaseDate.value);
    }
    if (purchasePriceCents.present) {
      map['purchase_price_cents'] = Variable<int>(purchasePriceCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (retailer.present) {
      map['retailer'] = Variable<String>(retailer.value);
    }
    if (coveragesJson.present) {
      map['coverages_json'] = Variable<String>(coveragesJson.value);
    }
    if (warrantyJson.present) {
      map['warranty_json'] = Variable<String>(warrantyJson.value);
    }
    if (extendedWarrantyJson.present) {
      map['extended_warranty_json'] =
          Variable<String>(extendedWarrantyJson.value);
    }
    if (leadDays.present) {
      map['lead_days'] = Variable<int>(leadDays.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (thumbBlobId.present) {
      map['thumb_blob_id'] = Variable<String>(thumbBlobId.value);
    }
    if (photoBlobId.present) {
      map['photo_blob_id'] = Variable<String>(photoBlobId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('serial: $serial, ')
          ..write('roomId: $roomId, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('purchasePriceCents: $purchasePriceCents, ')
          ..write('currency: $currency, ')
          ..write('retailer: $retailer, ')
          ..write('coveragesJson: $coveragesJson, ')
          ..write('warrantyJson: $warrantyJson, ')
          ..write('extendedWarrantyJson: $extendedWarrantyJson, ')
          ..write('leadDays: $leadDays, ')
          ..write('notes: $notes, ')
          ..write('thumbBlobId: $thumbBlobId, ')
          ..write('photoBlobId: $photoBlobId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocsTable extends Docs with TableInfo<$DocsTable, DocRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('other'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
      'blob_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, itemId, kind, title, blobId, url, createdAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'docs';
  @override
  VerificationContext validateIntegrity(Insertable<DocRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('blob_id')) {
      context.handle(_blobIdMeta,
          blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      blobId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blob_id']),
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $DocsTable createAlias(String alias) {
    return $DocsTable(attachedDatabase, alias);
  }
}

class DocRow extends DataClass implements Insertable<DocRow> {
  final String id;
  final String itemId;

  /// Stored as the enum's name, not its index.
  ///
  /// An index is a number whose meaning depends on the order of a list in the
  /// source — reorder the enum and every row in the database changes meaning
  /// silently. The name survives reordering, and it is also what the backup
  /// format uses, so one string means one thing everywhere.
  final String kind;
  final String? title;
  final String? blobId;
  final String? url;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  const DocRow(
      {required this.id,
      required this.itemId,
      required this.kind,
      this.title,
      this.blobId,
      this.url,
      this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || blobId != null) {
      map['blob_id'] = Variable<String>(blobId);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DocsCompanion toCompanion(bool nullToAbsent) {
    return DocsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      kind: Value(kind),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      blobId:
          blobId == null && nullToAbsent ? const Value.absent() : Value(blobId),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DocRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String?>(json['title']),
      blobId: serializer.fromJson<String?>(json['blobId']),
      url: serializer.fromJson<String?>(json['url']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String?>(title),
      'blobId': serializer.toJson<String?>(blobId),
      'url': serializer.toJson<String?>(url),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DocRow copyWith(
          {String? id,
          String? itemId,
          String? kind,
          Value<String?> title = const Value.absent(),
          Value<String?> blobId = const Value.absent(),
          Value<String?> url = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      DocRow(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        kind: kind ?? this.kind,
        title: title.present ? title.value : this.title,
        blobId: blobId.present ? blobId.value : this.blobId,
        url: url.present ? url.value : this.url,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  DocRow copyWithCompanion(DocsCompanion data) {
    return DocRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      url: data.url.present ? data.url.value : this.url,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('blobId: $blobId, ')
          ..write('url: $url, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, itemId, kind, title, blobId, url, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.blobId == this.blobId &&
          other.url == this.url &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class DocsCompanion extends UpdateCompanion<DocRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> kind;
  final Value<String?> title;
  final Value<String?> blobId;
  final Value<String?> url;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DocsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.blobId = const Value.absent(),
    this.url = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocsCompanion.insert({
    required String id,
    required String itemId,
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.blobId = const Value.absent(),
    this.url = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        itemId = Value(itemId);
  static Insertable<DocRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? blobId,
    Expression<String>? url,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (blobId != null) 'blob_id': blobId,
      if (url != null) 'url': url,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocsCompanion copyWith(
      {Value<String>? id,
      Value<String>? itemId,
      Value<String>? kind,
      Value<String?>? title,
      Value<String?>? blobId,
      Value<String?>? url,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return DocsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      blobId: blobId ?? this.blobId,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('blobId: $blobId, ')
          ..write('url: $url, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoomsTable extends Rooms with TableInfo<$RoomsTable, RoomRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _propertyIdMeta =
      const VerificationMeta('propertyId');
  @override
  late final GeneratedColumn<String> propertyId = GeneratedColumn<String>(
      'property_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isSeedMeta = const VerificationMeta('isSeed');
  @override
  late final GeneratedColumn<bool> isSeed = GeneratedColumn<bool>(
      'is_seed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_seed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, propertyId, name, sortOrder, isSeed, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rooms';
  @override
  VerificationContext validateIntegrity(Insertable<RoomRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('property_id')) {
      context.handle(
          _propertyIdMeta,
          propertyId.isAcceptableOrUnknown(
              data['property_id']!, _propertyIdMeta));
    } else if (isInserting) {
      context.missing(_propertyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('is_seed')) {
      context.handle(_isSeedMeta,
          isSeed.isAcceptableOrUnknown(data['is_seed']!, _isSeedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoomRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoomRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      propertyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}property_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      isSeed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_seed'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $RoomsTable createAlias(String alias) {
    return $RoomsTable(attachedDatabase, alias);
  }
}

class RoomRow extends DataClass implements Insertable<RoomRow> {
  final String id;
  final String propertyId;
  final String name;
  final int sortOrder;
  final bool isSeed;
  final DateTime? deletedAt;
  const RoomRow(
      {required this.id,
      required this.propertyId,
      required this.name,
      required this.sortOrder,
      required this.isSeed,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['property_id'] = Variable<String>(propertyId);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_seed'] = Variable<bool>(isSeed);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(
      id: Value(id),
      propertyId: Value(propertyId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      isSeed: Value(isSeed),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory RoomRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoomRow(
      id: serializer.fromJson<String>(json['id']),
      propertyId: serializer.fromJson<String>(json['propertyId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isSeed: serializer.fromJson<bool>(json['isSeed']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'propertyId': serializer.toJson<String>(propertyId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isSeed': serializer.toJson<bool>(isSeed),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  RoomRow copyWith(
          {String? id,
          String? propertyId,
          String? name,
          int? sortOrder,
          bool? isSeed,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      RoomRow(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        isSeed: isSeed ?? this.isSeed,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  RoomRow copyWithCompanion(RoomsCompanion data) {
    return RoomRow(
      id: data.id.present ? data.id.value : this.id,
      propertyId:
          data.propertyId.present ? data.propertyId.value : this.propertyId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isSeed: data.isSeed.present ? data.isSeed.value : this.isSeed,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoomRow(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSeed: $isSeed, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, propertyId, name, sortOrder, isSeed, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoomRow &&
          other.id == this.id &&
          other.propertyId == this.propertyId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.isSeed == this.isSeed &&
          other.deletedAt == this.deletedAt);
}

class RoomsCompanion extends UpdateCompanion<RoomRow> {
  final Value<String> id;
  final Value<String> propertyId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> isSeed;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const RoomsCompanion({
    this.id = const Value.absent(),
    this.propertyId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSeed = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomsCompanion.insert({
    required String id,
    required String propertyId,
    required String name,
    this.sortOrder = const Value.absent(),
    this.isSeed = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        propertyId = Value(propertyId),
        name = Value(name);
  static Insertable<RoomRow> custom({
    Expression<String>? id,
    Expression<String>? propertyId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? isSeed,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (propertyId != null) 'property_id': propertyId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isSeed != null) 'is_seed': isSeed,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomsCompanion copyWith(
      {Value<String>? id,
      Value<String>? propertyId,
      Value<String>? name,
      Value<int>? sortOrder,
      Value<bool>? isSeed,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return RoomsCompanion(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isSeed: isSeed ?? this.isSeed,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (propertyId.present) {
      map['property_id'] = Variable<String>(propertyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isSeed.present) {
      map['is_seed'] = Variable<bool>(isSeed.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomsCompanion(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSeed: $isSeed, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubscriptionsTable extends Subscriptions
    with TableInfo<$SubscriptionsTable, SubscriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _propertyIdMeta =
      const VerificationMeta('propertyId');
  @override
  late final GeneratedColumn<String> propertyId = GeneratedColumn<String>(
      'property_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serviceIdMeta =
      const VerificationMeta('serviceId');
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
      'service_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _logoBlobIdMeta =
      const VerificationMeta('logoBlobId');
  @override
  late final GeneratedColumn<String> logoBlobId = GeneratedColumn<String>(
      'logo_blob_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cadenceMeta =
      const VerificationMeta('cadence');
  @override
  late final GeneratedColumn<String> cadence = GeneratedColumn<String>(
      'cadence', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _anchorDateMeta =
      const VerificationMeta('anchorDate');
  @override
  late final GeneratedColumn<String> anchorDate = GeneratedColumn<String>(
      'anchor_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountCentsMeta =
      const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
      'amount_cents', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  static const VerificationMeta _startedDateMeta =
      const VerificationMeta('startedDate');
  @override
  late final GeneratedColumn<String> startedDate = GeneratedColumn<String>(
      'started_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _remindDaysMeta =
      const VerificationMeta('remindDays');
  @override
  late final GeneratedColumn<int> remindDays = GeneratedColumn<int>(
      'remind_days', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        propertyId,
        name,
        serviceId,
        logoBlobId,
        cadence,
        anchorDate,
        amountCents,
        currency,
        startedDate,
        remindDays,
        notes,
        createdAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscriptions';
  @override
  VerificationContext validateIntegrity(Insertable<SubscriptionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('property_id')) {
      context.handle(
          _propertyIdMeta,
          propertyId.isAcceptableOrUnknown(
              data['property_id']!, _propertyIdMeta));
    } else if (isInserting) {
      context.missing(_propertyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('service_id')) {
      context.handle(_serviceIdMeta,
          serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta));
    }
    if (data.containsKey('logo_blob_id')) {
      context.handle(
          _logoBlobIdMeta,
          logoBlobId.isAcceptableOrUnknown(
              data['logo_blob_id']!, _logoBlobIdMeta));
    }
    if (data.containsKey('cadence')) {
      context.handle(_cadenceMeta,
          cadence.isAcceptableOrUnknown(data['cadence']!, _cadenceMeta));
    } else if (isInserting) {
      context.missing(_cadenceMeta);
    }
    if (data.containsKey('anchor_date')) {
      context.handle(
          _anchorDateMeta,
          anchorDate.isAcceptableOrUnknown(
              data['anchor_date']!, _anchorDateMeta));
    } else if (isInserting) {
      context.missing(_anchorDateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
          _amountCentsMeta,
          amountCents.isAcceptableOrUnknown(
              data['amount_cents']!, _amountCentsMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('started_date')) {
      context.handle(
          _startedDateMeta,
          startedDate.isAcceptableOrUnknown(
              data['started_date']!, _startedDateMeta));
    }
    if (data.containsKey('remind_days')) {
      context.handle(
          _remindDaysMeta,
          remindDays.isAcceptableOrUnknown(
              data['remind_days']!, _remindDaysMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubscriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubscriptionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      propertyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}property_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      serviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}service_id']),
      logoBlobId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo_blob_id']),
      cadence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cadence'])!,
      anchorDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anchor_date'])!,
      amountCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      startedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_date']),
      remindDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remind_days']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $SubscriptionsTable createAlias(String alias) {
    return $SubscriptionsTable(attachedDatabase, alias);
  }
}

class SubscriptionRow extends DataClass implements Insertable<SubscriptionRow> {
  final String id;
  final String propertyId;
  final String name;
  final String? serviceId;
  final String? logoBlobId;

  /// The enum's name — see the note on `Docs.kind`.
  final String cadence;

  /// One real renewal date, `YYYY-MM-DD`. Every other date derives from it.
  final String anchorDate;
  final int amountCents;
  final String currency;
  final String? startedDate;

  /// 0, 1, 3 or 7. Null or zero means no reminder, and is the default.
  final int? remindDays;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  const SubscriptionRow(
      {required this.id,
      required this.propertyId,
      required this.name,
      this.serviceId,
      this.logoBlobId,
      required this.cadence,
      required this.anchorDate,
      required this.amountCents,
      required this.currency,
      this.startedDate,
      this.remindDays,
      this.notes,
      this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['property_id'] = Variable<String>(propertyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || serviceId != null) {
      map['service_id'] = Variable<String>(serviceId);
    }
    if (!nullToAbsent || logoBlobId != null) {
      map['logo_blob_id'] = Variable<String>(logoBlobId);
    }
    map['cadence'] = Variable<String>(cadence);
    map['anchor_date'] = Variable<String>(anchorDate);
    map['amount_cents'] = Variable<int>(amountCents);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || startedDate != null) {
      map['started_date'] = Variable<String>(startedDate);
    }
    if (!nullToAbsent || remindDays != null) {
      map['remind_days'] = Variable<int>(remindDays);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionsCompanion(
      id: Value(id),
      propertyId: Value(propertyId),
      name: Value(name),
      serviceId: serviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceId),
      logoBlobId: logoBlobId == null && nullToAbsent
          ? const Value.absent()
          : Value(logoBlobId),
      cadence: Value(cadence),
      anchorDate: Value(anchorDate),
      amountCents: Value(amountCents),
      currency: Value(currency),
      startedDate: startedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startedDate),
      remindDays: remindDays == null && nullToAbsent
          ? const Value.absent()
          : Value(remindDays),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SubscriptionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubscriptionRow(
      id: serializer.fromJson<String>(json['id']),
      propertyId: serializer.fromJson<String>(json['propertyId']),
      name: serializer.fromJson<String>(json['name']),
      serviceId: serializer.fromJson<String?>(json['serviceId']),
      logoBlobId: serializer.fromJson<String?>(json['logoBlobId']),
      cadence: serializer.fromJson<String>(json['cadence']),
      anchorDate: serializer.fromJson<String>(json['anchorDate']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      currency: serializer.fromJson<String>(json['currency']),
      startedDate: serializer.fromJson<String?>(json['startedDate']),
      remindDays: serializer.fromJson<int?>(json['remindDays']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'propertyId': serializer.toJson<String>(propertyId),
      'name': serializer.toJson<String>(name),
      'serviceId': serializer.toJson<String?>(serviceId),
      'logoBlobId': serializer.toJson<String?>(logoBlobId),
      'cadence': serializer.toJson<String>(cadence),
      'anchorDate': serializer.toJson<String>(anchorDate),
      'amountCents': serializer.toJson<int>(amountCents),
      'currency': serializer.toJson<String>(currency),
      'startedDate': serializer.toJson<String?>(startedDate),
      'remindDays': serializer.toJson<int?>(remindDays),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SubscriptionRow copyWith(
          {String? id,
          String? propertyId,
          String? name,
          Value<String?> serviceId = const Value.absent(),
          Value<String?> logoBlobId = const Value.absent(),
          String? cadence,
          String? anchorDate,
          int? amountCents,
          String? currency,
          Value<String?> startedDate = const Value.absent(),
          Value<int?> remindDays = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      SubscriptionRow(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        name: name ?? this.name,
        serviceId: serviceId.present ? serviceId.value : this.serviceId,
        logoBlobId: logoBlobId.present ? logoBlobId.value : this.logoBlobId,
        cadence: cadence ?? this.cadence,
        anchorDate: anchorDate ?? this.anchorDate,
        amountCents: amountCents ?? this.amountCents,
        currency: currency ?? this.currency,
        startedDate: startedDate.present ? startedDate.value : this.startedDate,
        remindDays: remindDays.present ? remindDays.value : this.remindDays,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  SubscriptionRow copyWithCompanion(SubscriptionsCompanion data) {
    return SubscriptionRow(
      id: data.id.present ? data.id.value : this.id,
      propertyId:
          data.propertyId.present ? data.propertyId.value : this.propertyId,
      name: data.name.present ? data.name.value : this.name,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      logoBlobId:
          data.logoBlobId.present ? data.logoBlobId.value : this.logoBlobId,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      anchorDate:
          data.anchorDate.present ? data.anchorDate.value : this.anchorDate,
      amountCents:
          data.amountCents.present ? data.amountCents.value : this.amountCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      startedDate:
          data.startedDate.present ? data.startedDate.value : this.startedDate,
      remindDays:
          data.remindDays.present ? data.remindDays.value : this.remindDays,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionRow(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('serviceId: $serviceId, ')
          ..write('logoBlobId: $logoBlobId, ')
          ..write('cadence: $cadence, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('startedDate: $startedDate, ')
          ..write('remindDays: $remindDays, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      propertyId,
      name,
      serviceId,
      logoBlobId,
      cadence,
      anchorDate,
      amountCents,
      currency,
      startedDate,
      remindDays,
      notes,
      createdAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionRow &&
          other.id == this.id &&
          other.propertyId == this.propertyId &&
          other.name == this.name &&
          other.serviceId == this.serviceId &&
          other.logoBlobId == this.logoBlobId &&
          other.cadence == this.cadence &&
          other.anchorDate == this.anchorDate &&
          other.amountCents == this.amountCents &&
          other.currency == this.currency &&
          other.startedDate == this.startedDate &&
          other.remindDays == this.remindDays &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class SubscriptionsCompanion extends UpdateCompanion<SubscriptionRow> {
  final Value<String> id;
  final Value<String> propertyId;
  final Value<String> name;
  final Value<String?> serviceId;
  final Value<String?> logoBlobId;
  final Value<String> cadence;
  final Value<String> anchorDate;
  final Value<int> amountCents;
  final Value<String> currency;
  final Value<String?> startedDate;
  final Value<int?> remindDays;
  final Value<String?> notes;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SubscriptionsCompanion({
    this.id = const Value.absent(),
    this.propertyId = const Value.absent(),
    this.name = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.logoBlobId = const Value.absent(),
    this.cadence = const Value.absent(),
    this.anchorDate = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.startedDate = const Value.absent(),
    this.remindDays = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubscriptionsCompanion.insert({
    required String id,
    required String propertyId,
    required String name,
    this.serviceId = const Value.absent(),
    this.logoBlobId = const Value.absent(),
    required String cadence,
    required String anchorDate,
    this.amountCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.startedDate = const Value.absent(),
    this.remindDays = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        propertyId = Value(propertyId),
        name = Value(name),
        cadence = Value(cadence),
        anchorDate = Value(anchorDate);
  static Insertable<SubscriptionRow> custom({
    Expression<String>? id,
    Expression<String>? propertyId,
    Expression<String>? name,
    Expression<String>? serviceId,
    Expression<String>? logoBlobId,
    Expression<String>? cadence,
    Expression<String>? anchorDate,
    Expression<int>? amountCents,
    Expression<String>? currency,
    Expression<String>? startedDate,
    Expression<int>? remindDays,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (propertyId != null) 'property_id': propertyId,
      if (name != null) 'name': name,
      if (serviceId != null) 'service_id': serviceId,
      if (logoBlobId != null) 'logo_blob_id': logoBlobId,
      if (cadence != null) 'cadence': cadence,
      if (anchorDate != null) 'anchor_date': anchorDate,
      if (amountCents != null) 'amount_cents': amountCents,
      if (currency != null) 'currency': currency,
      if (startedDate != null) 'started_date': startedDate,
      if (remindDays != null) 'remind_days': remindDays,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubscriptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? propertyId,
      Value<String>? name,
      Value<String?>? serviceId,
      Value<String?>? logoBlobId,
      Value<String>? cadence,
      Value<String>? anchorDate,
      Value<int>? amountCents,
      Value<String>? currency,
      Value<String?>? startedDate,
      Value<int?>? remindDays,
      Value<String?>? notes,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return SubscriptionsCompanion(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      name: name ?? this.name,
      serviceId: serviceId ?? this.serviceId,
      logoBlobId: logoBlobId ?? this.logoBlobId,
      cadence: cadence ?? this.cadence,
      anchorDate: anchorDate ?? this.anchorDate,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      startedDate: startedDate ?? this.startedDate,
      remindDays: remindDays ?? this.remindDays,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (propertyId.present) {
      map['property_id'] = Variable<String>(propertyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (logoBlobId.present) {
      map['logo_blob_id'] = Variable<String>(logoBlobId.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<String>(cadence.value);
    }
    if (anchorDate.present) {
      map['anchor_date'] = Variable<String>(anchorDate.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (startedDate.present) {
      map['started_date'] = Variable<String>(startedDate.value);
    }
    if (remindDays.present) {
      map['remind_days'] = Variable<int>(remindDays.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('name: $name, ')
          ..write('serviceId: $serviceId, ')
          ..write('logoBlobId: $logoBlobId, ')
          ..write('cadence: $cadence, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('amountCents: $amountCents, ')
          ..write('currency: $currency, ')
          ..write('startedDate: $startedDate, ')
          ..write('remindDays: $remindDays, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PapersTable extends Papers with TableInfo<$PapersTable, PaperRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PapersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _propertyIdMeta =
      const VerificationMeta('propertyId');
  @override
  late final GeneratedColumn<String> propertyId = GeneratedColumn<String>(
      'property_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _holderMeta = const VerificationMeta('holder');
  @override
  late final GeneratedColumn<String> holder = GeneratedColumn<String>(
      'holder', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expiresOnMeta =
      const VerificationMeta('expiresOn');
  @override
  late final GeneratedColumn<String> expiresOn = GeneratedColumn<String>(
      'expires_on', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _issuedOnMeta =
      const VerificationMeta('issuedOn');
  @override
  late final GeneratedColumn<String> issuedOn = GeneratedColumn<String>(
      'issued_on', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leadDaysMeta =
      const VerificationMeta('leadDays');
  @override
  late final GeneratedColumn<int> leadDays = GeneratedColumn<int>(
      'lead_days', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _authorityMeta =
      const VerificationMeta('authority');
  @override
  late final GeneratedColumn<String> authority = GeneratedColumn<String>(
      'authority', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _storedAtMeta =
      const VerificationMeta('storedAt');
  @override
  late final GeneratedColumn<String> storedAt = GeneratedColumn<String>(
      'stored_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        propertyId,
        kind,
        label,
        holder,
        expiresOn,
        issuedOn,
        leadDays,
        authority,
        storedAt,
        notes,
        createdAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'papers';
  @override
  VerificationContext validateIntegrity(Insertable<PaperRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('property_id')) {
      context.handle(
          _propertyIdMeta,
          propertyId.isAcceptableOrUnknown(
              data['property_id']!, _propertyIdMeta));
    } else if (isInserting) {
      context.missing(_propertyIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('holder')) {
      context.handle(_holderMeta,
          holder.isAcceptableOrUnknown(data['holder']!, _holderMeta));
    }
    if (data.containsKey('expires_on')) {
      context.handle(_expiresOnMeta,
          expiresOn.isAcceptableOrUnknown(data['expires_on']!, _expiresOnMeta));
    } else if (isInserting) {
      context.missing(_expiresOnMeta);
    }
    if (data.containsKey('issued_on')) {
      context.handle(_issuedOnMeta,
          issuedOn.isAcceptableOrUnknown(data['issued_on']!, _issuedOnMeta));
    }
    if (data.containsKey('lead_days')) {
      context.handle(_leadDaysMeta,
          leadDays.isAcceptableOrUnknown(data['lead_days']!, _leadDaysMeta));
    }
    if (data.containsKey('authority')) {
      context.handle(_authorityMeta,
          authority.isAcceptableOrUnknown(data['authority']!, _authorityMeta));
    }
    if (data.containsKey('stored_at')) {
      context.handle(_storedAtMeta,
          storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaperRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaperRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      propertyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}property_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      holder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}holder']),
      expiresOn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}expires_on'])!,
      issuedOn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issued_on']),
      leadDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lead_days']),
      authority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}authority']),
      storedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stored_at']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PapersTable createAlias(String alias) {
    return $PapersTable(attachedDatabase, alias);
  }
}

class PaperRow extends DataClass implements Insertable<PaperRow> {
  final String id;
  final String propertyId;

  /// The enum's name, and one of those names is misspelled on purpose:
  /// `licence` is British, the label people read is American, and the key is
  /// frozen because it is written into every record ever saved. See the note
  /// on `PaperKind`.
  final String kind;
  final String label;
  final String? holder;
  final String expiresOn;
  final String? issuedOn;
  final int? leadDays;
  final String? authority;
  final String? storedAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  const PaperRow(
      {required this.id,
      required this.propertyId,
      required this.kind,
      required this.label,
      this.holder,
      required this.expiresOn,
      this.issuedOn,
      this.leadDays,
      this.authority,
      this.storedAt,
      this.notes,
      this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['property_id'] = Variable<String>(propertyId);
    map['kind'] = Variable<String>(kind);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || holder != null) {
      map['holder'] = Variable<String>(holder);
    }
    map['expires_on'] = Variable<String>(expiresOn);
    if (!nullToAbsent || issuedOn != null) {
      map['issued_on'] = Variable<String>(issuedOn);
    }
    if (!nullToAbsent || leadDays != null) {
      map['lead_days'] = Variable<int>(leadDays);
    }
    if (!nullToAbsent || authority != null) {
      map['authority'] = Variable<String>(authority);
    }
    if (!nullToAbsent || storedAt != null) {
      map['stored_at'] = Variable<String>(storedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PapersCompanion toCompanion(bool nullToAbsent) {
    return PapersCompanion(
      id: Value(id),
      propertyId: Value(propertyId),
      kind: Value(kind),
      label: Value(label),
      holder:
          holder == null && nullToAbsent ? const Value.absent() : Value(holder),
      expiresOn: Value(expiresOn),
      issuedOn: issuedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(issuedOn),
      leadDays: leadDays == null && nullToAbsent
          ? const Value.absent()
          : Value(leadDays),
      authority: authority == null && nullToAbsent
          ? const Value.absent()
          : Value(authority),
      storedAt: storedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(storedAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PaperRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaperRow(
      id: serializer.fromJson<String>(json['id']),
      propertyId: serializer.fromJson<String>(json['propertyId']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String>(json['label']),
      holder: serializer.fromJson<String?>(json['holder']),
      expiresOn: serializer.fromJson<String>(json['expiresOn']),
      issuedOn: serializer.fromJson<String?>(json['issuedOn']),
      leadDays: serializer.fromJson<int?>(json['leadDays']),
      authority: serializer.fromJson<String?>(json['authority']),
      storedAt: serializer.fromJson<String?>(json['storedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'propertyId': serializer.toJson<String>(propertyId),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String>(label),
      'holder': serializer.toJson<String?>(holder),
      'expiresOn': serializer.toJson<String>(expiresOn),
      'issuedOn': serializer.toJson<String?>(issuedOn),
      'leadDays': serializer.toJson<int?>(leadDays),
      'authority': serializer.toJson<String?>(authority),
      'storedAt': serializer.toJson<String?>(storedAt),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PaperRow copyWith(
          {String? id,
          String? propertyId,
          String? kind,
          String? label,
          Value<String?> holder = const Value.absent(),
          String? expiresOn,
          Value<String?> issuedOn = const Value.absent(),
          Value<int?> leadDays = const Value.absent(),
          Value<String?> authority = const Value.absent(),
          Value<String?> storedAt = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      PaperRow(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        kind: kind ?? this.kind,
        label: label ?? this.label,
        holder: holder.present ? holder.value : this.holder,
        expiresOn: expiresOn ?? this.expiresOn,
        issuedOn: issuedOn.present ? issuedOn.value : this.issuedOn,
        leadDays: leadDays.present ? leadDays.value : this.leadDays,
        authority: authority.present ? authority.value : this.authority,
        storedAt: storedAt.present ? storedAt.value : this.storedAt,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PaperRow copyWithCompanion(PapersCompanion data) {
    return PaperRow(
      id: data.id.present ? data.id.value : this.id,
      propertyId:
          data.propertyId.present ? data.propertyId.value : this.propertyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      holder: data.holder.present ? data.holder.value : this.holder,
      expiresOn: data.expiresOn.present ? data.expiresOn.value : this.expiresOn,
      issuedOn: data.issuedOn.present ? data.issuedOn.value : this.issuedOn,
      leadDays: data.leadDays.present ? data.leadDays.value : this.leadDays,
      authority: data.authority.present ? data.authority.value : this.authority,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaperRow(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('holder: $holder, ')
          ..write('expiresOn: $expiresOn, ')
          ..write('issuedOn: $issuedOn, ')
          ..write('leadDays: $leadDays, ')
          ..write('authority: $authority, ')
          ..write('storedAt: $storedAt, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      propertyId,
      kind,
      label,
      holder,
      expiresOn,
      issuedOn,
      leadDays,
      authority,
      storedAt,
      notes,
      createdAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaperRow &&
          other.id == this.id &&
          other.propertyId == this.propertyId &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.holder == this.holder &&
          other.expiresOn == this.expiresOn &&
          other.issuedOn == this.issuedOn &&
          other.leadDays == this.leadDays &&
          other.authority == this.authority &&
          other.storedAt == this.storedAt &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PapersCompanion extends UpdateCompanion<PaperRow> {
  final Value<String> id;
  final Value<String> propertyId;
  final Value<String> kind;
  final Value<String> label;
  final Value<String?> holder;
  final Value<String> expiresOn;
  final Value<String?> issuedOn;
  final Value<int?> leadDays;
  final Value<String?> authority;
  final Value<String?> storedAt;
  final Value<String?> notes;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PapersCompanion({
    this.id = const Value.absent(),
    this.propertyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.holder = const Value.absent(),
    this.expiresOn = const Value.absent(),
    this.issuedOn = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.authority = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PapersCompanion.insert({
    required String id,
    required String propertyId,
    required String kind,
    required String label,
    this.holder = const Value.absent(),
    required String expiresOn,
    this.issuedOn = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.authority = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        propertyId = Value(propertyId),
        kind = Value(kind),
        label = Value(label),
        expiresOn = Value(expiresOn);
  static Insertable<PaperRow> custom({
    Expression<String>? id,
    Expression<String>? propertyId,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<String>? holder,
    Expression<String>? expiresOn,
    Expression<String>? issuedOn,
    Expression<int>? leadDays,
    Expression<String>? authority,
    Expression<String>? storedAt,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (propertyId != null) 'property_id': propertyId,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (holder != null) 'holder': holder,
      if (expiresOn != null) 'expires_on': expiresOn,
      if (issuedOn != null) 'issued_on': issuedOn,
      if (leadDays != null) 'lead_days': leadDays,
      if (authority != null) 'authority': authority,
      if (storedAt != null) 'stored_at': storedAt,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PapersCompanion copyWith(
      {Value<String>? id,
      Value<String>? propertyId,
      Value<String>? kind,
      Value<String>? label,
      Value<String?>? holder,
      Value<String>? expiresOn,
      Value<String?>? issuedOn,
      Value<int?>? leadDays,
      Value<String?>? authority,
      Value<String?>? storedAt,
      Value<String?>? notes,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PapersCompanion(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      holder: holder ?? this.holder,
      expiresOn: expiresOn ?? this.expiresOn,
      issuedOn: issuedOn ?? this.issuedOn,
      leadDays: leadDays ?? this.leadDays,
      authority: authority ?? this.authority,
      storedAt: storedAt ?? this.storedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (propertyId.present) {
      map['property_id'] = Variable<String>(propertyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (holder.present) {
      map['holder'] = Variable<String>(holder.value);
    }
    if (expiresOn.present) {
      map['expires_on'] = Variable<String>(expiresOn.value);
    }
    if (issuedOn.present) {
      map['issued_on'] = Variable<String>(issuedOn.value);
    }
    if (leadDays.present) {
      map['lead_days'] = Variable<int>(leadDays.value);
    }
    if (authority.present) {
      map['authority'] = Variable<String>(authority.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<String>(storedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PapersCompanion(')
          ..write('id: $id, ')
          ..write('propertyId: $propertyId, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('holder: $holder, ')
          ..write('expiresOn: $expiresOn, ')
          ..write('issuedOn: $issuedOn, ')
          ..write('leadDays: $leadDays, ')
          ..write('authority: $authority, ')
          ..write('storedAt: $storedAt, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PropertiesTable extends Properties
    with TableInfo<$PropertiesTable, PropertyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropertiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'properties';
  @override
  VerificationContext validateIntegrity(Insertable<PropertyRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PropertyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PropertyRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PropertiesTable createAlias(String alias) {
    return $PropertiesTable(attachedDatabase, alias);
  }
}

class PropertyRow extends DataClass implements Insertable<PropertyRow> {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  const PropertyRow(
      {required this.id, required this.name, this.createdAt, this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PropertiesCompanion toCompanion(bool nullToAbsent) {
    return PropertiesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PropertyRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PropertyRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PropertyRow copyWith(
          {String? id,
          String? name,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      PropertyRow(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PropertyRow copyWithCompanion(PropertiesCompanion data) {
    return PropertyRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PropertyRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PropertiesCompanion extends UpdateCompanion<PropertyRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PropertiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PropertiesCompanion.insert({
    required String id,
    required String name,
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<PropertyRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PropertiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PropertiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropertiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlobsTable extends Blobs with TableInfo<$BlobsTable, BlobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
      'bytes', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
      'mime', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _byteLengthMeta =
      const VerificationMeta('byteLength');
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
      'byte_length', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, bytes, mime, byteLength, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blobs';
  @override
  VerificationContext validateIntegrity(Insertable<BlobRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
          _mimeMeta, mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta));
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
          _byteLengthMeta,
          byteLength.isAcceptableOrUnknown(
              data['byte_length']!, _byteLengthMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlobRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}bytes'])!,
      mime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime'])!,
      byteLength: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}byte_length'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
    );
  }

  @override
  $BlobsTable createAlias(String alias) {
    return $BlobsTable(attachedDatabase, alias);
  }
}

class BlobRow extends DataClass implements Insertable<BlobRow> {
  final String id;
  final Uint8List bytes;
  final String mime;
  final int byteLength;
  final DateTime? createdAt;
  const BlobRow(
      {required this.id,
      required this.bytes,
      required this.mime,
      required this.byteLength,
      this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['mime'] = Variable<String>(mime);
    map['byte_length'] = Variable<int>(byteLength);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  BlobsCompanion toCompanion(bool nullToAbsent) {
    return BlobsCompanion(
      id: Value(id),
      bytes: Value(bytes),
      mime: Value(mime),
      byteLength: Value(byteLength),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory BlobRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlobRow(
      id: serializer.fromJson<String>(json['id']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      mime: serializer.fromJson<String>(json['mime']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'mime': serializer.toJson<String>(mime),
      'byteLength': serializer.toJson<int>(byteLength),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  BlobRow copyWith(
          {String? id,
          Uint8List? bytes,
          String? mime,
          int? byteLength,
          Value<DateTime?> createdAt = const Value.absent()}) =>
      BlobRow(
        id: id ?? this.id,
        bytes: bytes ?? this.bytes,
        mime: mime ?? this.mime,
        byteLength: byteLength ?? this.byteLength,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
      );
  BlobRow copyWithCompanion(BlobsCompanion data) {
    return BlobRow(
      id: data.id.present ? data.id.value : this.id,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteLength:
          data.byteLength.present ? data.byteLength.value : this.byteLength,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlobRow(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, $driftBlobEquality.hash(bytes), mime, byteLength, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlobRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.mime == this.mime &&
          other.byteLength == this.byteLength &&
          other.createdAt == this.createdAt);
}

class BlobsCompanion extends UpdateCompanion<BlobRow> {
  final Value<String> id;
  final Value<Uint8List> bytes;
  final Value<String> mime;
  final Value<int> byteLength;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const BlobsCompanion({
    this.id = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlobsCompanion.insert({
    required String id,
    required Uint8List bytes,
    required String mime,
    this.byteLength = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bytes = Value(bytes),
        mime = Value(mime);
  static Insertable<BlobRow> custom({
    Expression<String>? id,
    Expression<Uint8List>? bytes,
    Expression<String>? mime,
    Expression<int>? byteLength,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bytes != null) 'bytes': bytes,
      if (mime != null) 'mime': mime,
      if (byteLength != null) 'byte_length': byteLength,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlobsCompanion copyWith(
      {Value<String>? id,
      Value<Uint8List>? bytes,
      Value<String>? mime,
      Value<int>? byteLength,
      Value<DateTime?>? createdAt,
      Value<int>? rowid}) {
    return BlobsCompanion(
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      mime: mime ?? this.mime,
      byteLength: byteLength ?? this.byteLength,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlobsCompanion(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTableTable extends SettingsTable
    with TableInfo<$SettingsTableTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('singleton'));
  static const VerificationMeta _reminderOffsetsDaysJsonMeta =
      const VerificationMeta('reminderOffsetsDaysJson');
  @override
  late final GeneratedColumn<String> reminderOffsetsDaysJson =
      GeneratedColumn<String>('reminder_offsets_days_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[30]'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('USD'));
  static const VerificationMeta _lastBackupAtMeta =
      const VerificationMeta('lastBackupAt');
  @override
  late final GeneratedColumn<DateTime> lastBackupAt = GeneratedColumn<DateTime>(
      'last_backup_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _backupReminderDaysMeta =
      const VerificationMeta('backupReminderDays');
  @override
  late final GeneratedColumn<int> backupReminderDays = GeneratedColumn<int>(
      'backup_reminder_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(30));
  static const VerificationMeta _devModeEnabledMeta =
      const VerificationMeta('devModeEnabled');
  @override
  late final GeneratedColumn<bool> devModeEnabled = GeneratedColumn<bool>(
      'dev_mode_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("dev_mode_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _onboardedAtMeta =
      const VerificationMeta('onboardedAt');
  @override
  late final GeneratedColumn<DateTime> onboardedAt = GeneratedColumn<DateTime>(
      'onboarded_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
      'theme', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _soundsMeta = const VerificationMeta('sounds');
  @override
  late final GeneratedColumn<bool> sounds = GeneratedColumn<bool>(
      'sounds', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("sounds" IN (0, 1))'));
  static const VerificationMeta _hapticsMeta =
      const VerificationMeta('haptics');
  @override
  late final GeneratedColumn<bool> haptics = GeneratedColumn<bool>(
      'haptics', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("haptics" IN (0, 1))'));
  static const VerificationMeta _roomsViewMeta =
      const VerificationMeta('roomsView');
  @override
  late final GeneratedColumn<String> roomsView = GeneratedColumn<String>(
      'rooms_view', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _biometricLockMeta =
      const VerificationMeta('biometricLock');
  @override
  late final GeneratedColumn<bool> biometricLock = GeneratedColumn<bool>(
      'biometric_lock', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("biometric_lock" IN (0, 1))'));
  static const VerificationMeta _notifyEnabledMeta =
      const VerificationMeta('notifyEnabled');
  @override
  late final GeneratedColumn<bool> notifyEnabled = GeneratedColumn<bool>(
      'notify_enabled', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notify_enabled" IN (0, 1))'));
  static const VerificationMeta _notifyAskedAtMeta =
      const VerificationMeta('notifyAskedAt');
  @override
  late final GeneratedColumn<DateTime> notifyAskedAt =
      GeneratedColumn<DateTime>('notify_asked_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _proUnlockMeta =
      const VerificationMeta('proUnlock');
  @override
  late final GeneratedColumn<bool> proUnlock = GeneratedColumn<bool>(
      'pro_unlock', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pro_unlock" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reportUnlockMeta =
      const VerificationMeta('reportUnlock');
  @override
  late final GeneratedColumn<bool> reportUnlock = GeneratedColumn<bool>(
      'report_unlock', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("report_unlock" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _entitlementSourceMeta =
      const VerificationMeta('entitlementSource');
  @override
  late final GeneratedColumn<String> entitlementSource =
      GeneratedColumn<String>('entitlement_source', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entitlementVerifiedAtMeta =
      const VerificationMeta('entitlementVerifiedAt');
  @override
  late final GeneratedColumn<DateTime> entitlementVerifiedAt =
      GeneratedColumn<DateTime>('entitlement_verified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        reminderOffsetsDaysJson,
        currency,
        lastBackupAt,
        backupReminderDays,
        devModeEnabled,
        displayName,
        onboardedAt,
        theme,
        sounds,
        haptics,
        roomsView,
        biometricLock,
        notifyEnabled,
        notifyAskedAt,
        proUnlock,
        reportUnlock,
        entitlementSource,
        entitlementVerifiedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingsRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reminder_offsets_days_json')) {
      context.handle(
          _reminderOffsetsDaysJsonMeta,
          reminderOffsetsDaysJson.isAcceptableOrUnknown(
              data['reminder_offsets_days_json']!,
              _reminderOffsetsDaysJsonMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('last_backup_at')) {
      context.handle(
          _lastBackupAtMeta,
          lastBackupAt.isAcceptableOrUnknown(
              data['last_backup_at']!, _lastBackupAtMeta));
    }
    if (data.containsKey('backup_reminder_days')) {
      context.handle(
          _backupReminderDaysMeta,
          backupReminderDays.isAcceptableOrUnknown(
              data['backup_reminder_days']!, _backupReminderDaysMeta));
    }
    if (data.containsKey('dev_mode_enabled')) {
      context.handle(
          _devModeEnabledMeta,
          devModeEnabled.isAcceptableOrUnknown(
              data['dev_mode_enabled']!, _devModeEnabledMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('onboarded_at')) {
      context.handle(
          _onboardedAtMeta,
          onboardedAt.isAcceptableOrUnknown(
              data['onboarded_at']!, _onboardedAtMeta));
    }
    if (data.containsKey('theme')) {
      context.handle(
          _themeMeta, theme.isAcceptableOrUnknown(data['theme']!, _themeMeta));
    }
    if (data.containsKey('sounds')) {
      context.handle(_soundsMeta,
          sounds.isAcceptableOrUnknown(data['sounds']!, _soundsMeta));
    }
    if (data.containsKey('haptics')) {
      context.handle(_hapticsMeta,
          haptics.isAcceptableOrUnknown(data['haptics']!, _hapticsMeta));
    }
    if (data.containsKey('rooms_view')) {
      context.handle(_roomsViewMeta,
          roomsView.isAcceptableOrUnknown(data['rooms_view']!, _roomsViewMeta));
    }
    if (data.containsKey('biometric_lock')) {
      context.handle(
          _biometricLockMeta,
          biometricLock.isAcceptableOrUnknown(
              data['biometric_lock']!, _biometricLockMeta));
    }
    if (data.containsKey('notify_enabled')) {
      context.handle(
          _notifyEnabledMeta,
          notifyEnabled.isAcceptableOrUnknown(
              data['notify_enabled']!, _notifyEnabledMeta));
    }
    if (data.containsKey('notify_asked_at')) {
      context.handle(
          _notifyAskedAtMeta,
          notifyAskedAt.isAcceptableOrUnknown(
              data['notify_asked_at']!, _notifyAskedAtMeta));
    }
    if (data.containsKey('pro_unlock')) {
      context.handle(_proUnlockMeta,
          proUnlock.isAcceptableOrUnknown(data['pro_unlock']!, _proUnlockMeta));
    }
    if (data.containsKey('report_unlock')) {
      context.handle(
          _reportUnlockMeta,
          reportUnlock.isAcceptableOrUnknown(
              data['report_unlock']!, _reportUnlockMeta));
    }
    if (data.containsKey('entitlement_source')) {
      context.handle(
          _entitlementSourceMeta,
          entitlementSource.isAcceptableOrUnknown(
              data['entitlement_source']!, _entitlementSourceMeta));
    }
    if (data.containsKey('entitlement_verified_at')) {
      context.handle(
          _entitlementVerifiedAtMeta,
          entitlementVerifiedAt.isAcceptableOrUnknown(
              data['entitlement_verified_at']!, _entitlementVerifiedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      reminderOffsetsDaysJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reminder_offsets_days_json'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      lastBackupAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_backup_at']),
      backupReminderDays: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}backup_reminder_days'])!,
      devModeEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dev_mode_enabled'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      onboardedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}onboarded_at']),
      theme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme']),
      sounds: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}sounds']),
      haptics: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}haptics']),
      roomsView: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rooms_view']),
      biometricLock: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}biometric_lock']),
      notifyEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}notify_enabled']),
      notifyAskedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}notify_asked_at']),
      proUnlock: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pro_unlock'])!,
      reportUnlock: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}report_unlock'])!,
      entitlementSource: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}entitlement_source']),
      entitlementVerifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}entitlement_verified_at']),
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Always `singleton`. A primary key with one legal value is how a table
  /// says "there is one of these".
  final String id;

  /// A JSON list of ints. One number is read and always has been, but the
  /// column keeps the shape the backup format uses so a restore is a copy.
  final String reminderOffsetsDaysJson;
  final String currency;
  final DateTime? lastBackupAt;
  final int backupReminderDays;
  final bool devModeEnabled;
  final String? displayName;
  final DateTime? onboardedAt;
  final String? theme;
  final bool? sounds;
  final bool? haptics;
  final String? roomsView;
  final bool? biometricLock;
  final bool? notifyEnabled;
  final DateTime? notifyAskedAt;
  final bool proUnlock;
  final bool reportUnlock;
  final String? entitlementSource;
  final DateTime? entitlementVerifiedAt;
  const SettingsRow(
      {required this.id,
      required this.reminderOffsetsDaysJson,
      required this.currency,
      this.lastBackupAt,
      required this.backupReminderDays,
      required this.devModeEnabled,
      this.displayName,
      this.onboardedAt,
      this.theme,
      this.sounds,
      this.haptics,
      this.roomsView,
      this.biometricLock,
      this.notifyEnabled,
      this.notifyAskedAt,
      required this.proUnlock,
      required this.reportUnlock,
      this.entitlementSource,
      this.entitlementVerifiedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['reminder_offsets_days_json'] =
        Variable<String>(reminderOffsetsDaysJson);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || lastBackupAt != null) {
      map['last_backup_at'] = Variable<DateTime>(lastBackupAt);
    }
    map['backup_reminder_days'] = Variable<int>(backupReminderDays);
    map['dev_mode_enabled'] = Variable<bool>(devModeEnabled);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || onboardedAt != null) {
      map['onboarded_at'] = Variable<DateTime>(onboardedAt);
    }
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    if (!nullToAbsent || sounds != null) {
      map['sounds'] = Variable<bool>(sounds);
    }
    if (!nullToAbsent || haptics != null) {
      map['haptics'] = Variable<bool>(haptics);
    }
    if (!nullToAbsent || roomsView != null) {
      map['rooms_view'] = Variable<String>(roomsView);
    }
    if (!nullToAbsent || biometricLock != null) {
      map['biometric_lock'] = Variable<bool>(biometricLock);
    }
    if (!nullToAbsent || notifyEnabled != null) {
      map['notify_enabled'] = Variable<bool>(notifyEnabled);
    }
    if (!nullToAbsent || notifyAskedAt != null) {
      map['notify_asked_at'] = Variable<DateTime>(notifyAskedAt);
    }
    map['pro_unlock'] = Variable<bool>(proUnlock);
    map['report_unlock'] = Variable<bool>(reportUnlock);
    if (!nullToAbsent || entitlementSource != null) {
      map['entitlement_source'] = Variable<String>(entitlementSource);
    }
    if (!nullToAbsent || entitlementVerifiedAt != null) {
      map['entitlement_verified_at'] =
          Variable<DateTime>(entitlementVerifiedAt);
    }
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      id: Value(id),
      reminderOffsetsDaysJson: Value(reminderOffsetsDaysJson),
      currency: Value(currency),
      lastBackupAt: lastBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBackupAt),
      backupReminderDays: Value(backupReminderDays),
      devModeEnabled: Value(devModeEnabled),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      onboardedAt: onboardedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(onboardedAt),
      theme:
          theme == null && nullToAbsent ? const Value.absent() : Value(theme),
      sounds:
          sounds == null && nullToAbsent ? const Value.absent() : Value(sounds),
      haptics: haptics == null && nullToAbsent
          ? const Value.absent()
          : Value(haptics),
      roomsView: roomsView == null && nullToAbsent
          ? const Value.absent()
          : Value(roomsView),
      biometricLock: biometricLock == null && nullToAbsent
          ? const Value.absent()
          : Value(biometricLock),
      notifyEnabled: notifyEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(notifyEnabled),
      notifyAskedAt: notifyAskedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(notifyAskedAt),
      proUnlock: Value(proUnlock),
      reportUnlock: Value(reportUnlock),
      entitlementSource: entitlementSource == null && nullToAbsent
          ? const Value.absent()
          : Value(entitlementSource),
      entitlementVerifiedAt: entitlementVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(entitlementVerifiedAt),
    );
  }

  factory SettingsRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<String>(json['id']),
      reminderOffsetsDaysJson:
          serializer.fromJson<String>(json['reminderOffsetsDaysJson']),
      currency: serializer.fromJson<String>(json['currency']),
      lastBackupAt: serializer.fromJson<DateTime?>(json['lastBackupAt']),
      backupReminderDays: serializer.fromJson<int>(json['backupReminderDays']),
      devModeEnabled: serializer.fromJson<bool>(json['devModeEnabled']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      onboardedAt: serializer.fromJson<DateTime?>(json['onboardedAt']),
      theme: serializer.fromJson<String?>(json['theme']),
      sounds: serializer.fromJson<bool?>(json['sounds']),
      haptics: serializer.fromJson<bool?>(json['haptics']),
      roomsView: serializer.fromJson<String?>(json['roomsView']),
      biometricLock: serializer.fromJson<bool?>(json['biometricLock']),
      notifyEnabled: serializer.fromJson<bool?>(json['notifyEnabled']),
      notifyAskedAt: serializer.fromJson<DateTime?>(json['notifyAskedAt']),
      proUnlock: serializer.fromJson<bool>(json['proUnlock']),
      reportUnlock: serializer.fromJson<bool>(json['reportUnlock']),
      entitlementSource:
          serializer.fromJson<String?>(json['entitlementSource']),
      entitlementVerifiedAt:
          serializer.fromJson<DateTime?>(json['entitlementVerifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reminderOffsetsDaysJson':
          serializer.toJson<String>(reminderOffsetsDaysJson),
      'currency': serializer.toJson<String>(currency),
      'lastBackupAt': serializer.toJson<DateTime?>(lastBackupAt),
      'backupReminderDays': serializer.toJson<int>(backupReminderDays),
      'devModeEnabled': serializer.toJson<bool>(devModeEnabled),
      'displayName': serializer.toJson<String?>(displayName),
      'onboardedAt': serializer.toJson<DateTime?>(onboardedAt),
      'theme': serializer.toJson<String?>(theme),
      'sounds': serializer.toJson<bool?>(sounds),
      'haptics': serializer.toJson<bool?>(haptics),
      'roomsView': serializer.toJson<String?>(roomsView),
      'biometricLock': serializer.toJson<bool?>(biometricLock),
      'notifyEnabled': serializer.toJson<bool?>(notifyEnabled),
      'notifyAskedAt': serializer.toJson<DateTime?>(notifyAskedAt),
      'proUnlock': serializer.toJson<bool>(proUnlock),
      'reportUnlock': serializer.toJson<bool>(reportUnlock),
      'entitlementSource': serializer.toJson<String?>(entitlementSource),
      'entitlementVerifiedAt':
          serializer.toJson<DateTime?>(entitlementVerifiedAt),
    };
  }

  SettingsRow copyWith(
          {String? id,
          String? reminderOffsetsDaysJson,
          String? currency,
          Value<DateTime?> lastBackupAt = const Value.absent(),
          int? backupReminderDays,
          bool? devModeEnabled,
          Value<String?> displayName = const Value.absent(),
          Value<DateTime?> onboardedAt = const Value.absent(),
          Value<String?> theme = const Value.absent(),
          Value<bool?> sounds = const Value.absent(),
          Value<bool?> haptics = const Value.absent(),
          Value<String?> roomsView = const Value.absent(),
          Value<bool?> biometricLock = const Value.absent(),
          Value<bool?> notifyEnabled = const Value.absent(),
          Value<DateTime?> notifyAskedAt = const Value.absent(),
          bool? proUnlock,
          bool? reportUnlock,
          Value<String?> entitlementSource = const Value.absent(),
          Value<DateTime?> entitlementVerifiedAt = const Value.absent()}) =>
      SettingsRow(
        id: id ?? this.id,
        reminderOffsetsDaysJson:
            reminderOffsetsDaysJson ?? this.reminderOffsetsDaysJson,
        currency: currency ?? this.currency,
        lastBackupAt:
            lastBackupAt.present ? lastBackupAt.value : this.lastBackupAt,
        backupReminderDays: backupReminderDays ?? this.backupReminderDays,
        devModeEnabled: devModeEnabled ?? this.devModeEnabled,
        displayName: displayName.present ? displayName.value : this.displayName,
        onboardedAt: onboardedAt.present ? onboardedAt.value : this.onboardedAt,
        theme: theme.present ? theme.value : this.theme,
        sounds: sounds.present ? sounds.value : this.sounds,
        haptics: haptics.present ? haptics.value : this.haptics,
        roomsView: roomsView.present ? roomsView.value : this.roomsView,
        biometricLock:
            biometricLock.present ? biometricLock.value : this.biometricLock,
        notifyEnabled:
            notifyEnabled.present ? notifyEnabled.value : this.notifyEnabled,
        notifyAskedAt:
            notifyAskedAt.present ? notifyAskedAt.value : this.notifyAskedAt,
        proUnlock: proUnlock ?? this.proUnlock,
        reportUnlock: reportUnlock ?? this.reportUnlock,
        entitlementSource: entitlementSource.present
            ? entitlementSource.value
            : this.entitlementSource,
        entitlementVerifiedAt: entitlementVerifiedAt.present
            ? entitlementVerifiedAt.value
            : this.entitlementVerifiedAt,
      );
  SettingsRow copyWithCompanion(SettingsTableCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      reminderOffsetsDaysJson: data.reminderOffsetsDaysJson.present
          ? data.reminderOffsetsDaysJson.value
          : this.reminderOffsetsDaysJson,
      currency: data.currency.present ? data.currency.value : this.currency,
      lastBackupAt: data.lastBackupAt.present
          ? data.lastBackupAt.value
          : this.lastBackupAt,
      backupReminderDays: data.backupReminderDays.present
          ? data.backupReminderDays.value
          : this.backupReminderDays,
      devModeEnabled: data.devModeEnabled.present
          ? data.devModeEnabled.value
          : this.devModeEnabled,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      onboardedAt:
          data.onboardedAt.present ? data.onboardedAt.value : this.onboardedAt,
      theme: data.theme.present ? data.theme.value : this.theme,
      sounds: data.sounds.present ? data.sounds.value : this.sounds,
      haptics: data.haptics.present ? data.haptics.value : this.haptics,
      roomsView: data.roomsView.present ? data.roomsView.value : this.roomsView,
      biometricLock: data.biometricLock.present
          ? data.biometricLock.value
          : this.biometricLock,
      notifyEnabled: data.notifyEnabled.present
          ? data.notifyEnabled.value
          : this.notifyEnabled,
      notifyAskedAt: data.notifyAskedAt.present
          ? data.notifyAskedAt.value
          : this.notifyAskedAt,
      proUnlock: data.proUnlock.present ? data.proUnlock.value : this.proUnlock,
      reportUnlock: data.reportUnlock.present
          ? data.reportUnlock.value
          : this.reportUnlock,
      entitlementSource: data.entitlementSource.present
          ? data.entitlementSource.value
          : this.entitlementSource,
      entitlementVerifiedAt: data.entitlementVerifiedAt.present
          ? data.entitlementVerifiedAt.value
          : this.entitlementVerifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('reminderOffsetsDaysJson: $reminderOffsetsDaysJson, ')
          ..write('currency: $currency, ')
          ..write('lastBackupAt: $lastBackupAt, ')
          ..write('backupReminderDays: $backupReminderDays, ')
          ..write('devModeEnabled: $devModeEnabled, ')
          ..write('displayName: $displayName, ')
          ..write('onboardedAt: $onboardedAt, ')
          ..write('theme: $theme, ')
          ..write('sounds: $sounds, ')
          ..write('haptics: $haptics, ')
          ..write('roomsView: $roomsView, ')
          ..write('biometricLock: $biometricLock, ')
          ..write('notifyEnabled: $notifyEnabled, ')
          ..write('notifyAskedAt: $notifyAskedAt, ')
          ..write('proUnlock: $proUnlock, ')
          ..write('reportUnlock: $reportUnlock, ')
          ..write('entitlementSource: $entitlementSource, ')
          ..write('entitlementVerifiedAt: $entitlementVerifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      reminderOffsetsDaysJson,
      currency,
      lastBackupAt,
      backupReminderDays,
      devModeEnabled,
      displayName,
      onboardedAt,
      theme,
      sounds,
      haptics,
      roomsView,
      biometricLock,
      notifyEnabled,
      notifyAskedAt,
      proUnlock,
      reportUnlock,
      entitlementSource,
      entitlementVerifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.reminderOffsetsDaysJson == this.reminderOffsetsDaysJson &&
          other.currency == this.currency &&
          other.lastBackupAt == this.lastBackupAt &&
          other.backupReminderDays == this.backupReminderDays &&
          other.devModeEnabled == this.devModeEnabled &&
          other.displayName == this.displayName &&
          other.onboardedAt == this.onboardedAt &&
          other.theme == this.theme &&
          other.sounds == this.sounds &&
          other.haptics == this.haptics &&
          other.roomsView == this.roomsView &&
          other.biometricLock == this.biometricLock &&
          other.notifyEnabled == this.notifyEnabled &&
          other.notifyAskedAt == this.notifyAskedAt &&
          other.proUnlock == this.proUnlock &&
          other.reportUnlock == this.reportUnlock &&
          other.entitlementSource == this.entitlementSource &&
          other.entitlementVerifiedAt == this.entitlementVerifiedAt);
}

class SettingsTableCompanion extends UpdateCompanion<SettingsRow> {
  final Value<String> id;
  final Value<String> reminderOffsetsDaysJson;
  final Value<String> currency;
  final Value<DateTime?> lastBackupAt;
  final Value<int> backupReminderDays;
  final Value<bool> devModeEnabled;
  final Value<String?> displayName;
  final Value<DateTime?> onboardedAt;
  final Value<String?> theme;
  final Value<bool?> sounds;
  final Value<bool?> haptics;
  final Value<String?> roomsView;
  final Value<bool?> biometricLock;
  final Value<bool?> notifyEnabled;
  final Value<DateTime?> notifyAskedAt;
  final Value<bool> proUnlock;
  final Value<bool> reportUnlock;
  final Value<String?> entitlementSource;
  final Value<DateTime?> entitlementVerifiedAt;
  final Value<int> rowid;
  const SettingsTableCompanion({
    this.id = const Value.absent(),
    this.reminderOffsetsDaysJson = const Value.absent(),
    this.currency = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.backupReminderDays = const Value.absent(),
    this.devModeEnabled = const Value.absent(),
    this.displayName = const Value.absent(),
    this.onboardedAt = const Value.absent(),
    this.theme = const Value.absent(),
    this.sounds = const Value.absent(),
    this.haptics = const Value.absent(),
    this.roomsView = const Value.absent(),
    this.biometricLock = const Value.absent(),
    this.notifyEnabled = const Value.absent(),
    this.notifyAskedAt = const Value.absent(),
    this.proUnlock = const Value.absent(),
    this.reportUnlock = const Value.absent(),
    this.entitlementSource = const Value.absent(),
    this.entitlementVerifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.reminderOffsetsDaysJson = const Value.absent(),
    this.currency = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.backupReminderDays = const Value.absent(),
    this.devModeEnabled = const Value.absent(),
    this.displayName = const Value.absent(),
    this.onboardedAt = const Value.absent(),
    this.theme = const Value.absent(),
    this.sounds = const Value.absent(),
    this.haptics = const Value.absent(),
    this.roomsView = const Value.absent(),
    this.biometricLock = const Value.absent(),
    this.notifyEnabled = const Value.absent(),
    this.notifyAskedAt = const Value.absent(),
    this.proUnlock = const Value.absent(),
    this.reportUnlock = const Value.absent(),
    this.entitlementSource = const Value.absent(),
    this.entitlementVerifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<String>? id,
    Expression<String>? reminderOffsetsDaysJson,
    Expression<String>? currency,
    Expression<DateTime>? lastBackupAt,
    Expression<int>? backupReminderDays,
    Expression<bool>? devModeEnabled,
    Expression<String>? displayName,
    Expression<DateTime>? onboardedAt,
    Expression<String>? theme,
    Expression<bool>? sounds,
    Expression<bool>? haptics,
    Expression<String>? roomsView,
    Expression<bool>? biometricLock,
    Expression<bool>? notifyEnabled,
    Expression<DateTime>? notifyAskedAt,
    Expression<bool>? proUnlock,
    Expression<bool>? reportUnlock,
    Expression<String>? entitlementSource,
    Expression<DateTime>? entitlementVerifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminderOffsetsDaysJson != null)
        'reminder_offsets_days_json': reminderOffsetsDaysJson,
      if (currency != null) 'currency': currency,
      if (lastBackupAt != null) 'last_backup_at': lastBackupAt,
      if (backupReminderDays != null)
        'backup_reminder_days': backupReminderDays,
      if (devModeEnabled != null) 'dev_mode_enabled': devModeEnabled,
      if (displayName != null) 'display_name': displayName,
      if (onboardedAt != null) 'onboarded_at': onboardedAt,
      if (theme != null) 'theme': theme,
      if (sounds != null) 'sounds': sounds,
      if (haptics != null) 'haptics': haptics,
      if (roomsView != null) 'rooms_view': roomsView,
      if (biometricLock != null) 'biometric_lock': biometricLock,
      if (notifyEnabled != null) 'notify_enabled': notifyEnabled,
      if (notifyAskedAt != null) 'notify_asked_at': notifyAskedAt,
      if (proUnlock != null) 'pro_unlock': proUnlock,
      if (reportUnlock != null) 'report_unlock': reportUnlock,
      if (entitlementSource != null) 'entitlement_source': entitlementSource,
      if (entitlementVerifiedAt != null)
        'entitlement_verified_at': entitlementVerifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? reminderOffsetsDaysJson,
      Value<String>? currency,
      Value<DateTime?>? lastBackupAt,
      Value<int>? backupReminderDays,
      Value<bool>? devModeEnabled,
      Value<String?>? displayName,
      Value<DateTime?>? onboardedAt,
      Value<String?>? theme,
      Value<bool?>? sounds,
      Value<bool?>? haptics,
      Value<String?>? roomsView,
      Value<bool?>? biometricLock,
      Value<bool?>? notifyEnabled,
      Value<DateTime?>? notifyAskedAt,
      Value<bool>? proUnlock,
      Value<bool>? reportUnlock,
      Value<String?>? entitlementSource,
      Value<DateTime?>? entitlementVerifiedAt,
      Value<int>? rowid}) {
    return SettingsTableCompanion(
      id: id ?? this.id,
      reminderOffsetsDaysJson:
          reminderOffsetsDaysJson ?? this.reminderOffsetsDaysJson,
      currency: currency ?? this.currency,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      backupReminderDays: backupReminderDays ?? this.backupReminderDays,
      devModeEnabled: devModeEnabled ?? this.devModeEnabled,
      displayName: displayName ?? this.displayName,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      theme: theme ?? this.theme,
      sounds: sounds ?? this.sounds,
      haptics: haptics ?? this.haptics,
      roomsView: roomsView ?? this.roomsView,
      biometricLock: biometricLock ?? this.biometricLock,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyAskedAt: notifyAskedAt ?? this.notifyAskedAt,
      proUnlock: proUnlock ?? this.proUnlock,
      reportUnlock: reportUnlock ?? this.reportUnlock,
      entitlementSource: entitlementSource ?? this.entitlementSource,
      entitlementVerifiedAt:
          entitlementVerifiedAt ?? this.entitlementVerifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reminderOffsetsDaysJson.present) {
      map['reminder_offsets_days_json'] =
          Variable<String>(reminderOffsetsDaysJson.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (lastBackupAt.present) {
      map['last_backup_at'] = Variable<DateTime>(lastBackupAt.value);
    }
    if (backupReminderDays.present) {
      map['backup_reminder_days'] = Variable<int>(backupReminderDays.value);
    }
    if (devModeEnabled.present) {
      map['dev_mode_enabled'] = Variable<bool>(devModeEnabled.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (onboardedAt.present) {
      map['onboarded_at'] = Variable<DateTime>(onboardedAt.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (sounds.present) {
      map['sounds'] = Variable<bool>(sounds.value);
    }
    if (haptics.present) {
      map['haptics'] = Variable<bool>(haptics.value);
    }
    if (roomsView.present) {
      map['rooms_view'] = Variable<String>(roomsView.value);
    }
    if (biometricLock.present) {
      map['biometric_lock'] = Variable<bool>(biometricLock.value);
    }
    if (notifyEnabled.present) {
      map['notify_enabled'] = Variable<bool>(notifyEnabled.value);
    }
    if (notifyAskedAt.present) {
      map['notify_asked_at'] = Variable<DateTime>(notifyAskedAt.value);
    }
    if (proUnlock.present) {
      map['pro_unlock'] = Variable<bool>(proUnlock.value);
    }
    if (reportUnlock.present) {
      map['report_unlock'] = Variable<bool>(reportUnlock.value);
    }
    if (entitlementSource.present) {
      map['entitlement_source'] = Variable<String>(entitlementSource.value);
    }
    if (entitlementVerifiedAt.present) {
      map['entitlement_verified_at'] =
          Variable<DateTime>(entitlementVerifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('reminderOffsetsDaysJson: $reminderOffsetsDaysJson, ')
          ..write('currency: $currency, ')
          ..write('lastBackupAt: $lastBackupAt, ')
          ..write('backupReminderDays: $backupReminderDays, ')
          ..write('devModeEnabled: $devModeEnabled, ')
          ..write('displayName: $displayName, ')
          ..write('onboardedAt: $onboardedAt, ')
          ..write('theme: $theme, ')
          ..write('sounds: $sounds, ')
          ..write('haptics: $haptics, ')
          ..write('roomsView: $roomsView, ')
          ..write('biometricLock: $biometricLock, ')
          ..write('notifyEnabled: $notifyEnabled, ')
          ..write('notifyAskedAt: $notifyAskedAt, ')
          ..write('proUnlock: $proUnlock, ')
          ..write('reportUnlock: $reportUnlock, ')
          ..write('entitlementSource: $entitlementSource, ')
          ..write('entitlementVerifiedAt: $entitlementVerifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$StashDatabase extends GeneratedDatabase {
  _$StashDatabase(QueryExecutor e) : super(e);
  $StashDatabaseManager get managers => $StashDatabaseManager(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $DocsTable docs = $DocsTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $SubscriptionsTable subscriptions = $SubscriptionsTable(this);
  late final $PapersTable papers = $PapersTable(this);
  late final $PropertiesTable properties = $PropertiesTable(this);
  late final $BlobsTable blobs = $BlobsTable(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        items,
        docs,
        rooms,
        subscriptions,
        papers,
        properties,
        blobs,
        settingsTable
      ];
}

typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String id,
  required String propertyId,
  required String name,
  Value<String?> brand,
  Value<String?> model,
  Value<String?> serial,
  Value<String?> roomId,
  Value<String?> purchaseDate,
  Value<int?> purchasePriceCents,
  Value<String?> currency,
  Value<String?> retailer,
  Value<String> coveragesJson,
  Value<String?> warrantyJson,
  Value<String?> extendedWarrantyJson,
  Value<int?> leadDays,
  Value<String?> notes,
  Value<String?> thumbBlobId,
  Value<String?> photoBlobId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> id,
  Value<String> propertyId,
  Value<String> name,
  Value<String?> brand,
  Value<String?> model,
  Value<String?> serial,
  Value<String?> roomId,
  Value<String?> purchaseDate,
  Value<int?> purchasePriceCents,
  Value<String?> currency,
  Value<String?> retailer,
  Value<String> coveragesJson,
  Value<String?> warrantyJson,
  Value<String?> extendedWarrantyJson,
  Value<int?> leadDays,
  Value<String?> notes,
  Value<String?> thumbBlobId,
  Value<String?> photoBlobId,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$ItemsTableFilterComposer
    extends Composer<_$StashDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomId => $composableBuilder(
      column: $table.roomId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseDate => $composableBuilder(
      column: $table.purchaseDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get purchasePriceCents => $composableBuilder(
      column: $table.purchasePriceCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get retailer => $composableBuilder(
      column: $table.retailer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coveragesJson => $composableBuilder(
      column: $table.coveragesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get warrantyJson => $composableBuilder(
      column: $table.warrantyJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extendedWarrantyJson => $composableBuilder(
      column: $table.extendedWarrantyJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leadDays => $composableBuilder(
      column: $table.leadDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbBlobId => $composableBuilder(
      column: $table.thumbBlobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoBlobId => $composableBuilder(
      column: $table.photoBlobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$ItemsTableOrderingComposer
    extends Composer<_$StashDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomId => $composableBuilder(
      column: $table.roomId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseDate => $composableBuilder(
      column: $table.purchaseDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get purchasePriceCents => $composableBuilder(
      column: $table.purchasePriceCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get retailer => $composableBuilder(
      column: $table.retailer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coveragesJson => $composableBuilder(
      column: $table.coveragesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get warrantyJson => $composableBuilder(
      column: $table.warrantyJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extendedWarrantyJson => $composableBuilder(
      column: $table.extendedWarrantyJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leadDays => $composableBuilder(
      column: $table.leadDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbBlobId => $composableBuilder(
      column: $table.thumbBlobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoBlobId => $composableBuilder(
      column: $table.photoBlobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$StashDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<String> get purchaseDate => $composableBuilder(
      column: $table.purchaseDate, builder: (column) => column);

  GeneratedColumn<int> get purchasePriceCents => $composableBuilder(
      column: $table.purchasePriceCents, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get retailer =>
      $composableBuilder(column: $table.retailer, builder: (column) => column);

  GeneratedColumn<String> get coveragesJson => $composableBuilder(
      column: $table.coveragesJson, builder: (column) => column);

  GeneratedColumn<String> get warrantyJson => $composableBuilder(
      column: $table.warrantyJson, builder: (column) => column);

  GeneratedColumn<String> get extendedWarrantyJson => $composableBuilder(
      column: $table.extendedWarrantyJson, builder: (column) => column);

  GeneratedColumn<int> get leadDays =>
      $composableBuilder(column: $table.leadDays, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get thumbBlobId => $composableBuilder(
      column: $table.thumbBlobId, builder: (column) => column);

  GeneratedColumn<String> get photoBlobId => $composableBuilder(
      column: $table.photoBlobId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ItemsTableTableManager extends RootTableManager<
    _$StashDatabase,
    $ItemsTable,
    ItemRow,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (ItemRow, BaseReferences<_$StashDatabase, $ItemsTable, ItemRow>),
    ItemRow,
    PrefetchHooks Function()> {
  $$ItemsTableTableManager(_$StashDatabase db, $ItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> propertyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> serial = const Value.absent(),
            Value<String?> roomId = const Value.absent(),
            Value<String?> purchaseDate = const Value.absent(),
            Value<int?> purchasePriceCents = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<String?> retailer = const Value.absent(),
            Value<String> coveragesJson = const Value.absent(),
            Value<String?> warrantyJson = const Value.absent(),
            Value<String?> extendedWarrantyJson = const Value.absent(),
            Value<int?> leadDays = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> thumbBlobId = const Value.absent(),
            Value<String?> photoBlobId = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion(
            id: id,
            propertyId: propertyId,
            name: name,
            brand: brand,
            model: model,
            serial: serial,
            roomId: roomId,
            purchaseDate: purchaseDate,
            purchasePriceCents: purchasePriceCents,
            currency: currency,
            retailer: retailer,
            coveragesJson: coveragesJson,
            warrantyJson: warrantyJson,
            extendedWarrantyJson: extendedWarrantyJson,
            leadDays: leadDays,
            notes: notes,
            thumbBlobId: thumbBlobId,
            photoBlobId: photoBlobId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String propertyId,
            required String name,
            Value<String?> brand = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> serial = const Value.absent(),
            Value<String?> roomId = const Value.absent(),
            Value<String?> purchaseDate = const Value.absent(),
            Value<int?> purchasePriceCents = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<String?> retailer = const Value.absent(),
            Value<String> coveragesJson = const Value.absent(),
            Value<String?> warrantyJson = const Value.absent(),
            Value<String?> extendedWarrantyJson = const Value.absent(),
            Value<int?> leadDays = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> thumbBlobId = const Value.absent(),
            Value<String?> photoBlobId = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion.insert(
            id: id,
            propertyId: propertyId,
            name: name,
            brand: brand,
            model: model,
            serial: serial,
            roomId: roomId,
            purchaseDate: purchaseDate,
            purchasePriceCents: purchasePriceCents,
            currency: currency,
            retailer: retailer,
            coveragesJson: coveragesJson,
            warrantyJson: warrantyJson,
            extendedWarrantyJson: extendedWarrantyJson,
            leadDays: leadDays,
            notes: notes,
            thumbBlobId: thumbBlobId,
            photoBlobId: photoBlobId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ItemsTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $ItemsTable,
    ItemRow,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (ItemRow, BaseReferences<_$StashDatabase, $ItemsTable, ItemRow>),
    ItemRow,
    PrefetchHooks Function()>;
typedef $$DocsTableCreateCompanionBuilder = DocsCompanion Function({
  required String id,
  required String itemId,
  Value<String> kind,
  Value<String?> title,
  Value<String?> blobId,
  Value<String?> url,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$DocsTableUpdateCompanionBuilder = DocsCompanion Function({
  Value<String> id,
  Value<String> itemId,
  Value<String> kind,
  Value<String?> title,
  Value<String?> blobId,
  Value<String?> url,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$DocsTableFilterComposer extends Composer<_$StashDatabase, $DocsTable> {
  $$DocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blobId => $composableBuilder(
      column: $table.blobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$DocsTableOrderingComposer
    extends Composer<_$StashDatabase, $DocsTable> {
  $$DocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blobId => $composableBuilder(
      column: $table.blobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$DocsTableAnnotationComposer
    extends Composer<_$StashDatabase, $DocsTable> {
  $$DocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DocsTableTableManager extends RootTableManager<
    _$StashDatabase,
    $DocsTable,
    DocRow,
    $$DocsTableFilterComposer,
    $$DocsTableOrderingComposer,
    $$DocsTableAnnotationComposer,
    $$DocsTableCreateCompanionBuilder,
    $$DocsTableUpdateCompanionBuilder,
    (DocRow, BaseReferences<_$StashDatabase, $DocsTable, DocRow>),
    DocRow,
    PrefetchHooks Function()> {
  $$DocsTableTableManager(_$StashDatabase db, $DocsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> blobId = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocsCompanion(
            id: id,
            itemId: itemId,
            kind: kind,
            title: title,
            blobId: blobId,
            url: url,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String itemId,
            Value<String> kind = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> blobId = const Value.absent(),
            Value<String?> url = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocsCompanion.insert(
            id: id,
            itemId: itemId,
            kind: kind,
            title: title,
            blobId: blobId,
            url: url,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DocsTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $DocsTable,
    DocRow,
    $$DocsTableFilterComposer,
    $$DocsTableOrderingComposer,
    $$DocsTableAnnotationComposer,
    $$DocsTableCreateCompanionBuilder,
    $$DocsTableUpdateCompanionBuilder,
    (DocRow, BaseReferences<_$StashDatabase, $DocsTable, DocRow>),
    DocRow,
    PrefetchHooks Function()>;
typedef $$RoomsTableCreateCompanionBuilder = RoomsCompanion Function({
  required String id,
  required String propertyId,
  required String name,
  Value<int> sortOrder,
  Value<bool> isSeed,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$RoomsTableUpdateCompanionBuilder = RoomsCompanion Function({
  Value<String> id,
  Value<String> propertyId,
  Value<String> name,
  Value<int> sortOrder,
  Value<bool> isSeed,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$RoomsTableFilterComposer
    extends Composer<_$StashDatabase, $RoomsTable> {
  $$RoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSeed => $composableBuilder(
      column: $table.isSeed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$RoomsTableOrderingComposer
    extends Composer<_$StashDatabase, $RoomsTable> {
  $$RoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSeed => $composableBuilder(
      column: $table.isSeed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$RoomsTableAnnotationComposer
    extends Composer<_$StashDatabase, $RoomsTable> {
  $$RoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isSeed =>
      $composableBuilder(column: $table.isSeed, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$RoomsTableTableManager extends RootTableManager<
    _$StashDatabase,
    $RoomsTable,
    RoomRow,
    $$RoomsTableFilterComposer,
    $$RoomsTableOrderingComposer,
    $$RoomsTableAnnotationComposer,
    $$RoomsTableCreateCompanionBuilder,
    $$RoomsTableUpdateCompanionBuilder,
    (RoomRow, BaseReferences<_$StashDatabase, $RoomsTable, RoomRow>),
    RoomRow,
    PrefetchHooks Function()> {
  $$RoomsTableTableManager(_$StashDatabase db, $RoomsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> propertyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isSeed = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion(
            id: id,
            propertyId: propertyId,
            name: name,
            sortOrder: sortOrder,
            isSeed: isSeed,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String propertyId,
            required String name,
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isSeed = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoomsCompanion.insert(
            id: id,
            propertyId: propertyId,
            name: name,
            sortOrder: sortOrder,
            isSeed: isSeed,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RoomsTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $RoomsTable,
    RoomRow,
    $$RoomsTableFilterComposer,
    $$RoomsTableOrderingComposer,
    $$RoomsTableAnnotationComposer,
    $$RoomsTableCreateCompanionBuilder,
    $$RoomsTableUpdateCompanionBuilder,
    (RoomRow, BaseReferences<_$StashDatabase, $RoomsTable, RoomRow>),
    RoomRow,
    PrefetchHooks Function()>;
typedef $$SubscriptionsTableCreateCompanionBuilder = SubscriptionsCompanion
    Function({
  required String id,
  required String propertyId,
  required String name,
  Value<String?> serviceId,
  Value<String?> logoBlobId,
  required String cadence,
  required String anchorDate,
  Value<int> amountCents,
  Value<String> currency,
  Value<String?> startedDate,
  Value<int?> remindDays,
  Value<String?> notes,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$SubscriptionsTableUpdateCompanionBuilder = SubscriptionsCompanion
    Function({
  Value<String> id,
  Value<String> propertyId,
  Value<String> name,
  Value<String?> serviceId,
  Value<String?> logoBlobId,
  Value<String> cadence,
  Value<String> anchorDate,
  Value<int> amountCents,
  Value<String> currency,
  Value<String?> startedDate,
  Value<int?> remindDays,
  Value<String?> notes,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$SubscriptionsTableFilterComposer
    extends Composer<_$StashDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceId => $composableBuilder(
      column: $table.serviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get logoBlobId => $composableBuilder(
      column: $table.logoBlobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cadence => $composableBuilder(
      column: $table.cadence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get anchorDate => $composableBuilder(
      column: $table.anchorDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startedDate => $composableBuilder(
      column: $table.startedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remindDays => $composableBuilder(
      column: $table.remindDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$SubscriptionsTableOrderingComposer
    extends Composer<_$StashDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceId => $composableBuilder(
      column: $table.serviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get logoBlobId => $composableBuilder(
      column: $table.logoBlobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cadence => $composableBuilder(
      column: $table.cadence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get anchorDate => $composableBuilder(
      column: $table.anchorDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedDate => $composableBuilder(
      column: $table.startedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remindDays => $composableBuilder(
      column: $table.remindDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$SubscriptionsTableAnnotationComposer
    extends Composer<_$StashDatabase, $SubscriptionsTable> {
  $$SubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<String> get logoBlobId => $composableBuilder(
      column: $table.logoBlobId, builder: (column) => column);

  GeneratedColumn<String> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<String> get anchorDate => $composableBuilder(
      column: $table.anchorDate, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get startedDate => $composableBuilder(
      column: $table.startedDate, builder: (column) => column);

  GeneratedColumn<int> get remindDays => $composableBuilder(
      column: $table.remindDays, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SubscriptionsTableTableManager extends RootTableManager<
    _$StashDatabase,
    $SubscriptionsTable,
    SubscriptionRow,
    $$SubscriptionsTableFilterComposer,
    $$SubscriptionsTableOrderingComposer,
    $$SubscriptionsTableAnnotationComposer,
    $$SubscriptionsTableCreateCompanionBuilder,
    $$SubscriptionsTableUpdateCompanionBuilder,
    (
      SubscriptionRow,
      BaseReferences<_$StashDatabase, $SubscriptionsTable, SubscriptionRow>
    ),
    SubscriptionRow,
    PrefetchHooks Function()> {
  $$SubscriptionsTableTableManager(
      _$StashDatabase db, $SubscriptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> propertyId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> serviceId = const Value.absent(),
            Value<String?> logoBlobId = const Value.absent(),
            Value<String> cadence = const Value.absent(),
            Value<String> anchorDate = const Value.absent(),
            Value<int> amountCents = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> startedDate = const Value.absent(),
            Value<int?> remindDays = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SubscriptionsCompanion(
            id: id,
            propertyId: propertyId,
            name: name,
            serviceId: serviceId,
            logoBlobId: logoBlobId,
            cadence: cadence,
            anchorDate: anchorDate,
            amountCents: amountCents,
            currency: currency,
            startedDate: startedDate,
            remindDays: remindDays,
            notes: notes,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String propertyId,
            required String name,
            Value<String?> serviceId = const Value.absent(),
            Value<String?> logoBlobId = const Value.absent(),
            required String cadence,
            required String anchorDate,
            Value<int> amountCents = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> startedDate = const Value.absent(),
            Value<int?> remindDays = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SubscriptionsCompanion.insert(
            id: id,
            propertyId: propertyId,
            name: name,
            serviceId: serviceId,
            logoBlobId: logoBlobId,
            cadence: cadence,
            anchorDate: anchorDate,
            amountCents: amountCents,
            currency: currency,
            startedDate: startedDate,
            remindDays: remindDays,
            notes: notes,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SubscriptionsTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $SubscriptionsTable,
    SubscriptionRow,
    $$SubscriptionsTableFilterComposer,
    $$SubscriptionsTableOrderingComposer,
    $$SubscriptionsTableAnnotationComposer,
    $$SubscriptionsTableCreateCompanionBuilder,
    $$SubscriptionsTableUpdateCompanionBuilder,
    (
      SubscriptionRow,
      BaseReferences<_$StashDatabase, $SubscriptionsTable, SubscriptionRow>
    ),
    SubscriptionRow,
    PrefetchHooks Function()>;
typedef $$PapersTableCreateCompanionBuilder = PapersCompanion Function({
  required String id,
  required String propertyId,
  required String kind,
  required String label,
  Value<String?> holder,
  required String expiresOn,
  Value<String?> issuedOn,
  Value<int?> leadDays,
  Value<String?> authority,
  Value<String?> storedAt,
  Value<String?> notes,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PapersTableUpdateCompanionBuilder = PapersCompanion Function({
  Value<String> id,
  Value<String> propertyId,
  Value<String> kind,
  Value<String> label,
  Value<String?> holder,
  Value<String> expiresOn,
  Value<String?> issuedOn,
  Value<int?> leadDays,
  Value<String?> authority,
  Value<String?> storedAt,
  Value<String?> notes,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$PapersTableFilterComposer
    extends Composer<_$StashDatabase, $PapersTable> {
  $$PapersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get holder => $composableBuilder(
      column: $table.holder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get expiresOn => $composableBuilder(
      column: $table.expiresOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get issuedOn => $composableBuilder(
      column: $table.issuedOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leadDays => $composableBuilder(
      column: $table.leadDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authority => $composableBuilder(
      column: $table.authority, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storedAt => $composableBuilder(
      column: $table.storedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$PapersTableOrderingComposer
    extends Composer<_$StashDatabase, $PapersTable> {
  $$PapersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get holder => $composableBuilder(
      column: $table.holder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expiresOn => $composableBuilder(
      column: $table.expiresOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get issuedOn => $composableBuilder(
      column: $table.issuedOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leadDays => $composableBuilder(
      column: $table.leadDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authority => $composableBuilder(
      column: $table.authority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storedAt => $composableBuilder(
      column: $table.storedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$PapersTableAnnotationComposer
    extends Composer<_$StashDatabase, $PapersTable> {
  $$PapersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get propertyId => $composableBuilder(
      column: $table.propertyId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get holder =>
      $composableBuilder(column: $table.holder, builder: (column) => column);

  GeneratedColumn<String> get expiresOn =>
      $composableBuilder(column: $table.expiresOn, builder: (column) => column);

  GeneratedColumn<String> get issuedOn =>
      $composableBuilder(column: $table.issuedOn, builder: (column) => column);

  GeneratedColumn<int> get leadDays =>
      $composableBuilder(column: $table.leadDays, builder: (column) => column);

  GeneratedColumn<String> get authority =>
      $composableBuilder(column: $table.authority, builder: (column) => column);

  GeneratedColumn<String> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PapersTableTableManager extends RootTableManager<
    _$StashDatabase,
    $PapersTable,
    PaperRow,
    $$PapersTableFilterComposer,
    $$PapersTableOrderingComposer,
    $$PapersTableAnnotationComposer,
    $$PapersTableCreateCompanionBuilder,
    $$PapersTableUpdateCompanionBuilder,
    (PaperRow, BaseReferences<_$StashDatabase, $PapersTable, PaperRow>),
    PaperRow,
    PrefetchHooks Function()> {
  $$PapersTableTableManager(_$StashDatabase db, $PapersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PapersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PapersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PapersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> propertyId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String?> holder = const Value.absent(),
            Value<String> expiresOn = const Value.absent(),
            Value<String?> issuedOn = const Value.absent(),
            Value<int?> leadDays = const Value.absent(),
            Value<String?> authority = const Value.absent(),
            Value<String?> storedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PapersCompanion(
            id: id,
            propertyId: propertyId,
            kind: kind,
            label: label,
            holder: holder,
            expiresOn: expiresOn,
            issuedOn: issuedOn,
            leadDays: leadDays,
            authority: authority,
            storedAt: storedAt,
            notes: notes,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String propertyId,
            required String kind,
            required String label,
            Value<String?> holder = const Value.absent(),
            required String expiresOn,
            Value<String?> issuedOn = const Value.absent(),
            Value<int?> leadDays = const Value.absent(),
            Value<String?> authority = const Value.absent(),
            Value<String?> storedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PapersCompanion.insert(
            id: id,
            propertyId: propertyId,
            kind: kind,
            label: label,
            holder: holder,
            expiresOn: expiresOn,
            issuedOn: issuedOn,
            leadDays: leadDays,
            authority: authority,
            storedAt: storedAt,
            notes: notes,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PapersTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $PapersTable,
    PaperRow,
    $$PapersTableFilterComposer,
    $$PapersTableOrderingComposer,
    $$PapersTableAnnotationComposer,
    $$PapersTableCreateCompanionBuilder,
    $$PapersTableUpdateCompanionBuilder,
    (PaperRow, BaseReferences<_$StashDatabase, $PapersTable, PaperRow>),
    PaperRow,
    PrefetchHooks Function()>;
typedef $$PropertiesTableCreateCompanionBuilder = PropertiesCompanion Function({
  required String id,
  required String name,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PropertiesTableUpdateCompanionBuilder = PropertiesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime?> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$PropertiesTableFilterComposer
    extends Composer<_$StashDatabase, $PropertiesTable> {
  $$PropertiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$PropertiesTableOrderingComposer
    extends Composer<_$StashDatabase, $PropertiesTable> {
  $$PropertiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$PropertiesTableAnnotationComposer
    extends Composer<_$StashDatabase, $PropertiesTable> {
  $$PropertiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PropertiesTableTableManager extends RootTableManager<
    _$StashDatabase,
    $PropertiesTable,
    PropertyRow,
    $$PropertiesTableFilterComposer,
    $$PropertiesTableOrderingComposer,
    $$PropertiesTableAnnotationComposer,
    $$PropertiesTableCreateCompanionBuilder,
    $$PropertiesTableUpdateCompanionBuilder,
    (
      PropertyRow,
      BaseReferences<_$StashDatabase, $PropertiesTable, PropertyRow>
    ),
    PropertyRow,
    PrefetchHooks Function()> {
  $$PropertiesTableTableManager(_$StashDatabase db, $PropertiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropertiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropertiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropertiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertiesCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PropertiesCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PropertiesTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $PropertiesTable,
    PropertyRow,
    $$PropertiesTableFilterComposer,
    $$PropertiesTableOrderingComposer,
    $$PropertiesTableAnnotationComposer,
    $$PropertiesTableCreateCompanionBuilder,
    $$PropertiesTableUpdateCompanionBuilder,
    (
      PropertyRow,
      BaseReferences<_$StashDatabase, $PropertiesTable, PropertyRow>
    ),
    PropertyRow,
    PrefetchHooks Function()>;
typedef $$BlobsTableCreateCompanionBuilder = BlobsCompanion Function({
  required String id,
  required Uint8List bytes,
  required String mime,
  Value<int> byteLength,
  Value<DateTime?> createdAt,
  Value<int> rowid,
});
typedef $$BlobsTableUpdateCompanionBuilder = BlobsCompanion Function({
  Value<String> id,
  Value<Uint8List> bytes,
  Value<String> mime,
  Value<int> byteLength,
  Value<DateTime?> createdAt,
  Value<int> rowid,
});

class $$BlobsTableFilterComposer
    extends Composer<_$StashDatabase, $BlobsTable> {
  $$BlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime => $composableBuilder(
      column: $table.mime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BlobsTableOrderingComposer
    extends Composer<_$StashDatabase, $BlobsTable> {
  $$BlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mime => $composableBuilder(
      column: $table.mime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BlobsTableAnnotationComposer
    extends Composer<_$StashDatabase, $BlobsTable> {
  $$BlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BlobsTableTableManager extends RootTableManager<
    _$StashDatabase,
    $BlobsTable,
    BlobRow,
    $$BlobsTableFilterComposer,
    $$BlobsTableOrderingComposer,
    $$BlobsTableAnnotationComposer,
    $$BlobsTableCreateCompanionBuilder,
    $$BlobsTableUpdateCompanionBuilder,
    (BlobRow, BaseReferences<_$StashDatabase, $BlobsTable, BlobRow>),
    BlobRow,
    PrefetchHooks Function()> {
  $$BlobsTableTableManager(_$StashDatabase db, $BlobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<Uint8List> bytes = const Value.absent(),
            Value<String> mime = const Value.absent(),
            Value<int> byteLength = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlobsCompanion(
            id: id,
            bytes: bytes,
            mime: mime,
            byteLength: byteLength,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required Uint8List bytes,
            required String mime,
            Value<int> byteLength = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlobsCompanion.insert(
            id: id,
            bytes: bytes,
            mime: mime,
            byteLength: byteLength,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BlobsTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $BlobsTable,
    BlobRow,
    $$BlobsTableFilterComposer,
    $$BlobsTableOrderingComposer,
    $$BlobsTableAnnotationComposer,
    $$BlobsTableCreateCompanionBuilder,
    $$BlobsTableUpdateCompanionBuilder,
    (BlobRow, BaseReferences<_$StashDatabase, $BlobsTable, BlobRow>),
    BlobRow,
    PrefetchHooks Function()>;
typedef $$SettingsTableTableCreateCompanionBuilder = SettingsTableCompanion
    Function({
  Value<String> id,
  Value<String> reminderOffsetsDaysJson,
  Value<String> currency,
  Value<DateTime?> lastBackupAt,
  Value<int> backupReminderDays,
  Value<bool> devModeEnabled,
  Value<String?> displayName,
  Value<DateTime?> onboardedAt,
  Value<String?> theme,
  Value<bool?> sounds,
  Value<bool?> haptics,
  Value<String?> roomsView,
  Value<bool?> biometricLock,
  Value<bool?> notifyEnabled,
  Value<DateTime?> notifyAskedAt,
  Value<bool> proUnlock,
  Value<bool> reportUnlock,
  Value<String?> entitlementSource,
  Value<DateTime?> entitlementVerifiedAt,
  Value<int> rowid,
});
typedef $$SettingsTableTableUpdateCompanionBuilder = SettingsTableCompanion
    Function({
  Value<String> id,
  Value<String> reminderOffsetsDaysJson,
  Value<String> currency,
  Value<DateTime?> lastBackupAt,
  Value<int> backupReminderDays,
  Value<bool> devModeEnabled,
  Value<String?> displayName,
  Value<DateTime?> onboardedAt,
  Value<String?> theme,
  Value<bool?> sounds,
  Value<bool?> haptics,
  Value<String?> roomsView,
  Value<bool?> biometricLock,
  Value<bool?> notifyEnabled,
  Value<DateTime?> notifyAskedAt,
  Value<bool> proUnlock,
  Value<bool> reportUnlock,
  Value<String?> entitlementSource,
  Value<DateTime?> entitlementVerifiedAt,
  Value<int> rowid,
});

class $$SettingsTableTableFilterComposer
    extends Composer<_$StashDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderOffsetsDaysJson => $composableBuilder(
      column: $table.reminderOffsetsDaysJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastBackupAt => $composableBuilder(
      column: $table.lastBackupAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get backupReminderDays => $composableBuilder(
      column: $table.backupReminderDays,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get devModeEnabled => $composableBuilder(
      column: $table.devModeEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get onboardedAt => $composableBuilder(
      column: $table.onboardedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get sounds => $composableBuilder(
      column: $table.sounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get haptics => $composableBuilder(
      column: $table.haptics, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomsView => $composableBuilder(
      column: $table.roomsView, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get biometricLock => $composableBuilder(
      column: $table.biometricLock, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get notifyEnabled => $composableBuilder(
      column: $table.notifyEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get notifyAskedAt => $composableBuilder(
      column: $table.notifyAskedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get proUnlock => $composableBuilder(
      column: $table.proUnlock, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get reportUnlock => $composableBuilder(
      column: $table.reportUnlock, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entitlementSource => $composableBuilder(
      column: $table.entitlementSource,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get entitlementVerifiedAt => $composableBuilder(
      column: $table.entitlementVerifiedAt,
      builder: (column) => ColumnFilters(column));
}

class $$SettingsTableTableOrderingComposer
    extends Composer<_$StashDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderOffsetsDaysJson => $composableBuilder(
      column: $table.reminderOffsetsDaysJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastBackupAt => $composableBuilder(
      column: $table.lastBackupAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get backupReminderDays => $composableBuilder(
      column: $table.backupReminderDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get devModeEnabled => $composableBuilder(
      column: $table.devModeEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get onboardedAt => $composableBuilder(
      column: $table.onboardedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get sounds => $composableBuilder(
      column: $table.sounds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get haptics => $composableBuilder(
      column: $table.haptics, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomsView => $composableBuilder(
      column: $table.roomsView, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get biometricLock => $composableBuilder(
      column: $table.biometricLock,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get notifyEnabled => $composableBuilder(
      column: $table.notifyEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get notifyAskedAt => $composableBuilder(
      column: $table.notifyAskedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get proUnlock => $composableBuilder(
      column: $table.proUnlock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get reportUnlock => $composableBuilder(
      column: $table.reportUnlock,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entitlementSource => $composableBuilder(
      column: $table.entitlementSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get entitlementVerifiedAt => $composableBuilder(
      column: $table.entitlementVerifiedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableTableAnnotationComposer
    extends Composer<_$StashDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reminderOffsetsDaysJson => $composableBuilder(
      column: $table.reminderOffsetsDaysJson, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get lastBackupAt => $composableBuilder(
      column: $table.lastBackupAt, builder: (column) => column);

  GeneratedColumn<int> get backupReminderDays => $composableBuilder(
      column: $table.backupReminderDays, builder: (column) => column);

  GeneratedColumn<bool> get devModeEnabled => $composableBuilder(
      column: $table.devModeEnabled, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<DateTime> get onboardedAt => $composableBuilder(
      column: $table.onboardedAt, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<bool> get sounds =>
      $composableBuilder(column: $table.sounds, builder: (column) => column);

  GeneratedColumn<bool> get haptics =>
      $composableBuilder(column: $table.haptics, builder: (column) => column);

  GeneratedColumn<String> get roomsView =>
      $composableBuilder(column: $table.roomsView, builder: (column) => column);

  GeneratedColumn<bool> get biometricLock => $composableBuilder(
      column: $table.biometricLock, builder: (column) => column);

  GeneratedColumn<bool> get notifyEnabled => $composableBuilder(
      column: $table.notifyEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get notifyAskedAt => $composableBuilder(
      column: $table.notifyAskedAt, builder: (column) => column);

  GeneratedColumn<bool> get proUnlock =>
      $composableBuilder(column: $table.proUnlock, builder: (column) => column);

  GeneratedColumn<bool> get reportUnlock => $composableBuilder(
      column: $table.reportUnlock, builder: (column) => column);

  GeneratedColumn<String> get entitlementSource => $composableBuilder(
      column: $table.entitlementSource, builder: (column) => column);

  GeneratedColumn<DateTime> get entitlementVerifiedAt => $composableBuilder(
      column: $table.entitlementVerifiedAt, builder: (column) => column);
}

class $$SettingsTableTableTableManager extends RootTableManager<
    _$StashDatabase,
    $SettingsTableTable,
    SettingsRow,
    $$SettingsTableTableFilterComposer,
    $$SettingsTableTableOrderingComposer,
    $$SettingsTableTableAnnotationComposer,
    $$SettingsTableTableCreateCompanionBuilder,
    $$SettingsTableTableUpdateCompanionBuilder,
    (
      SettingsRow,
      BaseReferences<_$StashDatabase, $SettingsTableTable, SettingsRow>
    ),
    SettingsRow,
    PrefetchHooks Function()> {
  $$SettingsTableTableTableManager(
      _$StashDatabase db, $SettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> reminderOffsetsDaysJson = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime?> lastBackupAt = const Value.absent(),
            Value<int> backupReminderDays = const Value.absent(),
            Value<bool> devModeEnabled = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<DateTime?> onboardedAt = const Value.absent(),
            Value<String?> theme = const Value.absent(),
            Value<bool?> sounds = const Value.absent(),
            Value<bool?> haptics = const Value.absent(),
            Value<String?> roomsView = const Value.absent(),
            Value<bool?> biometricLock = const Value.absent(),
            Value<bool?> notifyEnabled = const Value.absent(),
            Value<DateTime?> notifyAskedAt = const Value.absent(),
            Value<bool> proUnlock = const Value.absent(),
            Value<bool> reportUnlock = const Value.absent(),
            Value<String?> entitlementSource = const Value.absent(),
            Value<DateTime?> entitlementVerifiedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsTableCompanion(
            id: id,
            reminderOffsetsDaysJson: reminderOffsetsDaysJson,
            currency: currency,
            lastBackupAt: lastBackupAt,
            backupReminderDays: backupReminderDays,
            devModeEnabled: devModeEnabled,
            displayName: displayName,
            onboardedAt: onboardedAt,
            theme: theme,
            sounds: sounds,
            haptics: haptics,
            roomsView: roomsView,
            biometricLock: biometricLock,
            notifyEnabled: notifyEnabled,
            notifyAskedAt: notifyAskedAt,
            proUnlock: proUnlock,
            reportUnlock: reportUnlock,
            entitlementSource: entitlementSource,
            entitlementVerifiedAt: entitlementVerifiedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> reminderOffsetsDaysJson = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime?> lastBackupAt = const Value.absent(),
            Value<int> backupReminderDays = const Value.absent(),
            Value<bool> devModeEnabled = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<DateTime?> onboardedAt = const Value.absent(),
            Value<String?> theme = const Value.absent(),
            Value<bool?> sounds = const Value.absent(),
            Value<bool?> haptics = const Value.absent(),
            Value<String?> roomsView = const Value.absent(),
            Value<bool?> biometricLock = const Value.absent(),
            Value<bool?> notifyEnabled = const Value.absent(),
            Value<DateTime?> notifyAskedAt = const Value.absent(),
            Value<bool> proUnlock = const Value.absent(),
            Value<bool> reportUnlock = const Value.absent(),
            Value<String?> entitlementSource = const Value.absent(),
            Value<DateTime?> entitlementVerifiedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsTableCompanion.insert(
            id: id,
            reminderOffsetsDaysJson: reminderOffsetsDaysJson,
            currency: currency,
            lastBackupAt: lastBackupAt,
            backupReminderDays: backupReminderDays,
            devModeEnabled: devModeEnabled,
            displayName: displayName,
            onboardedAt: onboardedAt,
            theme: theme,
            sounds: sounds,
            haptics: haptics,
            roomsView: roomsView,
            biometricLock: biometricLock,
            notifyEnabled: notifyEnabled,
            notifyAskedAt: notifyAskedAt,
            proUnlock: proUnlock,
            reportUnlock: reportUnlock,
            entitlementSource: entitlementSource,
            entitlementVerifiedAt: entitlementVerifiedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableTableProcessedTableManager = ProcessedTableManager<
    _$StashDatabase,
    $SettingsTableTable,
    SettingsRow,
    $$SettingsTableTableFilterComposer,
    $$SettingsTableTableOrderingComposer,
    $$SettingsTableTableAnnotationComposer,
    $$SettingsTableTableCreateCompanionBuilder,
    $$SettingsTableTableUpdateCompanionBuilder,
    (
      SettingsRow,
      BaseReferences<_$StashDatabase, $SettingsTableTable, SettingsRow>
    ),
    SettingsRow,
    PrefetchHooks Function()>;

class $StashDatabaseManager {
  final _$StashDatabase _db;
  $StashDatabaseManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$DocsTableTableManager get docs => $$DocsTableTableManager(_db, _db.docs);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db, _db.subscriptions);
  $$PapersTableTableManager get papers =>
      $$PapersTableTableManager(_db, _db.papers);
  $$PropertiesTableTableManager get properties =>
      $$PropertiesTableTableManager(_db, _db.properties);
  $$BlobsTableTableManager get blobs =>
      $$BlobsTableTableManager(_db, _db.blobs);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
}
