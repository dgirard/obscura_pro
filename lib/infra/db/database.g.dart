// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PatternsTable extends Patterns with TableInfo<$PatternsTable, Pattern> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatternsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nomMeta = const VerificationMeta('nom');
  @override
  late final GeneratedColumn<String> nom = GeneratedColumn<String>(
    'nom',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categorieMeta = const VerificationMeta(
    'categorie',
  );
  @override
  late final GeneratedColumn<String> categorie = GeneratedColumn<String>(
    'categorie',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('guide'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, nom, categorie, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pattern';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pattern> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('nom')) {
      context.handle(
        _nomMeta,
        nom.isAcceptableOrUnknown(data['nom']!, _nomMeta),
      );
    } else if (isInserting) {
      context.missing(_nomMeta);
    }
    if (data.containsKey('categorie')) {
      context.handle(
        _categorieMeta,
        categorie.isAcceptableOrUnknown(data['categorie']!, _categorieMeta),
      );
    } else if (isInserting) {
      context.missing(_categorieMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pattern map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pattern(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      nom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nom'],
      )!,
      categorie: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categorie'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $PatternsTable createAlias(String alias) {
    return $PatternsTable(attachedDatabase, alias);
  }
}

class Pattern extends DataClass implements Insertable<Pattern> {
  final int id;
  final String code;
  final String nom;
  final String categorie;

  /// `guide` for the fifteen that can be laid over a photograph, `reference`
  /// for the fifteen that are a card to read. Stored as text for the same
  /// reason [TrashItems.state] is: these rows get read by hand.
  final String kind;
  const Pattern({
    required this.id,
    required this.code,
    required this.nom,
    required this.categorie,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['nom'] = Variable<String>(nom);
    map['categorie'] = Variable<String>(categorie);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  PatternsCompanion toCompanion(bool nullToAbsent) {
    return PatternsCompanion(
      id: Value(id),
      code: Value(code),
      nom: Value(nom),
      categorie: Value(categorie),
      kind: Value(kind),
    );
  }

  factory Pattern.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pattern(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      nom: serializer.fromJson<String>(json['nom']),
      categorie: serializer.fromJson<String>(json['categorie']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'nom': serializer.toJson<String>(nom),
      'categorie': serializer.toJson<String>(categorie),
      'kind': serializer.toJson<String>(kind),
    };
  }

  Pattern copyWith({
    int? id,
    String? code,
    String? nom,
    String? categorie,
    String? kind,
  }) => Pattern(
    id: id ?? this.id,
    code: code ?? this.code,
    nom: nom ?? this.nom,
    categorie: categorie ?? this.categorie,
    kind: kind ?? this.kind,
  );
  Pattern copyWithCompanion(PatternsCompanion data) {
    return Pattern(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      nom: data.nom.present ? data.nom.value : this.nom,
      categorie: data.categorie.present ? data.categorie.value : this.categorie,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pattern(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('nom: $nom, ')
          ..write('categorie: $categorie, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, nom, categorie, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pattern &&
          other.id == this.id &&
          other.code == this.code &&
          other.nom == this.nom &&
          other.categorie == this.categorie &&
          other.kind == this.kind);
}

class PatternsCompanion extends UpdateCompanion<Pattern> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> nom;
  final Value<String> categorie;
  final Value<String> kind;
  const PatternsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.nom = const Value.absent(),
    this.categorie = const Value.absent(),
    this.kind = const Value.absent(),
  });
  PatternsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String nom,
    required String categorie,
    this.kind = const Value.absent(),
  }) : code = Value(code),
       nom = Value(nom),
       categorie = Value(categorie);
  static Insertable<Pattern> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? nom,
    Expression<String>? categorie,
    Expression<String>? kind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (nom != null) 'nom': nom,
      if (categorie != null) 'categorie': categorie,
      if (kind != null) 'kind': kind,
    });
  }

  PatternsCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<String>? nom,
    Value<String>? categorie,
    Value<String>? kind,
  }) {
    return PatternsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      nom: nom ?? this.nom,
      categorie: categorie ?? this.categorie,
      kind: kind ?? this.kind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (nom.present) {
      map['nom'] = Variable<String>(nom.value);
    }
    if (categorie.present) {
      map['categorie'] = Variable<String>(categorie.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatternsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('nom: $nom, ')
          ..write('categorie: $categorie, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cleStableMeta = const VerificationMeta(
    'cleStable',
  );
  @override
  late final GeneratedColumn<String> cleStable = GeneratedColumn<String>(
    'cle_stable',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _radicalDcfMeta = const VerificationMeta(
    'radicalDcf',
  );
  @override
  late final GeneratedColumn<String> radicalDcf = GeneratedColumn<String>(
    'radical_dcf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateOriginMeta = const VerificationMeta(
    'dateOrigin',
  );
  @override
  late final GeneratedColumn<DateTime> dateOrigin = GeneratedColumn<DateTime>(
    'date_origin',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serialBoitierMeta = const VerificationMeta(
    'serialBoitier',
  );
  @override
  late final GeneratedColumn<String> serialBoitier = GeneratedColumn<String>(
    'serial_boitier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dngPresentMeta = const VerificationMeta(
    'dngPresent',
  );
  @override
  late final GeneratedColumn<bool> dngPresent = GeneratedColumn<bool>(
    'dng_present',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dng_present" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _jpgPresentMeta = const VerificationMeta(
    'jpgPresent',
  );
  @override
  late final GeneratedColumn<bool> jpgPresent = GeneratedColumn<bool>(
    'jpg_present',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("jpg_present" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _previewSmallOffsetMeta =
      const VerificationMeta('previewSmallOffset');
  @override
  late final GeneratedColumn<int> previewSmallOffset = GeneratedColumn<int>(
    'preview_small_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewSmallLengthMeta =
      const VerificationMeta('previewSmallLength');
  @override
  late final GeneratedColumn<int> previewSmallLength = GeneratedColumn<int>(
    'preview_small_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewFullOffsetMeta = const VerificationMeta(
    'previewFullOffset',
  );
  @override
  late final GeneratedColumn<int> previewFullOffset = GeneratedColumn<int>(
    'preview_full_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previewFullLengthMeta = const VerificationMeta(
    'previewFullLength',
  );
  @override
  late final GeneratedColumn<int> previewFullLength = GeneratedColumn<int>(
    'preview_full_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cleStable,
    radicalDcf,
    dateOrigin,
    serialBoitier,
    dngPresent,
    jpgPresent,
    previewSmallOffset,
    previewSmallLength,
    previewFullOffset,
    previewFullLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo';
  @override
  VerificationContext validateIntegrity(
    Insertable<Photo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cle_stable')) {
      context.handle(
        _cleStableMeta,
        cleStable.isAcceptableOrUnknown(data['cle_stable']!, _cleStableMeta),
      );
    } else if (isInserting) {
      context.missing(_cleStableMeta);
    }
    if (data.containsKey('radical_dcf')) {
      context.handle(
        _radicalDcfMeta,
        radicalDcf.isAcceptableOrUnknown(data['radical_dcf']!, _radicalDcfMeta),
      );
    } else if (isInserting) {
      context.missing(_radicalDcfMeta);
    }
    if (data.containsKey('date_origin')) {
      context.handle(
        _dateOriginMeta,
        dateOrigin.isAcceptableOrUnknown(data['date_origin']!, _dateOriginMeta),
      );
    }
    if (data.containsKey('serial_boitier')) {
      context.handle(
        _serialBoitierMeta,
        serialBoitier.isAcceptableOrUnknown(
          data['serial_boitier']!,
          _serialBoitierMeta,
        ),
      );
    }
    if (data.containsKey('dng_present')) {
      context.handle(
        _dngPresentMeta,
        dngPresent.isAcceptableOrUnknown(data['dng_present']!, _dngPresentMeta),
      );
    }
    if (data.containsKey('jpg_present')) {
      context.handle(
        _jpgPresentMeta,
        jpgPresent.isAcceptableOrUnknown(data['jpg_present']!, _jpgPresentMeta),
      );
    }
    if (data.containsKey('preview_small_offset')) {
      context.handle(
        _previewSmallOffsetMeta,
        previewSmallOffset.isAcceptableOrUnknown(
          data['preview_small_offset']!,
          _previewSmallOffsetMeta,
        ),
      );
    }
    if (data.containsKey('preview_small_length')) {
      context.handle(
        _previewSmallLengthMeta,
        previewSmallLength.isAcceptableOrUnknown(
          data['preview_small_length']!,
          _previewSmallLengthMeta,
        ),
      );
    }
    if (data.containsKey('preview_full_offset')) {
      context.handle(
        _previewFullOffsetMeta,
        previewFullOffset.isAcceptableOrUnknown(
          data['preview_full_offset']!,
          _previewFullOffsetMeta,
        ),
      );
    }
    if (data.containsKey('preview_full_length')) {
      context.handle(
        _previewFullLengthMeta,
        previewFullLength.isAcceptableOrUnknown(
          data['preview_full_length']!,
          _previewFullLengthMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cleStable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cle_stable'],
      )!,
      radicalDcf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}radical_dcf'],
      )!,
      dateOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_origin'],
      ),
      serialBoitier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial_boitier'],
      ),
      dngPresent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dng_present'],
      )!,
      jpgPresent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}jpg_present'],
      )!,
      previewSmallOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preview_small_offset'],
      ),
      previewSmallLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preview_small_length'],
      ),
      previewFullOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preview_full_offset'],
      ),
      previewFullLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preview_full_length'],
      ),
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  final int id;

  /// Hash of radical + DateTimeOriginal + body serial (+ size/mtime fallback).
  /// Unique because two rows for one file would let the app delete a card file
  /// while another row still claims it is on the card.
  final String cleStable;

  /// DCF radical, e.g. `100LEICA/L1000001` -- folder plus 8.3 stem, without the
  /// extension, since the two files of one entity share it.
  final String radicalDcf;

  /// EXIF DateTimeOriginal. The camera records no timezone, so this is a
  /// wall-clock instant and must not be shifted when displayed.
  final DateTime? dateOrigin;
  final String? serialBoitier;
  final bool dngPresent;
  final bool jpgPresent;

  /// Byte range of the embedded grid preview inside the DNG.
  ///
  /// Cached here so decode workers never walk the IFD chain twice; the JPG
  /// sibling needs no offsets because the file is itself a decodable frame.
  /// Null until the header parser has run.
  final int? previewSmallOffset;
  final int? previewSmallLength;

  /// Byte range of the embedded full-size preview used by the viewer.
  final int? previewFullOffset;
  final int? previewFullLength;
  const Photo({
    required this.id,
    required this.cleStable,
    required this.radicalDcf,
    this.dateOrigin,
    this.serialBoitier,
    required this.dngPresent,
    required this.jpgPresent,
    this.previewSmallOffset,
    this.previewSmallLength,
    this.previewFullOffset,
    this.previewFullLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cle_stable'] = Variable<String>(cleStable);
    map['radical_dcf'] = Variable<String>(radicalDcf);
    if (!nullToAbsent || dateOrigin != null) {
      map['date_origin'] = Variable<DateTime>(dateOrigin);
    }
    if (!nullToAbsent || serialBoitier != null) {
      map['serial_boitier'] = Variable<String>(serialBoitier);
    }
    map['dng_present'] = Variable<bool>(dngPresent);
    map['jpg_present'] = Variable<bool>(jpgPresent);
    if (!nullToAbsent || previewSmallOffset != null) {
      map['preview_small_offset'] = Variable<int>(previewSmallOffset);
    }
    if (!nullToAbsent || previewSmallLength != null) {
      map['preview_small_length'] = Variable<int>(previewSmallLength);
    }
    if (!nullToAbsent || previewFullOffset != null) {
      map['preview_full_offset'] = Variable<int>(previewFullOffset);
    }
    if (!nullToAbsent || previewFullLength != null) {
      map['preview_full_length'] = Variable<int>(previewFullLength);
    }
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      cleStable: Value(cleStable),
      radicalDcf: Value(radicalDcf),
      dateOrigin: dateOrigin == null && nullToAbsent
          ? const Value.absent()
          : Value(dateOrigin),
      serialBoitier: serialBoitier == null && nullToAbsent
          ? const Value.absent()
          : Value(serialBoitier),
      dngPresent: Value(dngPresent),
      jpgPresent: Value(jpgPresent),
      previewSmallOffset: previewSmallOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(previewSmallOffset),
      previewSmallLength: previewSmallLength == null && nullToAbsent
          ? const Value.absent()
          : Value(previewSmallLength),
      previewFullOffset: previewFullOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(previewFullOffset),
      previewFullLength: previewFullLength == null && nullToAbsent
          ? const Value.absent()
          : Value(previewFullLength),
    );
  }

  factory Photo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      id: serializer.fromJson<int>(json['id']),
      cleStable: serializer.fromJson<String>(json['cleStable']),
      radicalDcf: serializer.fromJson<String>(json['radicalDcf']),
      dateOrigin: serializer.fromJson<DateTime?>(json['dateOrigin']),
      serialBoitier: serializer.fromJson<String?>(json['serialBoitier']),
      dngPresent: serializer.fromJson<bool>(json['dngPresent']),
      jpgPresent: serializer.fromJson<bool>(json['jpgPresent']),
      previewSmallOffset: serializer.fromJson<int?>(json['previewSmallOffset']),
      previewSmallLength: serializer.fromJson<int?>(json['previewSmallLength']),
      previewFullOffset: serializer.fromJson<int?>(json['previewFullOffset']),
      previewFullLength: serializer.fromJson<int?>(json['previewFullLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cleStable': serializer.toJson<String>(cleStable),
      'radicalDcf': serializer.toJson<String>(radicalDcf),
      'dateOrigin': serializer.toJson<DateTime?>(dateOrigin),
      'serialBoitier': serializer.toJson<String?>(serialBoitier),
      'dngPresent': serializer.toJson<bool>(dngPresent),
      'jpgPresent': serializer.toJson<bool>(jpgPresent),
      'previewSmallOffset': serializer.toJson<int?>(previewSmallOffset),
      'previewSmallLength': serializer.toJson<int?>(previewSmallLength),
      'previewFullOffset': serializer.toJson<int?>(previewFullOffset),
      'previewFullLength': serializer.toJson<int?>(previewFullLength),
    };
  }

  Photo copyWith({
    int? id,
    String? cleStable,
    String? radicalDcf,
    Value<DateTime?> dateOrigin = const Value.absent(),
    Value<String?> serialBoitier = const Value.absent(),
    bool? dngPresent,
    bool? jpgPresent,
    Value<int?> previewSmallOffset = const Value.absent(),
    Value<int?> previewSmallLength = const Value.absent(),
    Value<int?> previewFullOffset = const Value.absent(),
    Value<int?> previewFullLength = const Value.absent(),
  }) => Photo(
    id: id ?? this.id,
    cleStable: cleStable ?? this.cleStable,
    radicalDcf: radicalDcf ?? this.radicalDcf,
    dateOrigin: dateOrigin.present ? dateOrigin.value : this.dateOrigin,
    serialBoitier: serialBoitier.present
        ? serialBoitier.value
        : this.serialBoitier,
    dngPresent: dngPresent ?? this.dngPresent,
    jpgPresent: jpgPresent ?? this.jpgPresent,
    previewSmallOffset: previewSmallOffset.present
        ? previewSmallOffset.value
        : this.previewSmallOffset,
    previewSmallLength: previewSmallLength.present
        ? previewSmallLength.value
        : this.previewSmallLength,
    previewFullOffset: previewFullOffset.present
        ? previewFullOffset.value
        : this.previewFullOffset,
    previewFullLength: previewFullLength.present
        ? previewFullLength.value
        : this.previewFullLength,
  );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      id: data.id.present ? data.id.value : this.id,
      cleStable: data.cleStable.present ? data.cleStable.value : this.cleStable,
      radicalDcf: data.radicalDcf.present
          ? data.radicalDcf.value
          : this.radicalDcf,
      dateOrigin: data.dateOrigin.present
          ? data.dateOrigin.value
          : this.dateOrigin,
      serialBoitier: data.serialBoitier.present
          ? data.serialBoitier.value
          : this.serialBoitier,
      dngPresent: data.dngPresent.present
          ? data.dngPresent.value
          : this.dngPresent,
      jpgPresent: data.jpgPresent.present
          ? data.jpgPresent.value
          : this.jpgPresent,
      previewSmallOffset: data.previewSmallOffset.present
          ? data.previewSmallOffset.value
          : this.previewSmallOffset,
      previewSmallLength: data.previewSmallLength.present
          ? data.previewSmallLength.value
          : this.previewSmallLength,
      previewFullOffset: data.previewFullOffset.present
          ? data.previewFullOffset.value
          : this.previewFullOffset,
      previewFullLength: data.previewFullLength.present
          ? data.previewFullLength.value
          : this.previewFullLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('id: $id, ')
          ..write('cleStable: $cleStable, ')
          ..write('radicalDcf: $radicalDcf, ')
          ..write('dateOrigin: $dateOrigin, ')
          ..write('serialBoitier: $serialBoitier, ')
          ..write('dngPresent: $dngPresent, ')
          ..write('jpgPresent: $jpgPresent, ')
          ..write('previewSmallOffset: $previewSmallOffset, ')
          ..write('previewSmallLength: $previewSmallLength, ')
          ..write('previewFullOffset: $previewFullOffset, ')
          ..write('previewFullLength: $previewFullLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cleStable,
    radicalDcf,
    dateOrigin,
    serialBoitier,
    dngPresent,
    jpgPresent,
    previewSmallOffset,
    previewSmallLength,
    previewFullOffset,
    previewFullLength,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.id == this.id &&
          other.cleStable == this.cleStable &&
          other.radicalDcf == this.radicalDcf &&
          other.dateOrigin == this.dateOrigin &&
          other.serialBoitier == this.serialBoitier &&
          other.dngPresent == this.dngPresent &&
          other.jpgPresent == this.jpgPresent &&
          other.previewSmallOffset == this.previewSmallOffset &&
          other.previewSmallLength == this.previewSmallLength &&
          other.previewFullOffset == this.previewFullOffset &&
          other.previewFullLength == this.previewFullLength);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<int> id;
  final Value<String> cleStable;
  final Value<String> radicalDcf;
  final Value<DateTime?> dateOrigin;
  final Value<String?> serialBoitier;
  final Value<bool> dngPresent;
  final Value<bool> jpgPresent;
  final Value<int?> previewSmallOffset;
  final Value<int?> previewSmallLength;
  final Value<int?> previewFullOffset;
  final Value<int?> previewFullLength;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.cleStable = const Value.absent(),
    this.radicalDcf = const Value.absent(),
    this.dateOrigin = const Value.absent(),
    this.serialBoitier = const Value.absent(),
    this.dngPresent = const Value.absent(),
    this.jpgPresent = const Value.absent(),
    this.previewSmallOffset = const Value.absent(),
    this.previewSmallLength = const Value.absent(),
    this.previewFullOffset = const Value.absent(),
    this.previewFullLength = const Value.absent(),
  });
  PhotosCompanion.insert({
    this.id = const Value.absent(),
    required String cleStable,
    required String radicalDcf,
    this.dateOrigin = const Value.absent(),
    this.serialBoitier = const Value.absent(),
    this.dngPresent = const Value.absent(),
    this.jpgPresent = const Value.absent(),
    this.previewSmallOffset = const Value.absent(),
    this.previewSmallLength = const Value.absent(),
    this.previewFullOffset = const Value.absent(),
    this.previewFullLength = const Value.absent(),
  }) : cleStable = Value(cleStable),
       radicalDcf = Value(radicalDcf);
  static Insertable<Photo> custom({
    Expression<int>? id,
    Expression<String>? cleStable,
    Expression<String>? radicalDcf,
    Expression<DateTime>? dateOrigin,
    Expression<String>? serialBoitier,
    Expression<bool>? dngPresent,
    Expression<bool>? jpgPresent,
    Expression<int>? previewSmallOffset,
    Expression<int>? previewSmallLength,
    Expression<int>? previewFullOffset,
    Expression<int>? previewFullLength,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cleStable != null) 'cle_stable': cleStable,
      if (radicalDcf != null) 'radical_dcf': radicalDcf,
      if (dateOrigin != null) 'date_origin': dateOrigin,
      if (serialBoitier != null) 'serial_boitier': serialBoitier,
      if (dngPresent != null) 'dng_present': dngPresent,
      if (jpgPresent != null) 'jpg_present': jpgPresent,
      if (previewSmallOffset != null)
        'preview_small_offset': previewSmallOffset,
      if (previewSmallLength != null)
        'preview_small_length': previewSmallLength,
      if (previewFullOffset != null) 'preview_full_offset': previewFullOffset,
      if (previewFullLength != null) 'preview_full_length': previewFullLength,
    });
  }

  PhotosCompanion copyWith({
    Value<int>? id,
    Value<String>? cleStable,
    Value<String>? radicalDcf,
    Value<DateTime?>? dateOrigin,
    Value<String?>? serialBoitier,
    Value<bool>? dngPresent,
    Value<bool>? jpgPresent,
    Value<int?>? previewSmallOffset,
    Value<int?>? previewSmallLength,
    Value<int?>? previewFullOffset,
    Value<int?>? previewFullLength,
  }) {
    return PhotosCompanion(
      id: id ?? this.id,
      cleStable: cleStable ?? this.cleStable,
      radicalDcf: radicalDcf ?? this.radicalDcf,
      dateOrigin: dateOrigin ?? this.dateOrigin,
      serialBoitier: serialBoitier ?? this.serialBoitier,
      dngPresent: dngPresent ?? this.dngPresent,
      jpgPresent: jpgPresent ?? this.jpgPresent,
      previewSmallOffset: previewSmallOffset ?? this.previewSmallOffset,
      previewSmallLength: previewSmallLength ?? this.previewSmallLength,
      previewFullOffset: previewFullOffset ?? this.previewFullOffset,
      previewFullLength: previewFullLength ?? this.previewFullLength,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cleStable.present) {
      map['cle_stable'] = Variable<String>(cleStable.value);
    }
    if (radicalDcf.present) {
      map['radical_dcf'] = Variable<String>(radicalDcf.value);
    }
    if (dateOrigin.present) {
      map['date_origin'] = Variable<DateTime>(dateOrigin.value);
    }
    if (serialBoitier.present) {
      map['serial_boitier'] = Variable<String>(serialBoitier.value);
    }
    if (dngPresent.present) {
      map['dng_present'] = Variable<bool>(dngPresent.value);
    }
    if (jpgPresent.present) {
      map['jpg_present'] = Variable<bool>(jpgPresent.value);
    }
    if (previewSmallOffset.present) {
      map['preview_small_offset'] = Variable<int>(previewSmallOffset.value);
    }
    if (previewSmallLength.present) {
      map['preview_small_length'] = Variable<int>(previewSmallLength.value);
    }
    if (previewFullOffset.present) {
      map['preview_full_offset'] = Variable<int>(previewFullOffset.value);
    }
    if (previewFullLength.present) {
      map['preview_full_length'] = Variable<int>(previewFullLength.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('cleStable: $cleStable, ')
          ..write('radicalDcf: $radicalDcf, ')
          ..write('dateOrigin: $dateOrigin, ')
          ..write('serialBoitier: $serialBoitier, ')
          ..write('dngPresent: $dngPresent, ')
          ..write('jpgPresent: $jpgPresent, ')
          ..write('previewSmallOffset: $previewSmallOffset, ')
          ..write('previewSmallLength: $previewSmallLength, ')
          ..write('previewFullOffset: $previewFullOffset, ')
          ..write('previewFullLength: $previewFullLength')
          ..write(')'))
        .toString();
  }
}

class $LayerInstancesTable extends LayerInstances
    with TableInfo<$LayerInstancesTable, LayerInstance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LayerInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta(
    'patternId',
  );
  @override
  late final GeneratedColumn<int> patternId = GeneratedColumn<int>(
    'pattern_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pattern (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _posXMeta = const VerificationMeta('posX');
  @override
  late final GeneratedColumn<double> posX = GeneratedColumn<double>(
    'pos_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _posYMeta = const VerificationMeta('posY');
  @override
  late final GeneratedColumn<double> posY = GeneratedColumn<double>(
    'pos_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _scaleXMeta = const VerificationMeta('scaleX');
  @override
  late final GeneratedColumn<double> scaleX = GeneratedColumn<double>(
    'scale_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _scaleYMeta = const VerificationMeta('scaleY');
  @override
  late final GeneratedColumn<double> scaleY = GeneratedColumn<double>(
    'scale_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _opacityMeta = const VerificationMeta(
    'opacity',
  );
  @override
  late final GeneratedColumn<double> opacity = GeneratedColumn<double>(
    'opacity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zIndexMeta = const VerificationMeta('zIndex');
  @override
  late final GeneratedColumn<int> zIndex = GeneratedColumn<int>(
    'z_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _obscuraMeta = const VerificationMeta(
    'obscura',
  );
  @override
  late final GeneratedColumn<bool> obscura = GeneratedColumn<bool>(
    'obscura',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("obscura" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    photoId,
    patternId,
    posX,
    posY,
    scaleX,
    scaleY,
    rotation,
    opacity,
    color,
    zIndex,
    locked,
    obscura,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'layer_instance';
  @override
  VerificationContext validateIntegrity(
    Insertable<LayerInstance> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patternIdMeta);
    }
    if (data.containsKey('pos_x')) {
      context.handle(
        _posXMeta,
        posX.isAcceptableOrUnknown(data['pos_x']!, _posXMeta),
      );
    }
    if (data.containsKey('pos_y')) {
      context.handle(
        _posYMeta,
        posY.isAcceptableOrUnknown(data['pos_y']!, _posYMeta),
      );
    }
    if (data.containsKey('scale_x')) {
      context.handle(
        _scaleXMeta,
        scaleX.isAcceptableOrUnknown(data['scale_x']!, _scaleXMeta),
      );
    }
    if (data.containsKey('scale_y')) {
      context.handle(
        _scaleYMeta,
        scaleY.isAcceptableOrUnknown(data['scale_y']!, _scaleYMeta),
      );
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('opacity')) {
      context.handle(
        _opacityMeta,
        opacity.isAcceptableOrUnknown(data['opacity']!, _opacityMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('z_index')) {
      context.handle(
        _zIndexMeta,
        zIndex.isAcceptableOrUnknown(data['z_index']!, _zIndexMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('obscura')) {
      context.handle(
        _obscuraMeta,
        obscura.isAcceptableOrUnknown(data['obscura']!, _obscuraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LayerInstance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LayerInstance(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      )!,
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pattern_id'],
      )!,
      posX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_x'],
      )!,
      posY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_y'],
      )!,
      scaleX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scale_x'],
      )!,
      scaleY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scale_y'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      opacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opacity'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      zIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}z_index'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      obscura: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}obscura'],
      )!,
    );
  }

  @override
  $LayerInstancesTable createAlias(String alias) {
    return $LayerInstancesTable(attachedDatabase, alias);
  }
}

class LayerInstance extends DataClass implements Insertable<LayerInstance> {
  final int id;

  /// Cascades: a layer describes a photo and means nothing without it.
  final int photoId;

  /// Restricted, not cascading: deleting a pattern still in use would silently
  /// erase the user's composition instead of refusing an unsafe edit.
  final int patternId;
  final double posX;
  final double posY;
  final double scaleX;
  final double scaleY;

  /// Radians, clockwise from the frame's horizontal.
  final double rotation;
  final double opacity;

  /// ARGB, stored as a plain int so it does not depend on a Flutter type.
  final int color;
  final int zIndex;
  final bool locked;

  /// Whether the layer was placed in obscura mode; kept so the placement can be
  /// re-read in the same perceptual context it was judged in.
  final bool obscura;
  const LayerInstance({
    required this.id,
    required this.photoId,
    required this.patternId,
    required this.posX,
    required this.posY,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.opacity,
    required this.color,
    required this.zIndex,
    required this.locked,
    required this.obscura,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['photo_id'] = Variable<int>(photoId);
    map['pattern_id'] = Variable<int>(patternId);
    map['pos_x'] = Variable<double>(posX);
    map['pos_y'] = Variable<double>(posY);
    map['scale_x'] = Variable<double>(scaleX);
    map['scale_y'] = Variable<double>(scaleY);
    map['rotation'] = Variable<double>(rotation);
    map['opacity'] = Variable<double>(opacity);
    map['color'] = Variable<int>(color);
    map['z_index'] = Variable<int>(zIndex);
    map['locked'] = Variable<bool>(locked);
    map['obscura'] = Variable<bool>(obscura);
    return map;
  }

  LayerInstancesCompanion toCompanion(bool nullToAbsent) {
    return LayerInstancesCompanion(
      id: Value(id),
      photoId: Value(photoId),
      patternId: Value(patternId),
      posX: Value(posX),
      posY: Value(posY),
      scaleX: Value(scaleX),
      scaleY: Value(scaleY),
      rotation: Value(rotation),
      opacity: Value(opacity),
      color: Value(color),
      zIndex: Value(zIndex),
      locked: Value(locked),
      obscura: Value(obscura),
    );
  }

  factory LayerInstance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LayerInstance(
      id: serializer.fromJson<int>(json['id']),
      photoId: serializer.fromJson<int>(json['photoId']),
      patternId: serializer.fromJson<int>(json['patternId']),
      posX: serializer.fromJson<double>(json['posX']),
      posY: serializer.fromJson<double>(json['posY']),
      scaleX: serializer.fromJson<double>(json['scaleX']),
      scaleY: serializer.fromJson<double>(json['scaleY']),
      rotation: serializer.fromJson<double>(json['rotation']),
      opacity: serializer.fromJson<double>(json['opacity']),
      color: serializer.fromJson<int>(json['color']),
      zIndex: serializer.fromJson<int>(json['zIndex']),
      locked: serializer.fromJson<bool>(json['locked']),
      obscura: serializer.fromJson<bool>(json['obscura']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'photoId': serializer.toJson<int>(photoId),
      'patternId': serializer.toJson<int>(patternId),
      'posX': serializer.toJson<double>(posX),
      'posY': serializer.toJson<double>(posY),
      'scaleX': serializer.toJson<double>(scaleX),
      'scaleY': serializer.toJson<double>(scaleY),
      'rotation': serializer.toJson<double>(rotation),
      'opacity': serializer.toJson<double>(opacity),
      'color': serializer.toJson<int>(color),
      'zIndex': serializer.toJson<int>(zIndex),
      'locked': serializer.toJson<bool>(locked),
      'obscura': serializer.toJson<bool>(obscura),
    };
  }

  LayerInstance copyWith({
    int? id,
    int? photoId,
    int? patternId,
    double? posX,
    double? posY,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
    int? color,
    int? zIndex,
    bool? locked,
    bool? obscura,
  }) => LayerInstance(
    id: id ?? this.id,
    photoId: photoId ?? this.photoId,
    patternId: patternId ?? this.patternId,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    zIndex: zIndex ?? this.zIndex,
    locked: locked ?? this.locked,
    obscura: obscura ?? this.obscura,
  );
  LayerInstance copyWithCompanion(LayerInstancesCompanion data) {
    return LayerInstance(
      id: data.id.present ? data.id.value : this.id,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      posX: data.posX.present ? data.posX.value : this.posX,
      posY: data.posY.present ? data.posY.value : this.posY,
      scaleX: data.scaleX.present ? data.scaleX.value : this.scaleX,
      scaleY: data.scaleY.present ? data.scaleY.value : this.scaleY,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      opacity: data.opacity.present ? data.opacity.value : this.opacity,
      color: data.color.present ? data.color.value : this.color,
      zIndex: data.zIndex.present ? data.zIndex.value : this.zIndex,
      locked: data.locked.present ? data.locked.value : this.locked,
      obscura: data.obscura.present ? data.obscura.value : this.obscura,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LayerInstance(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('patternId: $patternId, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('scaleX: $scaleX, ')
          ..write('scaleY: $scaleY, ')
          ..write('rotation: $rotation, ')
          ..write('opacity: $opacity, ')
          ..write('color: $color, ')
          ..write('zIndex: $zIndex, ')
          ..write('locked: $locked, ')
          ..write('obscura: $obscura')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    photoId,
    patternId,
    posX,
    posY,
    scaleX,
    scaleY,
    rotation,
    opacity,
    color,
    zIndex,
    locked,
    obscura,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LayerInstance &&
          other.id == this.id &&
          other.photoId == this.photoId &&
          other.patternId == this.patternId &&
          other.posX == this.posX &&
          other.posY == this.posY &&
          other.scaleX == this.scaleX &&
          other.scaleY == this.scaleY &&
          other.rotation == this.rotation &&
          other.opacity == this.opacity &&
          other.color == this.color &&
          other.zIndex == this.zIndex &&
          other.locked == this.locked &&
          other.obscura == this.obscura);
}

class LayerInstancesCompanion extends UpdateCompanion<LayerInstance> {
  final Value<int> id;
  final Value<int> photoId;
  final Value<int> patternId;
  final Value<double> posX;
  final Value<double> posY;
  final Value<double> scaleX;
  final Value<double> scaleY;
  final Value<double> rotation;
  final Value<double> opacity;
  final Value<int> color;
  final Value<int> zIndex;
  final Value<bool> locked;
  final Value<bool> obscura;
  const LayerInstancesCompanion({
    this.id = const Value.absent(),
    this.photoId = const Value.absent(),
    this.patternId = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.scaleX = const Value.absent(),
    this.scaleY = const Value.absent(),
    this.rotation = const Value.absent(),
    this.opacity = const Value.absent(),
    this.color = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.locked = const Value.absent(),
    this.obscura = const Value.absent(),
  });
  LayerInstancesCompanion.insert({
    this.id = const Value.absent(),
    required int photoId,
    required int patternId,
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.scaleX = const Value.absent(),
    this.scaleY = const Value.absent(),
    this.rotation = const Value.absent(),
    this.opacity = const Value.absent(),
    required int color,
    this.zIndex = const Value.absent(),
    this.locked = const Value.absent(),
    this.obscura = const Value.absent(),
  }) : photoId = Value(photoId),
       patternId = Value(patternId),
       color = Value(color);
  static Insertable<LayerInstance> custom({
    Expression<int>? id,
    Expression<int>? photoId,
    Expression<int>? patternId,
    Expression<double>? posX,
    Expression<double>? posY,
    Expression<double>? scaleX,
    Expression<double>? scaleY,
    Expression<double>? rotation,
    Expression<double>? opacity,
    Expression<int>? color,
    Expression<int>? zIndex,
    Expression<bool>? locked,
    Expression<bool>? obscura,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (photoId != null) 'photo_id': photoId,
      if (patternId != null) 'pattern_id': patternId,
      if (posX != null) 'pos_x': posX,
      if (posY != null) 'pos_y': posY,
      if (scaleX != null) 'scale_x': scaleX,
      if (scaleY != null) 'scale_y': scaleY,
      if (rotation != null) 'rotation': rotation,
      if (opacity != null) 'opacity': opacity,
      if (color != null) 'color': color,
      if (zIndex != null) 'z_index': zIndex,
      if (locked != null) 'locked': locked,
      if (obscura != null) 'obscura': obscura,
    });
  }

  LayerInstancesCompanion copyWith({
    Value<int>? id,
    Value<int>? photoId,
    Value<int>? patternId,
    Value<double>? posX,
    Value<double>? posY,
    Value<double>? scaleX,
    Value<double>? scaleY,
    Value<double>? rotation,
    Value<double>? opacity,
    Value<int>? color,
    Value<int>? zIndex,
    Value<bool>? locked,
    Value<bool>? obscura,
  }) {
    return LayerInstancesCompanion(
      id: id ?? this.id,
      photoId: photoId ?? this.photoId,
      patternId: patternId ?? this.patternId,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      zIndex: zIndex ?? this.zIndex,
      locked: locked ?? this.locked,
      obscura: obscura ?? this.obscura,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<int>(patternId.value);
    }
    if (posX.present) {
      map['pos_x'] = Variable<double>(posX.value);
    }
    if (posY.present) {
      map['pos_y'] = Variable<double>(posY.value);
    }
    if (scaleX.present) {
      map['scale_x'] = Variable<double>(scaleX.value);
    }
    if (scaleY.present) {
      map['scale_y'] = Variable<double>(scaleY.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (opacity.present) {
      map['opacity'] = Variable<double>(opacity.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (zIndex.present) {
      map['z_index'] = Variable<int>(zIndex.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (obscura.present) {
      map['obscura'] = Variable<bool>(obscura.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LayerInstancesCompanion(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('patternId: $patternId, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('scaleX: $scaleX, ')
          ..write('scaleY: $scaleY, ')
          ..write('rotation: $rotation, ')
          ..write('opacity: $opacity, ')
          ..write('color: $color, ')
          ..write('zIndex: $zIndex, ')
          ..write('locked: $locked, ')
          ..write('obscura: $obscura')
          ..write(')'))
        .toString();
  }
}

class $CropExportsTable extends CropExports
    with TableInfo<$CropExportsTable, CropExport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CropExportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ratioMeta = const VerificationMeta('ratio');
  @override
  late final GeneratedColumn<String> ratio = GeneratedColumn<String>(
    'ratio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orientationMeta = const VerificationMeta(
    'orientation',
  );
  @override
  late final GeneratedColumn<String> orientation = GeneratedColumn<String>(
    'orientation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rectXMeta = const VerificationMeta('rectX');
  @override
  late final GeneratedColumn<double> rectX = GeneratedColumn<double>(
    'rect_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rectYMeta = const VerificationMeta('rectY');
  @override
  late final GeneratedColumn<double> rectY = GeneratedColumn<double>(
    'rect_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rectWMeta = const VerificationMeta('rectW');
  @override
  late final GeneratedColumn<double> rectW = GeneratedColumn<double>(
    'rect_w',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rectHMeta = const VerificationMeta('rectH');
  @override
  late final GeneratedColumn<double> rectH = GeneratedColumn<double>(
    'rect_h',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportPathMeta = const VerificationMeta(
    'exportPath',
  );
  @override
  late final GeneratedColumn<String> exportPath = GeneratedColumn<String>(
    'export_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pixelWidthMeta = const VerificationMeta(
    'pixelWidth',
  );
  @override
  late final GeneratedColumn<int> pixelWidth = GeneratedColumn<int>(
    'pixel_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pixelHeightMeta = const VerificationMeta(
    'pixelHeight',
  );
  @override
  late final GeneratedColumn<int> pixelHeight = GeneratedColumn<int>(
    'pixel_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    photoId,
    ratio,
    orientation,
    rectX,
    rectY,
    rectW,
    rectH,
    exportPath,
    pixelWidth,
    pixelHeight,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crop_export';
  @override
  VerificationContext validateIntegrity(
    Insertable<CropExport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('ratio')) {
      context.handle(
        _ratioMeta,
        ratio.isAcceptableOrUnknown(data['ratio']!, _ratioMeta),
      );
    } else if (isInserting) {
      context.missing(_ratioMeta);
    }
    if (data.containsKey('orientation')) {
      context.handle(
        _orientationMeta,
        orientation.isAcceptableOrUnknown(
          data['orientation']!,
          _orientationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orientationMeta);
    }
    if (data.containsKey('rect_x')) {
      context.handle(
        _rectXMeta,
        rectX.isAcceptableOrUnknown(data['rect_x']!, _rectXMeta),
      );
    } else if (isInserting) {
      context.missing(_rectXMeta);
    }
    if (data.containsKey('rect_y')) {
      context.handle(
        _rectYMeta,
        rectY.isAcceptableOrUnknown(data['rect_y']!, _rectYMeta),
      );
    } else if (isInserting) {
      context.missing(_rectYMeta);
    }
    if (data.containsKey('rect_w')) {
      context.handle(
        _rectWMeta,
        rectW.isAcceptableOrUnknown(data['rect_w']!, _rectWMeta),
      );
    } else if (isInserting) {
      context.missing(_rectWMeta);
    }
    if (data.containsKey('rect_h')) {
      context.handle(
        _rectHMeta,
        rectH.isAcceptableOrUnknown(data['rect_h']!, _rectHMeta),
      );
    } else if (isInserting) {
      context.missing(_rectHMeta);
    }
    if (data.containsKey('export_path')) {
      context.handle(
        _exportPathMeta,
        exportPath.isAcceptableOrUnknown(data['export_path']!, _exportPathMeta),
      );
    } else if (isInserting) {
      context.missing(_exportPathMeta);
    }
    if (data.containsKey('pixel_width')) {
      context.handle(
        _pixelWidthMeta,
        pixelWidth.isAcceptableOrUnknown(data['pixel_width']!, _pixelWidthMeta),
      );
    }
    if (data.containsKey('pixel_height')) {
      context.handle(
        _pixelHeightMeta,
        pixelHeight.isAcceptableOrUnknown(
          data['pixel_height']!,
          _pixelHeightMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CropExport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CropExport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      )!,
      ratio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ratio'],
      )!,
      orientation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orientation'],
      )!,
      rectX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rect_x'],
      )!,
      rectY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rect_y'],
      )!,
      rectW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rect_w'],
      )!,
      rectH: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rect_h'],
      )!,
      exportPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}export_path'],
      )!,
      pixelWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pixel_width'],
      ),
      pixelHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pixel_height'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CropExportsTable createAlias(String alias) {
    return $CropExportsTable(attachedDatabase, alias);
  }
}

class CropExport extends DataClass implements Insertable<CropExport> {
  final int id;
  final int photoId;

  /// Nominal ratio label, e.g. `3:2` or `65:24`.
  final String ratio;

  /// `landscape` or `portrait`.
  final String orientation;
  final double rectX;
  final double rectY;
  final double rectW;
  final double rectH;

  /// Always a Mac path. Exports never land on the card.
  final String exportPath;

  /// Pixel size of the file that was written.
  ///
  /// Recorded at export rather than read back from the file: the list of
  /// exports has to be able to say what a crop actually produced without
  /// decoding a few dozen multi-megabyte JPEGs to find out, and the number is
  /// in hand at the moment the file is written. Nullable because rows written
  /// before this column existed have no honest answer.
  final int? pixelWidth;
  final int? pixelHeight;
  final DateTime createdAt;
  const CropExport({
    required this.id,
    required this.photoId,
    required this.ratio,
    required this.orientation,
    required this.rectX,
    required this.rectY,
    required this.rectW,
    required this.rectH,
    required this.exportPath,
    this.pixelWidth,
    this.pixelHeight,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['photo_id'] = Variable<int>(photoId);
    map['ratio'] = Variable<String>(ratio);
    map['orientation'] = Variable<String>(orientation);
    map['rect_x'] = Variable<double>(rectX);
    map['rect_y'] = Variable<double>(rectY);
    map['rect_w'] = Variable<double>(rectW);
    map['rect_h'] = Variable<double>(rectH);
    map['export_path'] = Variable<String>(exportPath);
    if (!nullToAbsent || pixelWidth != null) {
      map['pixel_width'] = Variable<int>(pixelWidth);
    }
    if (!nullToAbsent || pixelHeight != null) {
      map['pixel_height'] = Variable<int>(pixelHeight);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CropExportsCompanion toCompanion(bool nullToAbsent) {
    return CropExportsCompanion(
      id: Value(id),
      photoId: Value(photoId),
      ratio: Value(ratio),
      orientation: Value(orientation),
      rectX: Value(rectX),
      rectY: Value(rectY),
      rectW: Value(rectW),
      rectH: Value(rectH),
      exportPath: Value(exportPath),
      pixelWidth: pixelWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(pixelWidth),
      pixelHeight: pixelHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(pixelHeight),
      createdAt: Value(createdAt),
    );
  }

  factory CropExport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CropExport(
      id: serializer.fromJson<int>(json['id']),
      photoId: serializer.fromJson<int>(json['photoId']),
      ratio: serializer.fromJson<String>(json['ratio']),
      orientation: serializer.fromJson<String>(json['orientation']),
      rectX: serializer.fromJson<double>(json['rectX']),
      rectY: serializer.fromJson<double>(json['rectY']),
      rectW: serializer.fromJson<double>(json['rectW']),
      rectH: serializer.fromJson<double>(json['rectH']),
      exportPath: serializer.fromJson<String>(json['exportPath']),
      pixelWidth: serializer.fromJson<int?>(json['pixelWidth']),
      pixelHeight: serializer.fromJson<int?>(json['pixelHeight']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'photoId': serializer.toJson<int>(photoId),
      'ratio': serializer.toJson<String>(ratio),
      'orientation': serializer.toJson<String>(orientation),
      'rectX': serializer.toJson<double>(rectX),
      'rectY': serializer.toJson<double>(rectY),
      'rectW': serializer.toJson<double>(rectW),
      'rectH': serializer.toJson<double>(rectH),
      'exportPath': serializer.toJson<String>(exportPath),
      'pixelWidth': serializer.toJson<int?>(pixelWidth),
      'pixelHeight': serializer.toJson<int?>(pixelHeight),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CropExport copyWith({
    int? id,
    int? photoId,
    String? ratio,
    String? orientation,
    double? rectX,
    double? rectY,
    double? rectW,
    double? rectH,
    String? exportPath,
    Value<int?> pixelWidth = const Value.absent(),
    Value<int?> pixelHeight = const Value.absent(),
    DateTime? createdAt,
  }) => CropExport(
    id: id ?? this.id,
    photoId: photoId ?? this.photoId,
    ratio: ratio ?? this.ratio,
    orientation: orientation ?? this.orientation,
    rectX: rectX ?? this.rectX,
    rectY: rectY ?? this.rectY,
    rectW: rectW ?? this.rectW,
    rectH: rectH ?? this.rectH,
    exportPath: exportPath ?? this.exportPath,
    pixelWidth: pixelWidth.present ? pixelWidth.value : this.pixelWidth,
    pixelHeight: pixelHeight.present ? pixelHeight.value : this.pixelHeight,
    createdAt: createdAt ?? this.createdAt,
  );
  CropExport copyWithCompanion(CropExportsCompanion data) {
    return CropExport(
      id: data.id.present ? data.id.value : this.id,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      ratio: data.ratio.present ? data.ratio.value : this.ratio,
      orientation: data.orientation.present
          ? data.orientation.value
          : this.orientation,
      rectX: data.rectX.present ? data.rectX.value : this.rectX,
      rectY: data.rectY.present ? data.rectY.value : this.rectY,
      rectW: data.rectW.present ? data.rectW.value : this.rectW,
      rectH: data.rectH.present ? data.rectH.value : this.rectH,
      exportPath: data.exportPath.present
          ? data.exportPath.value
          : this.exportPath,
      pixelWidth: data.pixelWidth.present
          ? data.pixelWidth.value
          : this.pixelWidth,
      pixelHeight: data.pixelHeight.present
          ? data.pixelHeight.value
          : this.pixelHeight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CropExport(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('ratio: $ratio, ')
          ..write('orientation: $orientation, ')
          ..write('rectX: $rectX, ')
          ..write('rectY: $rectY, ')
          ..write('rectW: $rectW, ')
          ..write('rectH: $rectH, ')
          ..write('exportPath: $exportPath, ')
          ..write('pixelWidth: $pixelWidth, ')
          ..write('pixelHeight: $pixelHeight, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    photoId,
    ratio,
    orientation,
    rectX,
    rectY,
    rectW,
    rectH,
    exportPath,
    pixelWidth,
    pixelHeight,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CropExport &&
          other.id == this.id &&
          other.photoId == this.photoId &&
          other.ratio == this.ratio &&
          other.orientation == this.orientation &&
          other.rectX == this.rectX &&
          other.rectY == this.rectY &&
          other.rectW == this.rectW &&
          other.rectH == this.rectH &&
          other.exportPath == this.exportPath &&
          other.pixelWidth == this.pixelWidth &&
          other.pixelHeight == this.pixelHeight &&
          other.createdAt == this.createdAt);
}

class CropExportsCompanion extends UpdateCompanion<CropExport> {
  final Value<int> id;
  final Value<int> photoId;
  final Value<String> ratio;
  final Value<String> orientation;
  final Value<double> rectX;
  final Value<double> rectY;
  final Value<double> rectW;
  final Value<double> rectH;
  final Value<String> exportPath;
  final Value<int?> pixelWidth;
  final Value<int?> pixelHeight;
  final Value<DateTime> createdAt;
  const CropExportsCompanion({
    this.id = const Value.absent(),
    this.photoId = const Value.absent(),
    this.ratio = const Value.absent(),
    this.orientation = const Value.absent(),
    this.rectX = const Value.absent(),
    this.rectY = const Value.absent(),
    this.rectW = const Value.absent(),
    this.rectH = const Value.absent(),
    this.exportPath = const Value.absent(),
    this.pixelWidth = const Value.absent(),
    this.pixelHeight = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CropExportsCompanion.insert({
    this.id = const Value.absent(),
    required int photoId,
    required String ratio,
    required String orientation,
    required double rectX,
    required double rectY,
    required double rectW,
    required double rectH,
    required String exportPath,
    this.pixelWidth = const Value.absent(),
    this.pixelHeight = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : photoId = Value(photoId),
       ratio = Value(ratio),
       orientation = Value(orientation),
       rectX = Value(rectX),
       rectY = Value(rectY),
       rectW = Value(rectW),
       rectH = Value(rectH),
       exportPath = Value(exportPath);
  static Insertable<CropExport> custom({
    Expression<int>? id,
    Expression<int>? photoId,
    Expression<String>? ratio,
    Expression<String>? orientation,
    Expression<double>? rectX,
    Expression<double>? rectY,
    Expression<double>? rectW,
    Expression<double>? rectH,
    Expression<String>? exportPath,
    Expression<int>? pixelWidth,
    Expression<int>? pixelHeight,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (photoId != null) 'photo_id': photoId,
      if (ratio != null) 'ratio': ratio,
      if (orientation != null) 'orientation': orientation,
      if (rectX != null) 'rect_x': rectX,
      if (rectY != null) 'rect_y': rectY,
      if (rectW != null) 'rect_w': rectW,
      if (rectH != null) 'rect_h': rectH,
      if (exportPath != null) 'export_path': exportPath,
      if (pixelWidth != null) 'pixel_width': pixelWidth,
      if (pixelHeight != null) 'pixel_height': pixelHeight,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CropExportsCompanion copyWith({
    Value<int>? id,
    Value<int>? photoId,
    Value<String>? ratio,
    Value<String>? orientation,
    Value<double>? rectX,
    Value<double>? rectY,
    Value<double>? rectW,
    Value<double>? rectH,
    Value<String>? exportPath,
    Value<int?>? pixelWidth,
    Value<int?>? pixelHeight,
    Value<DateTime>? createdAt,
  }) {
    return CropExportsCompanion(
      id: id ?? this.id,
      photoId: photoId ?? this.photoId,
      ratio: ratio ?? this.ratio,
      orientation: orientation ?? this.orientation,
      rectX: rectX ?? this.rectX,
      rectY: rectY ?? this.rectY,
      rectW: rectW ?? this.rectW,
      rectH: rectH ?? this.rectH,
      exportPath: exportPath ?? this.exportPath,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (ratio.present) {
      map['ratio'] = Variable<String>(ratio.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(orientation.value);
    }
    if (rectX.present) {
      map['rect_x'] = Variable<double>(rectX.value);
    }
    if (rectY.present) {
      map['rect_y'] = Variable<double>(rectY.value);
    }
    if (rectW.present) {
      map['rect_w'] = Variable<double>(rectW.value);
    }
    if (rectH.present) {
      map['rect_h'] = Variable<double>(rectH.value);
    }
    if (exportPath.present) {
      map['export_path'] = Variable<String>(exportPath.value);
    }
    if (pixelWidth.present) {
      map['pixel_width'] = Variable<int>(pixelWidth.value);
    }
    if (pixelHeight.present) {
      map['pixel_height'] = Variable<int>(pixelHeight.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CropExportsCompanion(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('ratio: $ratio, ')
          ..write('orientation: $orientation, ')
          ..write('rectX: $rectX, ')
          ..write('rectY: $rectY, ')
          ..write('rectW: $rectW, ')
          ..write('rectH: $rectH, ')
          ..write('exportPath: $exportPath, ')
          ..write('pixelWidth: $pixelWidth, ')
          ..write('pixelHeight: $pixelHeight, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExportMarksTable extends ExportMarks
    with TableInfo<$ExportMarksTable, ExportMark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExportMarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, photoId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'export_mark';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExportMark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {photoId},
  ];
  @override
  ExportMark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExportMark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExportMarksTable createAlias(String alias) {
    return $ExportMarksTable(attachedDatabase, alias);
  }
}

class ExportMark extends DataClass implements Insertable<ExportMark> {
  final int id;
  final int photoId;
  final DateTime createdAt;
  const ExportMark({
    required this.id,
    required this.photoId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['photo_id'] = Variable<int>(photoId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExportMarksCompanion toCompanion(bool nullToAbsent) {
    return ExportMarksCompanion(
      id: Value(id),
      photoId: Value(photoId),
      createdAt: Value(createdAt),
    );
  }

  factory ExportMark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExportMark(
      id: serializer.fromJson<int>(json['id']),
      photoId: serializer.fromJson<int>(json['photoId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'photoId': serializer.toJson<int>(photoId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExportMark copyWith({int? id, int? photoId, DateTime? createdAt}) =>
      ExportMark(
        id: id ?? this.id,
        photoId: photoId ?? this.photoId,
        createdAt: createdAt ?? this.createdAt,
      );
  ExportMark copyWithCompanion(ExportMarksCompanion data) {
    return ExportMark(
      id: data.id.present ? data.id.value : this.id,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExportMark(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, photoId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExportMark &&
          other.id == this.id &&
          other.photoId == this.photoId &&
          other.createdAt == this.createdAt);
}

class ExportMarksCompanion extends UpdateCompanion<ExportMark> {
  final Value<int> id;
  final Value<int> photoId;
  final Value<DateTime> createdAt;
  const ExportMarksCompanion({
    this.id = const Value.absent(),
    this.photoId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExportMarksCompanion.insert({
    this.id = const Value.absent(),
    required int photoId,
    this.createdAt = const Value.absent(),
  }) : photoId = Value(photoId);
  static Insertable<ExportMark> custom({
    Expression<int>? id,
    Expression<int>? photoId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (photoId != null) 'photo_id': photoId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExportMarksCompanion copyWith({
    Value<int>? id,
    Value<int>? photoId,
    Value<DateTime>? createdAt,
  }) {
    return ExportMarksCompanion(
      id: id ?? this.id,
      photoId: photoId ?? this.photoId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExportMarksCompanion(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TrashItemsTable extends TrashItems
    with TableInfo<$TrashItemsTable, TrashItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrashItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrashFileKind, String> fileKind =
      GeneratedColumn<String>(
        'file_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TrashFileKind>($TrashItemsTable.$converterfileKind);
  static const VerificationMeta _cardRelativePathMeta = const VerificationMeta(
    'cardRelativePath',
  );
  @override
  late final GeneratedColumn<String> cardRelativePath = GeneratedColumn<String>(
    'card_relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrashState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TrashState>($TrashItemsTable.$converterstate);
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _macTrashPathMeta = const VerificationMeta(
    'macTrashPath',
  );
  @override
  late final GeneratedColumn<String> macTrashPath = GeneratedColumn<String>(
    'mac_trash_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceHashMeta = const VerificationMeta(
    'sourceHash',
  );
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
    'source_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    photoId,
    fileKind,
    cardRelativePath,
    state,
    byteSize,
    macTrashPath,
    sourceHash,
    verifiedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trash_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrashItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('card_relative_path')) {
      context.handle(
        _cardRelativePathMeta,
        cardRelativePath.isAcceptableOrUnknown(
          data['card_relative_path']!,
          _cardRelativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cardRelativePathMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('mac_trash_path')) {
      context.handle(
        _macTrashPathMeta,
        macTrashPath.isAcceptableOrUnknown(
          data['mac_trash_path']!,
          _macTrashPathMeta,
        ),
      );
    }
    if (data.containsKey('source_hash')) {
      context.handle(
        _sourceHashMeta,
        sourceHash.isAcceptableOrUnknown(data['source_hash']!, _sourceHashMeta),
      );
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {photoId, fileKind},
  ];
  @override
  TrashItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrashItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      )!,
      fileKind: $TrashItemsTable.$converterfileKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}file_kind'],
        )!,
      ),
      cardRelativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_relative_path'],
      )!,
      state: $TrashItemsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      macTrashPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac_trash_path'],
      ),
      sourceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hash'],
      ),
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TrashItemsTable createAlias(String alias) {
    return $TrashItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TrashFileKind, String, String> $converterfileKind =
      const EnumNameConverter<TrashFileKind>(TrashFileKind.values);
  static JsonTypeConverter2<TrashState, String, String> $converterstate =
      const EnumNameConverter<TrashState>(TrashState.values);
}

class TrashItem extends DataClass implements Insertable<TrashItem> {
  final int id;

  /// Cascades with the photo. The Mac-trash *bytes* are not at risk: files are
  /// never touched by a DB delete, and a Mac-trash folder with no row is
  /// re-adopted by reconciliation rather than discarded.
  final int photoId;
  final TrashFileKind fileKind;

  /// Path relative to the volume root, e.g. `DCIM/100LEICA/L1000001.DNG`.
  /// Relative because the mount point changes between sessions.
  final String cardRelativePath;

  /// Stored as text, not as an ordinal: recovery from an interrupted operation
  /// may involve reading these rows by hand, and an integer would be a riddle.
  final TrashState state;
  final int byteSize;

  /// Where the Mac-side copy lives, once there is one.
  final String? macTrashPath;

  /// Content hash of the card file, written only once a copy has actually been
  /// hashed and compared. Null means "never verified" -- the app must never
  /// unlink a card original on the strength of an unverified Mac copy.
  final String? sourceHash;

  /// When [sourceHash] was last confirmed to match the Mac copy. Null for the
  /// same reason as [sourceHash]: absence of proof, not proof of absence.
  final DateTime? verifiedAt;
  final DateTime updatedAt;
  const TrashItem({
    required this.id,
    required this.photoId,
    required this.fileKind,
    required this.cardRelativePath,
    required this.state,
    required this.byteSize,
    this.macTrashPath,
    this.sourceHash,
    this.verifiedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['photo_id'] = Variable<int>(photoId);
    {
      map['file_kind'] = Variable<String>(
        $TrashItemsTable.$converterfileKind.toSql(fileKind),
      );
    }
    map['card_relative_path'] = Variable<String>(cardRelativePath);
    {
      map['state'] = Variable<String>(
        $TrashItemsTable.$converterstate.toSql(state),
      );
    }
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || macTrashPath != null) {
      map['mac_trash_path'] = Variable<String>(macTrashPath);
    }
    if (!nullToAbsent || sourceHash != null) {
      map['source_hash'] = Variable<String>(sourceHash);
    }
    if (!nullToAbsent || verifiedAt != null) {
      map['verified_at'] = Variable<DateTime>(verifiedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrashItemsCompanion toCompanion(bool nullToAbsent) {
    return TrashItemsCompanion(
      id: Value(id),
      photoId: Value(photoId),
      fileKind: Value(fileKind),
      cardRelativePath: Value(cardRelativePath),
      state: Value(state),
      byteSize: Value(byteSize),
      macTrashPath: macTrashPath == null && nullToAbsent
          ? const Value.absent()
          : Value(macTrashPath),
      sourceHash: sourceHash == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceHash),
      verifiedAt: verifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrashItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrashItem(
      id: serializer.fromJson<int>(json['id']),
      photoId: serializer.fromJson<int>(json['photoId']),
      fileKind: $TrashItemsTable.$converterfileKind.fromJson(
        serializer.fromJson<String>(json['fileKind']),
      ),
      cardRelativePath: serializer.fromJson<String>(json['cardRelativePath']),
      state: $TrashItemsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      macTrashPath: serializer.fromJson<String?>(json['macTrashPath']),
      sourceHash: serializer.fromJson<String?>(json['sourceHash']),
      verifiedAt: serializer.fromJson<DateTime?>(json['verifiedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'photoId': serializer.toJson<int>(photoId),
      'fileKind': serializer.toJson<String>(
        $TrashItemsTable.$converterfileKind.toJson(fileKind),
      ),
      'cardRelativePath': serializer.toJson<String>(cardRelativePath),
      'state': serializer.toJson<String>(
        $TrashItemsTable.$converterstate.toJson(state),
      ),
      'byteSize': serializer.toJson<int>(byteSize),
      'macTrashPath': serializer.toJson<String?>(macTrashPath),
      'sourceHash': serializer.toJson<String?>(sourceHash),
      'verifiedAt': serializer.toJson<DateTime?>(verifiedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrashItem copyWith({
    int? id,
    int? photoId,
    TrashFileKind? fileKind,
    String? cardRelativePath,
    TrashState? state,
    int? byteSize,
    Value<String?> macTrashPath = const Value.absent(),
    Value<String?> sourceHash = const Value.absent(),
    Value<DateTime?> verifiedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => TrashItem(
    id: id ?? this.id,
    photoId: photoId ?? this.photoId,
    fileKind: fileKind ?? this.fileKind,
    cardRelativePath: cardRelativePath ?? this.cardRelativePath,
    state: state ?? this.state,
    byteSize: byteSize ?? this.byteSize,
    macTrashPath: macTrashPath.present ? macTrashPath.value : this.macTrashPath,
    sourceHash: sourceHash.present ? sourceHash.value : this.sourceHash,
    verifiedAt: verifiedAt.present ? verifiedAt.value : this.verifiedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrashItem copyWithCompanion(TrashItemsCompanion data) {
    return TrashItem(
      id: data.id.present ? data.id.value : this.id,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      fileKind: data.fileKind.present ? data.fileKind.value : this.fileKind,
      cardRelativePath: data.cardRelativePath.present
          ? data.cardRelativePath.value
          : this.cardRelativePath,
      state: data.state.present ? data.state.value : this.state,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      macTrashPath: data.macTrashPath.present
          ? data.macTrashPath.value
          : this.macTrashPath,
      sourceHash: data.sourceHash.present
          ? data.sourceHash.value
          : this.sourceHash,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrashItem(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('fileKind: $fileKind, ')
          ..write('cardRelativePath: $cardRelativePath, ')
          ..write('state: $state, ')
          ..write('byteSize: $byteSize, ')
          ..write('macTrashPath: $macTrashPath, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    photoId,
    fileKind,
    cardRelativePath,
    state,
    byteSize,
    macTrashPath,
    sourceHash,
    verifiedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrashItem &&
          other.id == this.id &&
          other.photoId == this.photoId &&
          other.fileKind == this.fileKind &&
          other.cardRelativePath == this.cardRelativePath &&
          other.state == this.state &&
          other.byteSize == this.byteSize &&
          other.macTrashPath == this.macTrashPath &&
          other.sourceHash == this.sourceHash &&
          other.verifiedAt == this.verifiedAt &&
          other.updatedAt == this.updatedAt);
}

class TrashItemsCompanion extends UpdateCompanion<TrashItem> {
  final Value<int> id;
  final Value<int> photoId;
  final Value<TrashFileKind> fileKind;
  final Value<String> cardRelativePath;
  final Value<TrashState> state;
  final Value<int> byteSize;
  final Value<String?> macTrashPath;
  final Value<String?> sourceHash;
  final Value<DateTime?> verifiedAt;
  final Value<DateTime> updatedAt;
  const TrashItemsCompanion({
    this.id = const Value.absent(),
    this.photoId = const Value.absent(),
    this.fileKind = const Value.absent(),
    this.cardRelativePath = const Value.absent(),
    this.state = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.macTrashPath = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TrashItemsCompanion.insert({
    this.id = const Value.absent(),
    required int photoId,
    required TrashFileKind fileKind,
    required String cardRelativePath,
    required TrashState state,
    this.byteSize = const Value.absent(),
    this.macTrashPath = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : photoId = Value(photoId),
       fileKind = Value(fileKind),
       cardRelativePath = Value(cardRelativePath),
       state = Value(state);
  static Insertable<TrashItem> custom({
    Expression<int>? id,
    Expression<int>? photoId,
    Expression<String>? fileKind,
    Expression<String>? cardRelativePath,
    Expression<String>? state,
    Expression<int>? byteSize,
    Expression<String>? macTrashPath,
    Expression<String>? sourceHash,
    Expression<DateTime>? verifiedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (photoId != null) 'photo_id': photoId,
      if (fileKind != null) 'file_kind': fileKind,
      if (cardRelativePath != null) 'card_relative_path': cardRelativePath,
      if (state != null) 'state': state,
      if (byteSize != null) 'byte_size': byteSize,
      if (macTrashPath != null) 'mac_trash_path': macTrashPath,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TrashItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? photoId,
    Value<TrashFileKind>? fileKind,
    Value<String>? cardRelativePath,
    Value<TrashState>? state,
    Value<int>? byteSize,
    Value<String?>? macTrashPath,
    Value<String?>? sourceHash,
    Value<DateTime?>? verifiedAt,
    Value<DateTime>? updatedAt,
  }) {
    return TrashItemsCompanion(
      id: id ?? this.id,
      photoId: photoId ?? this.photoId,
      fileKind: fileKind ?? this.fileKind,
      cardRelativePath: cardRelativePath ?? this.cardRelativePath,
      state: state ?? this.state,
      byteSize: byteSize ?? this.byteSize,
      macTrashPath: macTrashPath ?? this.macTrashPath,
      sourceHash: sourceHash ?? this.sourceHash,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (fileKind.present) {
      map['file_kind'] = Variable<String>(
        $TrashItemsTable.$converterfileKind.toSql(fileKind.value),
      );
    }
    if (cardRelativePath.present) {
      map['card_relative_path'] = Variable<String>(cardRelativePath.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $TrashItemsTable.$converterstate.toSql(state.value),
      );
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (macTrashPath.present) {
      map['mac_trash_path'] = Variable<String>(macTrashPath.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrashItemsCompanion(')
          ..write('id: $id, ')
          ..write('photoId: $photoId, ')
          ..write('fileKind: $fileKind, ')
          ..write('cardRelativePath: $cardRelativePath, ')
          ..write('state: $state, ')
          ..write('byteSize: $byteSize, ')
          ..write('macTrashPath: $macTrashPath, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ThumbCacheEntriesTable extends ThumbCacheEntries
    with TableInfo<$ThumbCacheEntriesTable, ThumbCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThumbCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cleStableMeta = const VerificationMeta(
    'cleStable',
  );
  @override
  late final GeneratedColumn<String> cleStable = GeneratedColumn<String>(
    'cle_stable',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo (cle_stable) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ThumbVariant, String> variant =
      GeneratedColumn<String>(
        'variant',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ThumbVariant>($ThumbCacheEntriesTable.$convertervariant);
  static const VerificationMeta _cachePathMeta = const VerificationMeta(
    'cachePath',
  );
  @override
  late final GeneratedColumn<String> cachePath = GeneratedColumn<String>(
    'cache_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _pixelWidthMeta = const VerificationMeta(
    'pixelWidth',
  );
  @override
  late final GeneratedColumn<int> pixelWidth = GeneratedColumn<int>(
    'pixel_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pixelHeightMeta = const VerificationMeta(
    'pixelHeight',
  );
  @override
  late final GeneratedColumn<int> pixelHeight = GeneratedColumn<int>(
    'pixel_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _averageColorMeta = const VerificationMeta(
    'averageColor',
  );
  @override
  late final GeneratedColumn<int> averageColor = GeneratedColumn<int>(
    'average_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cleStable,
    variant,
    cachePath,
    byteSize,
    createdAt,
    pixelWidth,
    pixelHeight,
    averageColor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thumb_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThumbCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cle_stable')) {
      context.handle(
        _cleStableMeta,
        cleStable.isAcceptableOrUnknown(data['cle_stable']!, _cleStableMeta),
      );
    } else if (isInserting) {
      context.missing(_cleStableMeta);
    }
    if (data.containsKey('cache_path')) {
      context.handle(
        _cachePathMeta,
        cachePath.isAcceptableOrUnknown(data['cache_path']!, _cachePathMeta),
      );
    } else if (isInserting) {
      context.missing(_cachePathMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('pixel_width')) {
      context.handle(
        _pixelWidthMeta,
        pixelWidth.isAcceptableOrUnknown(data['pixel_width']!, _pixelWidthMeta),
      );
    }
    if (data.containsKey('pixel_height')) {
      context.handle(
        _pixelHeightMeta,
        pixelHeight.isAcceptableOrUnknown(
          data['pixel_height']!,
          _pixelHeightMeta,
        ),
      );
    }
    if (data.containsKey('average_color')) {
      context.handle(
        _averageColorMeta,
        averageColor.isAcceptableOrUnknown(
          data['average_color']!,
          _averageColorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cleStable, variant},
  ];
  @override
  ThumbCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThumbCacheEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cleStable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cle_stable'],
      )!,
      variant: $ThumbCacheEntriesTable.$convertervariant.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}variant'],
        )!,
      ),
      cachePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_path'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      pixelWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pixel_width'],
      ),
      pixelHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pixel_height'],
      ),
      averageColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}average_color'],
      ),
    );
  }

  @override
  $ThumbCacheEntriesTable createAlias(String alias) {
    return $ThumbCacheEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ThumbVariant, String, String> $convertervariant =
      const EnumNameConverter<ThumbVariant>(ThumbVariant.values);
}

class ThumbCacheEntry extends DataClass implements Insertable<ThumbCacheEntry> {
  final int id;

  /// Foreign key onto the *stable key* rather than the row id, so the cascade
  /// that keeps the index free of orphans costs nothing at lookup time: the
  /// pipeline asks for a key it already holds, without joining through `photo`.
  final String cleStable;
  final ThumbVariant variant;

  /// Under application-support. Cache files are never written to the card.
  final String cachePath;
  final int byteSize;
  final DateTime createdAt;

  /// Pixel size of the cached image, so the grid can reserve a cell of the right
  /// aspect before any file is read.
  final int? pixelWidth;
  final int? pixelHeight;

  /// Mean colour of the decoded preview, ARGB in a plain int.
  ///
  /// This is the placeholder a pending cell shows (R6). It is stored on the row
  /// rather than derived from the cache file because the point of a placeholder
  /// is to be on screen *before* anything has been read from disk: one query
  /// over this table paints every pending cell in the grid.
  ///
  /// ThumbHash was the richer alternative and was not chosen. Its blurred
  /// reconstruction only helps once a photo has already been decoded, which on
  /// this app's timeline is also the moment the disk cache turns warm and the
  /// real thumbnail arrives in a few milliseconds — so it would buy a prettier
  /// placeholder exactly where no placeholder is visible.
  final int? averageColor;
  const ThumbCacheEntry({
    required this.id,
    required this.cleStable,
    required this.variant,
    required this.cachePath,
    required this.byteSize,
    required this.createdAt,
    this.pixelWidth,
    this.pixelHeight,
    this.averageColor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cle_stable'] = Variable<String>(cleStable);
    {
      map['variant'] = Variable<String>(
        $ThumbCacheEntriesTable.$convertervariant.toSql(variant),
      );
    }
    map['cache_path'] = Variable<String>(cachePath);
    map['byte_size'] = Variable<int>(byteSize);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || pixelWidth != null) {
      map['pixel_width'] = Variable<int>(pixelWidth);
    }
    if (!nullToAbsent || pixelHeight != null) {
      map['pixel_height'] = Variable<int>(pixelHeight);
    }
    if (!nullToAbsent || averageColor != null) {
      map['average_color'] = Variable<int>(averageColor);
    }
    return map;
  }

  ThumbCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return ThumbCacheEntriesCompanion(
      id: Value(id),
      cleStable: Value(cleStable),
      variant: Value(variant),
      cachePath: Value(cachePath),
      byteSize: Value(byteSize),
      createdAt: Value(createdAt),
      pixelWidth: pixelWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(pixelWidth),
      pixelHeight: pixelHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(pixelHeight),
      averageColor: averageColor == null && nullToAbsent
          ? const Value.absent()
          : Value(averageColor),
    );
  }

  factory ThumbCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThumbCacheEntry(
      id: serializer.fromJson<int>(json['id']),
      cleStable: serializer.fromJson<String>(json['cleStable']),
      variant: $ThumbCacheEntriesTable.$convertervariant.fromJson(
        serializer.fromJson<String>(json['variant']),
      ),
      cachePath: serializer.fromJson<String>(json['cachePath']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pixelWidth: serializer.fromJson<int?>(json['pixelWidth']),
      pixelHeight: serializer.fromJson<int?>(json['pixelHeight']),
      averageColor: serializer.fromJson<int?>(json['averageColor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cleStable': serializer.toJson<String>(cleStable),
      'variant': serializer.toJson<String>(
        $ThumbCacheEntriesTable.$convertervariant.toJson(variant),
      ),
      'cachePath': serializer.toJson<String>(cachePath),
      'byteSize': serializer.toJson<int>(byteSize),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pixelWidth': serializer.toJson<int?>(pixelWidth),
      'pixelHeight': serializer.toJson<int?>(pixelHeight),
      'averageColor': serializer.toJson<int?>(averageColor),
    };
  }

  ThumbCacheEntry copyWith({
    int? id,
    String? cleStable,
    ThumbVariant? variant,
    String? cachePath,
    int? byteSize,
    DateTime? createdAt,
    Value<int?> pixelWidth = const Value.absent(),
    Value<int?> pixelHeight = const Value.absent(),
    Value<int?> averageColor = const Value.absent(),
  }) => ThumbCacheEntry(
    id: id ?? this.id,
    cleStable: cleStable ?? this.cleStable,
    variant: variant ?? this.variant,
    cachePath: cachePath ?? this.cachePath,
    byteSize: byteSize ?? this.byteSize,
    createdAt: createdAt ?? this.createdAt,
    pixelWidth: pixelWidth.present ? pixelWidth.value : this.pixelWidth,
    pixelHeight: pixelHeight.present ? pixelHeight.value : this.pixelHeight,
    averageColor: averageColor.present ? averageColor.value : this.averageColor,
  );
  ThumbCacheEntry copyWithCompanion(ThumbCacheEntriesCompanion data) {
    return ThumbCacheEntry(
      id: data.id.present ? data.id.value : this.id,
      cleStable: data.cleStable.present ? data.cleStable.value : this.cleStable,
      variant: data.variant.present ? data.variant.value : this.variant,
      cachePath: data.cachePath.present ? data.cachePath.value : this.cachePath,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pixelWidth: data.pixelWidth.present
          ? data.pixelWidth.value
          : this.pixelWidth,
      pixelHeight: data.pixelHeight.present
          ? data.pixelHeight.value
          : this.pixelHeight,
      averageColor: data.averageColor.present
          ? data.averageColor.value
          : this.averageColor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThumbCacheEntry(')
          ..write('id: $id, ')
          ..write('cleStable: $cleStable, ')
          ..write('variant: $variant, ')
          ..write('cachePath: $cachePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('pixelWidth: $pixelWidth, ')
          ..write('pixelHeight: $pixelHeight, ')
          ..write('averageColor: $averageColor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cleStable,
    variant,
    cachePath,
    byteSize,
    createdAt,
    pixelWidth,
    pixelHeight,
    averageColor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThumbCacheEntry &&
          other.id == this.id &&
          other.cleStable == this.cleStable &&
          other.variant == this.variant &&
          other.cachePath == this.cachePath &&
          other.byteSize == this.byteSize &&
          other.createdAt == this.createdAt &&
          other.pixelWidth == this.pixelWidth &&
          other.pixelHeight == this.pixelHeight &&
          other.averageColor == this.averageColor);
}

class ThumbCacheEntriesCompanion extends UpdateCompanion<ThumbCacheEntry> {
  final Value<int> id;
  final Value<String> cleStable;
  final Value<ThumbVariant> variant;
  final Value<String> cachePath;
  final Value<int> byteSize;
  final Value<DateTime> createdAt;
  final Value<int?> pixelWidth;
  final Value<int?> pixelHeight;
  final Value<int?> averageColor;
  const ThumbCacheEntriesCompanion({
    this.id = const Value.absent(),
    this.cleStable = const Value.absent(),
    this.variant = const Value.absent(),
    this.cachePath = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pixelWidth = const Value.absent(),
    this.pixelHeight = const Value.absent(),
    this.averageColor = const Value.absent(),
  });
  ThumbCacheEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String cleStable,
    required ThumbVariant variant,
    required String cachePath,
    required int byteSize,
    this.createdAt = const Value.absent(),
    this.pixelWidth = const Value.absent(),
    this.pixelHeight = const Value.absent(),
    this.averageColor = const Value.absent(),
  }) : cleStable = Value(cleStable),
       variant = Value(variant),
       cachePath = Value(cachePath),
       byteSize = Value(byteSize);
  static Insertable<ThumbCacheEntry> custom({
    Expression<int>? id,
    Expression<String>? cleStable,
    Expression<String>? variant,
    Expression<String>? cachePath,
    Expression<int>? byteSize,
    Expression<DateTime>? createdAt,
    Expression<int>? pixelWidth,
    Expression<int>? pixelHeight,
    Expression<int>? averageColor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cleStable != null) 'cle_stable': cleStable,
      if (variant != null) 'variant': variant,
      if (cachePath != null) 'cache_path': cachePath,
      if (byteSize != null) 'byte_size': byteSize,
      if (createdAt != null) 'created_at': createdAt,
      if (pixelWidth != null) 'pixel_width': pixelWidth,
      if (pixelHeight != null) 'pixel_height': pixelHeight,
      if (averageColor != null) 'average_color': averageColor,
    });
  }

  ThumbCacheEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? cleStable,
    Value<ThumbVariant>? variant,
    Value<String>? cachePath,
    Value<int>? byteSize,
    Value<DateTime>? createdAt,
    Value<int?>? pixelWidth,
    Value<int?>? pixelHeight,
    Value<int?>? averageColor,
  }) {
    return ThumbCacheEntriesCompanion(
      id: id ?? this.id,
      cleStable: cleStable ?? this.cleStable,
      variant: variant ?? this.variant,
      cachePath: cachePath ?? this.cachePath,
      byteSize: byteSize ?? this.byteSize,
      createdAt: createdAt ?? this.createdAt,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      averageColor: averageColor ?? this.averageColor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cleStable.present) {
      map['cle_stable'] = Variable<String>(cleStable.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(
        $ThumbCacheEntriesTable.$convertervariant.toSql(variant.value),
      );
    }
    if (cachePath.present) {
      map['cache_path'] = Variable<String>(cachePath.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pixelWidth.present) {
      map['pixel_width'] = Variable<int>(pixelWidth.value);
    }
    if (pixelHeight.present) {
      map['pixel_height'] = Variable<int>(pixelHeight.value);
    }
    if (averageColor.present) {
      map['average_color'] = Variable<int>(averageColor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThumbCacheEntriesCompanion(')
          ..write('id: $id, ')
          ..write('cleStable: $cleStable, ')
          ..write('variant: $variant, ')
          ..write('cachePath: $cachePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('pixelWidth: $pixelWidth, ')
          ..write('pixelHeight: $pixelHeight, ')
          ..write('averageColor: $averageColor')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PatternsTable patterns = $PatternsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $LayerInstancesTable layerInstances = $LayerInstancesTable(this);
  late final $CropExportsTable cropExports = $CropExportsTable(this);
  late final $ExportMarksTable exportMarks = $ExportMarksTable(this);
  late final $TrashItemsTable trashItems = $TrashItemsTable(this);
  late final $ThumbCacheEntriesTable thumbCacheEntries =
      $ThumbCacheEntriesTable(this);
  late final CatalogDao catalogDao = CatalogDao(this as AppDatabase);
  late final CompositionDao compositionDao = CompositionDao(
    this as AppDatabase,
  );
  late final TrashDao trashDao = TrashDao(this as AppDatabase);
  late final ThumbCacheDao thumbCacheDao = ThumbCacheDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    patterns,
    photos,
    layerInstances,
    cropExports,
    exportMarks,
    trashItems,
    thumbCacheEntries,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('layer_instance', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('crop_export', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('export_mark', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trash_item', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('thumb_cache', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PatternsTableCreateCompanionBuilder =
    PatternsCompanion Function({
      Value<int> id,
      required String code,
      required String nom,
      required String categorie,
      Value<String> kind,
    });
typedef $$PatternsTableUpdateCompanionBuilder =
    PatternsCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<String> nom,
      Value<String> categorie,
      Value<String> kind,
    });

final class $$PatternsTableReferences
    extends BaseReferences<_$AppDatabase, $PatternsTable, Pattern> {
  $$PatternsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LayerInstancesTable, List<LayerInstance>>
  _layerInstancesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.layerInstances,
    aliasName: 'pattern__id__layer_instance__pattern_id',
  );

  $$LayerInstancesTableProcessedTableManager get layerInstancesRefs {
    final manager = $$LayerInstancesTableTableManager(
      $_db,
      $_db.layerInstances,
    ).filter((f) => f.patternId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_layerInstancesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PatternsTableFilterComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nom => $composableBuilder(
    column: $table.nom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categorie => $composableBuilder(
    column: $table.categorie,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> layerInstancesRefs(
    Expression<bool> Function($$LayerInstancesTableFilterComposer f) f,
  ) {
    final $$LayerInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.layerInstances,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayerInstancesTableFilterComposer(
            $db: $db,
            $table: $db.layerInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PatternsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nom => $composableBuilder(
    column: $table.nom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categorie => $composableBuilder(
    column: $table.categorie,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatternsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get nom =>
      $composableBuilder(column: $table.nom, builder: (column) => column);

  GeneratedColumn<String> get categorie =>
      $composableBuilder(column: $table.categorie, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  Expression<T> layerInstancesRefs<T extends Object>(
    Expression<T> Function($$LayerInstancesTableAnnotationComposer a) f,
  ) {
    final $$LayerInstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.layerInstances,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayerInstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.layerInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PatternsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatternsTable,
          Pattern,
          $$PatternsTableFilterComposer,
          $$PatternsTableOrderingComposer,
          $$PatternsTableAnnotationComposer,
          $$PatternsTableCreateCompanionBuilder,
          $$PatternsTableUpdateCompanionBuilder,
          (Pattern, $$PatternsTableReferences),
          Pattern,
          PrefetchHooks Function({bool layerInstancesRefs})
        > {
  $$PatternsTableTableManager(_$AppDatabase db, $PatternsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatternsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatternsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatternsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> nom = const Value.absent(),
                Value<String> categorie = const Value.absent(),
                Value<String> kind = const Value.absent(),
              }) => PatternsCompanion(
                id: id,
                code: code,
                nom: nom,
                categorie: categorie,
                kind: kind,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                required String nom,
                required String categorie,
                Value<String> kind = const Value.absent(),
              }) => PatternsCompanion.insert(
                id: id,
                code: code,
                nom: nom,
                categorie: categorie,
                kind: kind,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PatternsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({layerInstancesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (layerInstancesRefs) db.layerInstances,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (layerInstancesRefs)
                    await $_getPrefetchedData<
                      Pattern,
                      $PatternsTable,
                      LayerInstance
                    >(
                      currentTable: table,
                      referencedTable: $$PatternsTableReferences
                          ._layerInstancesRefsTable(db),
                      managerFromTypedResult: (p0) => $$PatternsTableReferences(
                        db,
                        table,
                        p0,
                      ).layerInstancesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.patternId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PatternsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatternsTable,
      Pattern,
      $$PatternsTableFilterComposer,
      $$PatternsTableOrderingComposer,
      $$PatternsTableAnnotationComposer,
      $$PatternsTableCreateCompanionBuilder,
      $$PatternsTableUpdateCompanionBuilder,
      (Pattern, $$PatternsTableReferences),
      Pattern,
      PrefetchHooks Function({bool layerInstancesRefs})
    >;
typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      Value<int> id,
      required String cleStable,
      required String radicalDcf,
      Value<DateTime?> dateOrigin,
      Value<String?> serialBoitier,
      Value<bool> dngPresent,
      Value<bool> jpgPresent,
      Value<int?> previewSmallOffset,
      Value<int?> previewSmallLength,
      Value<int?> previewFullOffset,
      Value<int?> previewFullLength,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<int> id,
      Value<String> cleStable,
      Value<String> radicalDcf,
      Value<DateTime?> dateOrigin,
      Value<String?> serialBoitier,
      Value<bool> dngPresent,
      Value<bool> jpgPresent,
      Value<int?> previewSmallOffset,
      Value<int?> previewSmallLength,
      Value<int?> previewFullOffset,
      Value<int?> previewFullLength,
    });

final class $$PhotosTableReferences
    extends BaseReferences<_$AppDatabase, $PhotosTable, Photo> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LayerInstancesTable, List<LayerInstance>>
  _layerInstancesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.layerInstances,
    aliasName: 'photo__id__layer_instance__photo_id',
  );

  $$LayerInstancesTableProcessedTableManager get layerInstancesRefs {
    final manager = $$LayerInstancesTableTableManager(
      $_db,
      $_db.layerInstances,
    ).filter((f) => f.photoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_layerInstancesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CropExportsTable, List<CropExport>>
  _cropExportsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cropExports,
    aliasName: 'photo__id__crop_export__photo_id',
  );

  $$CropExportsTableProcessedTableManager get cropExportsRefs {
    final manager = $$CropExportsTableTableManager(
      $_db,
      $_db.cropExports,
    ).filter((f) => f.photoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cropExportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExportMarksTable, List<ExportMark>>
  _exportMarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.exportMarks,
    aliasName: 'photo__id__export_mark__photo_id',
  );

  $$ExportMarksTableProcessedTableManager get exportMarksRefs {
    final manager = $$ExportMarksTableTableManager(
      $_db,
      $_db.exportMarks,
    ).filter((f) => f.photoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exportMarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrashItemsTable, List<TrashItem>>
  _trashItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trashItems,
    aliasName: 'photo__id__trash_item__photo_id',
  );

  $$TrashItemsTableProcessedTableManager get trashItemsRefs {
    final manager = $$TrashItemsTableTableManager(
      $_db,
      $_db.trashItems,
    ).filter((f) => f.photoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trashItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ThumbCacheEntriesTable, List<ThumbCacheEntry>>
  _thumbCacheEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.thumbCacheEntries,
        aliasName: 'photo__cle_stable__thumb_cache__cle_stable',
      );

  $$ThumbCacheEntriesTableProcessedTableManager get thumbCacheEntriesRefs {
    final manager =
        $$ThumbCacheEntriesTableTableManager(
          $_db,
          $_db.thumbCacheEntries,
        ).filter(
          (f) => f.cleStable.cleStable.sqlEquals(
            $_itemColumn<String>('cle_stable')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _thumbCacheEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleStable => $composableBuilder(
    column: $table.cleStable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get radicalDcf => $composableBuilder(
    column: $table.radicalDcf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateOrigin => $composableBuilder(
    column: $table.dateOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serialBoitier => $composableBuilder(
    column: $table.serialBoitier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dngPresent => $composableBuilder(
    column: $table.dngPresent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get jpgPresent => $composableBuilder(
    column: $table.jpgPresent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previewSmallOffset => $composableBuilder(
    column: $table.previewSmallOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previewSmallLength => $composableBuilder(
    column: $table.previewSmallLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previewFullOffset => $composableBuilder(
    column: $table.previewFullOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previewFullLength => $composableBuilder(
    column: $table.previewFullLength,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> layerInstancesRefs(
    Expression<bool> Function($$LayerInstancesTableFilterComposer f) f,
  ) {
    final $$LayerInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.layerInstances,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayerInstancesTableFilterComposer(
            $db: $db,
            $table: $db.layerInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cropExportsRefs(
    Expression<bool> Function($$CropExportsTableFilterComposer f) f,
  ) {
    final $$CropExportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cropExports,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CropExportsTableFilterComposer(
            $db: $db,
            $table: $db.cropExports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exportMarksRefs(
    Expression<bool> Function($$ExportMarksTableFilterComposer f) f,
  ) {
    final $$ExportMarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exportMarks,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportMarksTableFilterComposer(
            $db: $db,
            $table: $db.exportMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trashItemsRefs(
    Expression<bool> Function($$TrashItemsTableFilterComposer f) f,
  ) {
    final $$TrashItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trashItems,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrashItemsTableFilterComposer(
            $db: $db,
            $table: $db.trashItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> thumbCacheEntriesRefs(
    Expression<bool> Function($$ThumbCacheEntriesTableFilterComposer f) f,
  ) {
    final $$ThumbCacheEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cleStable,
      referencedTable: $db.thumbCacheEntries,
      getReferencedColumn: (t) => t.cleStable,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ThumbCacheEntriesTableFilterComposer(
            $db: $db,
            $table: $db.thumbCacheEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleStable => $composableBuilder(
    column: $table.cleStable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get radicalDcf => $composableBuilder(
    column: $table.radicalDcf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateOrigin => $composableBuilder(
    column: $table.dateOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serialBoitier => $composableBuilder(
    column: $table.serialBoitier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dngPresent => $composableBuilder(
    column: $table.dngPresent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get jpgPresent => $composableBuilder(
    column: $table.jpgPresent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previewSmallOffset => $composableBuilder(
    column: $table.previewSmallOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previewSmallLength => $composableBuilder(
    column: $table.previewSmallLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previewFullOffset => $composableBuilder(
    column: $table.previewFullOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previewFullLength => $composableBuilder(
    column: $table.previewFullLength,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cleStable =>
      $composableBuilder(column: $table.cleStable, builder: (column) => column);

  GeneratedColumn<String> get radicalDcf => $composableBuilder(
    column: $table.radicalDcf,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateOrigin => $composableBuilder(
    column: $table.dateOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serialBoitier => $composableBuilder(
    column: $table.serialBoitier,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dngPresent => $composableBuilder(
    column: $table.dngPresent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get jpgPresent => $composableBuilder(
    column: $table.jpgPresent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previewSmallOffset => $composableBuilder(
    column: $table.previewSmallOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previewSmallLength => $composableBuilder(
    column: $table.previewSmallLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previewFullOffset => $composableBuilder(
    column: $table.previewFullOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previewFullLength => $composableBuilder(
    column: $table.previewFullLength,
    builder: (column) => column,
  );

  Expression<T> layerInstancesRefs<T extends Object>(
    Expression<T> Function($$LayerInstancesTableAnnotationComposer a) f,
  ) {
    final $$LayerInstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.layerInstances,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayerInstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.layerInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cropExportsRefs<T extends Object>(
    Expression<T> Function($$CropExportsTableAnnotationComposer a) f,
  ) {
    final $$CropExportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cropExports,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CropExportsTableAnnotationComposer(
            $db: $db,
            $table: $db.cropExports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exportMarksRefs<T extends Object>(
    Expression<T> Function($$ExportMarksTableAnnotationComposer a) f,
  ) {
    final $$ExportMarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exportMarks,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportMarksTableAnnotationComposer(
            $db: $db,
            $table: $db.exportMarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trashItemsRefs<T extends Object>(
    Expression<T> Function($$TrashItemsTableAnnotationComposer a) f,
  ) {
    final $$TrashItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trashItems,
      getReferencedColumn: (t) => t.photoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrashItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.trashItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> thumbCacheEntriesRefs<T extends Object>(
    Expression<T> Function($$ThumbCacheEntriesTableAnnotationComposer a) f,
  ) {
    final $$ThumbCacheEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cleStable,
          referencedTable: $db.thumbCacheEntries,
          getReferencedColumn: (t) => t.cleStable,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ThumbCacheEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.thumbCacheEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          Photo,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (Photo, $$PhotosTableReferences),
          Photo,
          PrefetchHooks Function({
            bool layerInstancesRefs,
            bool cropExportsRefs,
            bool exportMarksRefs,
            bool trashItemsRefs,
            bool thumbCacheEntriesRefs,
          })
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cleStable = const Value.absent(),
                Value<String> radicalDcf = const Value.absent(),
                Value<DateTime?> dateOrigin = const Value.absent(),
                Value<String?> serialBoitier = const Value.absent(),
                Value<bool> dngPresent = const Value.absent(),
                Value<bool> jpgPresent = const Value.absent(),
                Value<int?> previewSmallOffset = const Value.absent(),
                Value<int?> previewSmallLength = const Value.absent(),
                Value<int?> previewFullOffset = const Value.absent(),
                Value<int?> previewFullLength = const Value.absent(),
              }) => PhotosCompanion(
                id: id,
                cleStable: cleStable,
                radicalDcf: radicalDcf,
                dateOrigin: dateOrigin,
                serialBoitier: serialBoitier,
                dngPresent: dngPresent,
                jpgPresent: jpgPresent,
                previewSmallOffset: previewSmallOffset,
                previewSmallLength: previewSmallLength,
                previewFullOffset: previewFullOffset,
                previewFullLength: previewFullLength,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cleStable,
                required String radicalDcf,
                Value<DateTime?> dateOrigin = const Value.absent(),
                Value<String?> serialBoitier = const Value.absent(),
                Value<bool> dngPresent = const Value.absent(),
                Value<bool> jpgPresent = const Value.absent(),
                Value<int?> previewSmallOffset = const Value.absent(),
                Value<int?> previewSmallLength = const Value.absent(),
                Value<int?> previewFullOffset = const Value.absent(),
                Value<int?> previewFullLength = const Value.absent(),
              }) => PhotosCompanion.insert(
                id: id,
                cleStable: cleStable,
                radicalDcf: radicalDcf,
                dateOrigin: dateOrigin,
                serialBoitier: serialBoitier,
                dngPresent: dngPresent,
                jpgPresent: jpgPresent,
                previewSmallOffset: previewSmallOffset,
                previewSmallLength: previewSmallLength,
                previewFullOffset: previewFullOffset,
                previewFullLength: previewFullLength,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PhotosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                layerInstancesRefs = false,
                cropExportsRefs = false,
                exportMarksRefs = false,
                trashItemsRefs = false,
                thumbCacheEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (layerInstancesRefs) db.layerInstances,
                    if (cropExportsRefs) db.cropExports,
                    if (exportMarksRefs) db.exportMarks,
                    if (trashItemsRefs) db.trashItems,
                    if (thumbCacheEntriesRefs) db.thumbCacheEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (layerInstancesRefs)
                        await $_getPrefetchedData<
                          Photo,
                          $PhotosTable,
                          LayerInstance
                        >(
                          currentTable: table,
                          referencedTable: $$PhotosTableReferences
                              ._layerInstancesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotosTableReferences(
                                db,
                                table,
                                p0,
                              ).layerInstancesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.photoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cropExportsRefs)
                        await $_getPrefetchedData<
                          Photo,
                          $PhotosTable,
                          CropExport
                        >(
                          currentTable: table,
                          referencedTable: $$PhotosTableReferences
                              ._cropExportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotosTableReferences(
                                db,
                                table,
                                p0,
                              ).cropExportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.photoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (exportMarksRefs)
                        await $_getPrefetchedData<
                          Photo,
                          $PhotosTable,
                          ExportMark
                        >(
                          currentTable: table,
                          referencedTable: $$PhotosTableReferences
                              ._exportMarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotosTableReferences(
                                db,
                                table,
                                p0,
                              ).exportMarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.photoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (trashItemsRefs)
                        await $_getPrefetchedData<
                          Photo,
                          $PhotosTable,
                          TrashItem
                        >(
                          currentTable: table,
                          referencedTable: $$PhotosTableReferences
                              ._trashItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotosTableReferences(
                                db,
                                table,
                                p0,
                              ).trashItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.photoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (thumbCacheEntriesRefs)
                        await $_getPrefetchedData<
                          Photo,
                          $PhotosTable,
                          ThumbCacheEntry
                        >(
                          currentTable: table,
                          referencedTable: $$PhotosTableReferences
                              ._thumbCacheEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotosTableReferences(
                                db,
                                table,
                                p0,
                              ).thumbCacheEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cleStable == item.cleStable,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      Photo,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (Photo, $$PhotosTableReferences),
      Photo,
      PrefetchHooks Function({
        bool layerInstancesRefs,
        bool cropExportsRefs,
        bool exportMarksRefs,
        bool trashItemsRefs,
        bool thumbCacheEntriesRefs,
      })
    >;
typedef $$LayerInstancesTableCreateCompanionBuilder =
    LayerInstancesCompanion Function({
      Value<int> id,
      required int photoId,
      required int patternId,
      Value<double> posX,
      Value<double> posY,
      Value<double> scaleX,
      Value<double> scaleY,
      Value<double> rotation,
      Value<double> opacity,
      required int color,
      Value<int> zIndex,
      Value<bool> locked,
      Value<bool> obscura,
    });
typedef $$LayerInstancesTableUpdateCompanionBuilder =
    LayerInstancesCompanion Function({
      Value<int> id,
      Value<int> photoId,
      Value<int> patternId,
      Value<double> posX,
      Value<double> posY,
      Value<double> scaleX,
      Value<double> scaleY,
      Value<double> rotation,
      Value<double> opacity,
      Value<int> color,
      Value<int> zIndex,
      Value<bool> locked,
      Value<bool> obscura,
    });

final class $$LayerInstancesTableReferences
    extends BaseReferences<_$AppDatabase, $LayerInstancesTable, LayerInstance> {
  $$LayerInstancesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhotosTable _photoIdTable(_$AppDatabase db) =>
      db.photos.createAlias('layer_instance__photo_id__photo__id');

  $$PhotosTableProcessedTableManager get photoId {
    final $_column = $_itemColumn<int>('photo_id')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_photoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PatternsTable _patternIdTable(_$AppDatabase db) =>
      db.patterns.createAlias('layer_instance__pattern_id__pattern__id');

  $$PatternsTableProcessedTableManager get patternId {
    final $_column = $_itemColumn<int>('pattern_id')!;

    final manager = $$PatternsTableTableManager(
      $_db,
      $_db.patterns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_patternIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LayerInstancesTableFilterComposer
    extends Composer<_$AppDatabase, $LayerInstancesTable> {
  $$LayerInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scaleX => $composableBuilder(
    column: $table.scaleX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scaleY => $composableBuilder(
    column: $table.scaleY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get zIndex => $composableBuilder(
    column: $table.zIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get obscura => $composableBuilder(
    column: $table.obscura,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get photoId {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableFilterComposer get patternId {
    final $$PatternsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableFilterComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LayerInstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $LayerInstancesTable> {
  $$LayerInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scaleX => $composableBuilder(
    column: $table.scaleX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scaleY => $composableBuilder(
    column: $table.scaleY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get zIndex => $composableBuilder(
    column: $table.zIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get obscura => $composableBuilder(
    column: $table.obscura,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get photoId {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableOrderingComposer get patternId {
    final $$PatternsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableOrderingComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LayerInstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LayerInstancesTable> {
  $$LayerInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get posX =>
      $composableBuilder(column: $table.posX, builder: (column) => column);

  GeneratedColumn<double> get posY =>
      $composableBuilder(column: $table.posY, builder: (column) => column);

  GeneratedColumn<double> get scaleX =>
      $composableBuilder(column: $table.scaleX, builder: (column) => column);

  GeneratedColumn<double> get scaleY =>
      $composableBuilder(column: $table.scaleY, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<double> get opacity =>
      $composableBuilder(column: $table.opacity, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get zIndex =>
      $composableBuilder(column: $table.zIndex, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<bool> get obscura =>
      $composableBuilder(column: $table.obscura, builder: (column) => column);

  $$PhotosTableAnnotationComposer get photoId {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableAnnotationComposer get patternId {
    final $$PatternsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableAnnotationComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LayerInstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LayerInstancesTable,
          LayerInstance,
          $$LayerInstancesTableFilterComposer,
          $$LayerInstancesTableOrderingComposer,
          $$LayerInstancesTableAnnotationComposer,
          $$LayerInstancesTableCreateCompanionBuilder,
          $$LayerInstancesTableUpdateCompanionBuilder,
          (LayerInstance, $$LayerInstancesTableReferences),
          LayerInstance,
          PrefetchHooks Function({bool photoId, bool patternId})
        > {
  $$LayerInstancesTableTableManager(
    _$AppDatabase db,
    $LayerInstancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LayerInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LayerInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LayerInstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> photoId = const Value.absent(),
                Value<int> patternId = const Value.absent(),
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<double> scaleX = const Value.absent(),
                Value<double> scaleY = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> zIndex = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> obscura = const Value.absent(),
              }) => LayerInstancesCompanion(
                id: id,
                photoId: photoId,
                patternId: patternId,
                posX: posX,
                posY: posY,
                scaleX: scaleX,
                scaleY: scaleY,
                rotation: rotation,
                opacity: opacity,
                color: color,
                zIndex: zIndex,
                locked: locked,
                obscura: obscura,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int photoId,
                required int patternId,
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<double> scaleX = const Value.absent(),
                Value<double> scaleY = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                required int color,
                Value<int> zIndex = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> obscura = const Value.absent(),
              }) => LayerInstancesCompanion.insert(
                id: id,
                photoId: photoId,
                patternId: patternId,
                posX: posX,
                posY: posY,
                scaleX: scaleX,
                scaleY: scaleY,
                rotation: rotation,
                opacity: opacity,
                color: color,
                zIndex: zIndex,
                locked: locked,
                obscura: obscura,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LayerInstancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({photoId = false, patternId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (photoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.photoId,
                                referencedTable: $$LayerInstancesTableReferences
                                    ._photoIdTable(db),
                                referencedColumn:
                                    $$LayerInstancesTableReferences
                                        ._photoIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (patternId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.patternId,
                                referencedTable: $$LayerInstancesTableReferences
                                    ._patternIdTable(db),
                                referencedColumn:
                                    $$LayerInstancesTableReferences
                                        ._patternIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LayerInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LayerInstancesTable,
      LayerInstance,
      $$LayerInstancesTableFilterComposer,
      $$LayerInstancesTableOrderingComposer,
      $$LayerInstancesTableAnnotationComposer,
      $$LayerInstancesTableCreateCompanionBuilder,
      $$LayerInstancesTableUpdateCompanionBuilder,
      (LayerInstance, $$LayerInstancesTableReferences),
      LayerInstance,
      PrefetchHooks Function({bool photoId, bool patternId})
    >;
typedef $$CropExportsTableCreateCompanionBuilder =
    CropExportsCompanion Function({
      Value<int> id,
      required int photoId,
      required String ratio,
      required String orientation,
      required double rectX,
      required double rectY,
      required double rectW,
      required double rectH,
      required String exportPath,
      Value<int?> pixelWidth,
      Value<int?> pixelHeight,
      Value<DateTime> createdAt,
    });
typedef $$CropExportsTableUpdateCompanionBuilder =
    CropExportsCompanion Function({
      Value<int> id,
      Value<int> photoId,
      Value<String> ratio,
      Value<String> orientation,
      Value<double> rectX,
      Value<double> rectY,
      Value<double> rectW,
      Value<double> rectH,
      Value<String> exportPath,
      Value<int?> pixelWidth,
      Value<int?> pixelHeight,
      Value<DateTime> createdAt,
    });

final class $$CropExportsTableReferences
    extends BaseReferences<_$AppDatabase, $CropExportsTable, CropExport> {
  $$CropExportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotosTable _photoIdTable(_$AppDatabase db) =>
      db.photos.createAlias('crop_export__photo_id__photo__id');

  $$PhotosTableProcessedTableManager get photoId {
    final $_column = $_itemColumn<int>('photo_id')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_photoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CropExportsTableFilterComposer
    extends Composer<_$AppDatabase, $CropExportsTable> {
  $$CropExportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rectX => $composableBuilder(
    column: $table.rectX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rectY => $composableBuilder(
    column: $table.rectY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rectW => $composableBuilder(
    column: $table.rectW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rectH => $composableBuilder(
    column: $table.rectH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportPath => $composableBuilder(
    column: $table.exportPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get photoId {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CropExportsTableOrderingComposer
    extends Composer<_$AppDatabase, $CropExportsTable> {
  $$CropExportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rectX => $composableBuilder(
    column: $table.rectX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rectY => $composableBuilder(
    column: $table.rectY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rectW => $composableBuilder(
    column: $table.rectW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rectH => $composableBuilder(
    column: $table.rectH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportPath => $composableBuilder(
    column: $table.exportPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get photoId {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CropExportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CropExportsTable> {
  $$CropExportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ratio =>
      $composableBuilder(column: $table.ratio, builder: (column) => column);

  GeneratedColumn<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rectX =>
      $composableBuilder(column: $table.rectX, builder: (column) => column);

  GeneratedColumn<double> get rectY =>
      $composableBuilder(column: $table.rectY, builder: (column) => column);

  GeneratedColumn<double> get rectW =>
      $composableBuilder(column: $table.rectW, builder: (column) => column);

  GeneratedColumn<double> get rectH =>
      $composableBuilder(column: $table.rectH, builder: (column) => column);

  GeneratedColumn<String> get exportPath => $composableBuilder(
    column: $table.exportPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PhotosTableAnnotationComposer get photoId {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CropExportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CropExportsTable,
          CropExport,
          $$CropExportsTableFilterComposer,
          $$CropExportsTableOrderingComposer,
          $$CropExportsTableAnnotationComposer,
          $$CropExportsTableCreateCompanionBuilder,
          $$CropExportsTableUpdateCompanionBuilder,
          (CropExport, $$CropExportsTableReferences),
          CropExport,
          PrefetchHooks Function({bool photoId})
        > {
  $$CropExportsTableTableManager(_$AppDatabase db, $CropExportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CropExportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CropExportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CropExportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> photoId = const Value.absent(),
                Value<String> ratio = const Value.absent(),
                Value<String> orientation = const Value.absent(),
                Value<double> rectX = const Value.absent(),
                Value<double> rectY = const Value.absent(),
                Value<double> rectW = const Value.absent(),
                Value<double> rectH = const Value.absent(),
                Value<String> exportPath = const Value.absent(),
                Value<int?> pixelWidth = const Value.absent(),
                Value<int?> pixelHeight = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CropExportsCompanion(
                id: id,
                photoId: photoId,
                ratio: ratio,
                orientation: orientation,
                rectX: rectX,
                rectY: rectY,
                rectW: rectW,
                rectH: rectH,
                exportPath: exportPath,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int photoId,
                required String ratio,
                required String orientation,
                required double rectX,
                required double rectY,
                required double rectW,
                required double rectH,
                required String exportPath,
                Value<int?> pixelWidth = const Value.absent(),
                Value<int?> pixelHeight = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CropExportsCompanion.insert(
                id: id,
                photoId: photoId,
                ratio: ratio,
                orientation: orientation,
                rectX: rectX,
                rectY: rectY,
                rectW: rectW,
                rectH: rectH,
                exportPath: exportPath,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CropExportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({photoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (photoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.photoId,
                                referencedTable: $$CropExportsTableReferences
                                    ._photoIdTable(db),
                                referencedColumn: $$CropExportsTableReferences
                                    ._photoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CropExportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CropExportsTable,
      CropExport,
      $$CropExportsTableFilterComposer,
      $$CropExportsTableOrderingComposer,
      $$CropExportsTableAnnotationComposer,
      $$CropExportsTableCreateCompanionBuilder,
      $$CropExportsTableUpdateCompanionBuilder,
      (CropExport, $$CropExportsTableReferences),
      CropExport,
      PrefetchHooks Function({bool photoId})
    >;
typedef $$ExportMarksTableCreateCompanionBuilder =
    ExportMarksCompanion Function({
      Value<int> id,
      required int photoId,
      Value<DateTime> createdAt,
    });
typedef $$ExportMarksTableUpdateCompanionBuilder =
    ExportMarksCompanion Function({
      Value<int> id,
      Value<int> photoId,
      Value<DateTime> createdAt,
    });

final class $$ExportMarksTableReferences
    extends BaseReferences<_$AppDatabase, $ExportMarksTable, ExportMark> {
  $$ExportMarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotosTable _photoIdTable(_$AppDatabase db) =>
      db.photos.createAlias('export_mark__photo_id__photo__id');

  $$PhotosTableProcessedTableManager get photoId {
    final $_column = $_itemColumn<int>('photo_id')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_photoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExportMarksTableFilterComposer
    extends Composer<_$AppDatabase, $ExportMarksTable> {
  $$ExportMarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get photoId {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportMarksTableOrderingComposer
    extends Composer<_$AppDatabase, $ExportMarksTable> {
  $$ExportMarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get photoId {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportMarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExportMarksTable> {
  $$ExportMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PhotosTableAnnotationComposer get photoId {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportMarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExportMarksTable,
          ExportMark,
          $$ExportMarksTableFilterComposer,
          $$ExportMarksTableOrderingComposer,
          $$ExportMarksTableAnnotationComposer,
          $$ExportMarksTableCreateCompanionBuilder,
          $$ExportMarksTableUpdateCompanionBuilder,
          (ExportMark, $$ExportMarksTableReferences),
          ExportMark,
          PrefetchHooks Function({bool photoId})
        > {
  $$ExportMarksTableTableManager(_$AppDatabase db, $ExportMarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExportMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExportMarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExportMarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> photoId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExportMarksCompanion(
                id: id,
                photoId: photoId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int photoId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExportMarksCompanion.insert(
                id: id,
                photoId: photoId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExportMarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({photoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (photoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.photoId,
                                referencedTable: $$ExportMarksTableReferences
                                    ._photoIdTable(db),
                                referencedColumn: $$ExportMarksTableReferences
                                    ._photoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExportMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExportMarksTable,
      ExportMark,
      $$ExportMarksTableFilterComposer,
      $$ExportMarksTableOrderingComposer,
      $$ExportMarksTableAnnotationComposer,
      $$ExportMarksTableCreateCompanionBuilder,
      $$ExportMarksTableUpdateCompanionBuilder,
      (ExportMark, $$ExportMarksTableReferences),
      ExportMark,
      PrefetchHooks Function({bool photoId})
    >;
typedef $$TrashItemsTableCreateCompanionBuilder =
    TrashItemsCompanion Function({
      Value<int> id,
      required int photoId,
      required TrashFileKind fileKind,
      required String cardRelativePath,
      required TrashState state,
      Value<int> byteSize,
      Value<String?> macTrashPath,
      Value<String?> sourceHash,
      Value<DateTime?> verifiedAt,
      Value<DateTime> updatedAt,
    });
typedef $$TrashItemsTableUpdateCompanionBuilder =
    TrashItemsCompanion Function({
      Value<int> id,
      Value<int> photoId,
      Value<TrashFileKind> fileKind,
      Value<String> cardRelativePath,
      Value<TrashState> state,
      Value<int> byteSize,
      Value<String?> macTrashPath,
      Value<String?> sourceHash,
      Value<DateTime?> verifiedAt,
      Value<DateTime> updatedAt,
    });

final class $$TrashItemsTableReferences
    extends BaseReferences<_$AppDatabase, $TrashItemsTable, TrashItem> {
  $$TrashItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotosTable _photoIdTable(_$AppDatabase db) =>
      db.photos.createAlias('trash_item__photo_id__photo__id');

  $$PhotosTableProcessedTableManager get photoId {
    final $_column = $_itemColumn<int>('photo_id')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_photoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrashItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TrashItemsTable> {
  $$TrashItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TrashFileKind, TrashFileKind, String>
  get fileKind => $composableBuilder(
    column: $table.fileKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get cardRelativePath => $composableBuilder(
    column: $table.cardRelativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TrashState, TrashState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macTrashPath => $composableBuilder(
    column: $table.macTrashPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get photoId {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrashItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrashItemsTable> {
  $$TrashItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileKind => $composableBuilder(
    column: $table.fileKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardRelativePath => $composableBuilder(
    column: $table.cardRelativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macTrashPath => $composableBuilder(
    column: $table.macTrashPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get photoId {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrashItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrashItemsTable> {
  $$TrashItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TrashFileKind, String> get fileKind =>
      $composableBuilder(column: $table.fileKind, builder: (column) => column);

  GeneratedColumn<String> get cardRelativePath => $composableBuilder(
    column: $table.cardRelativePath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TrashState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get macTrashPath => $composableBuilder(
    column: $table.macTrashPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceHash => $composableBuilder(
    column: $table.sourceHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PhotosTableAnnotationComposer get photoId {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.photoId,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrashItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrashItemsTable,
          TrashItem,
          $$TrashItemsTableFilterComposer,
          $$TrashItemsTableOrderingComposer,
          $$TrashItemsTableAnnotationComposer,
          $$TrashItemsTableCreateCompanionBuilder,
          $$TrashItemsTableUpdateCompanionBuilder,
          (TrashItem, $$TrashItemsTableReferences),
          TrashItem,
          PrefetchHooks Function({bool photoId})
        > {
  $$TrashItemsTableTableManager(_$AppDatabase db, $TrashItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrashItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrashItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrashItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> photoId = const Value.absent(),
                Value<TrashFileKind> fileKind = const Value.absent(),
                Value<String> cardRelativePath = const Value.absent(),
                Value<TrashState> state = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> macTrashPath = const Value.absent(),
                Value<String?> sourceHash = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TrashItemsCompanion(
                id: id,
                photoId: photoId,
                fileKind: fileKind,
                cardRelativePath: cardRelativePath,
                state: state,
                byteSize: byteSize,
                macTrashPath: macTrashPath,
                sourceHash: sourceHash,
                verifiedAt: verifiedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int photoId,
                required TrashFileKind fileKind,
                required String cardRelativePath,
                required TrashState state,
                Value<int> byteSize = const Value.absent(),
                Value<String?> macTrashPath = const Value.absent(),
                Value<String?> sourceHash = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TrashItemsCompanion.insert(
                id: id,
                photoId: photoId,
                fileKind: fileKind,
                cardRelativePath: cardRelativePath,
                state: state,
                byteSize: byteSize,
                macTrashPath: macTrashPath,
                sourceHash: sourceHash,
                verifiedAt: verifiedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrashItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({photoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (photoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.photoId,
                                referencedTable: $$TrashItemsTableReferences
                                    ._photoIdTable(db),
                                referencedColumn: $$TrashItemsTableReferences
                                    ._photoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrashItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrashItemsTable,
      TrashItem,
      $$TrashItemsTableFilterComposer,
      $$TrashItemsTableOrderingComposer,
      $$TrashItemsTableAnnotationComposer,
      $$TrashItemsTableCreateCompanionBuilder,
      $$TrashItemsTableUpdateCompanionBuilder,
      (TrashItem, $$TrashItemsTableReferences),
      TrashItem,
      PrefetchHooks Function({bool photoId})
    >;
typedef $$ThumbCacheEntriesTableCreateCompanionBuilder =
    ThumbCacheEntriesCompanion Function({
      Value<int> id,
      required String cleStable,
      required ThumbVariant variant,
      required String cachePath,
      required int byteSize,
      Value<DateTime> createdAt,
      Value<int?> pixelWidth,
      Value<int?> pixelHeight,
      Value<int?> averageColor,
    });
typedef $$ThumbCacheEntriesTableUpdateCompanionBuilder =
    ThumbCacheEntriesCompanion Function({
      Value<int> id,
      Value<String> cleStable,
      Value<ThumbVariant> variant,
      Value<String> cachePath,
      Value<int> byteSize,
      Value<DateTime> createdAt,
      Value<int?> pixelWidth,
      Value<int?> pixelHeight,
      Value<int?> averageColor,
    });

final class $$ThumbCacheEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ThumbCacheEntriesTable,
          ThumbCacheEntry
        > {
  $$ThumbCacheEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhotosTable _cleStableTable(_$AppDatabase db) =>
      db.photos.createAlias('thumb_cache__cle_stable__photo__cle_stable');

  $$PhotosTableProcessedTableManager get cleStable {
    final $_column = $_itemColumn<String>('cle_stable')!;

    final manager = $$PhotosTableTableManager(
      $_db,
      $_db.photos,
    ).filter((f) => f.cleStable.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cleStableTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ThumbCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ThumbCacheEntriesTable> {
  $$ThumbCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ThumbVariant, ThumbVariant, String>
  get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get cachePath => $composableBuilder(
    column: $table.cachePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get averageColor => $composableBuilder(
    column: $table.averageColor,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotosTableFilterComposer get cleStable {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cleStable,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.cleStable,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThumbCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ThumbCacheEntriesTable> {
  $$ThumbCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachePath => $composableBuilder(
    column: $table.cachePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get averageColor => $composableBuilder(
    column: $table.averageColor,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotosTableOrderingComposer get cleStable {
    final $$PhotosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cleStable,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.cleStable,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableOrderingComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThumbCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThumbCacheEntriesTable> {
  $$ThumbCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ThumbVariant, String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<String> get cachePath =>
      $composableBuilder(column: $table.cachePath, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get pixelWidth => $composableBuilder(
    column: $table.pixelWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pixelHeight => $composableBuilder(
    column: $table.pixelHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get averageColor => $composableBuilder(
    column: $table.averageColor,
    builder: (column) => column,
  );

  $$PhotosTableAnnotationComposer get cleStable {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cleStable,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.cleStable,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ThumbCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThumbCacheEntriesTable,
          ThumbCacheEntry,
          $$ThumbCacheEntriesTableFilterComposer,
          $$ThumbCacheEntriesTableOrderingComposer,
          $$ThumbCacheEntriesTableAnnotationComposer,
          $$ThumbCacheEntriesTableCreateCompanionBuilder,
          $$ThumbCacheEntriesTableUpdateCompanionBuilder,
          (ThumbCacheEntry, $$ThumbCacheEntriesTableReferences),
          ThumbCacheEntry,
          PrefetchHooks Function({bool cleStable})
        > {
  $$ThumbCacheEntriesTableTableManager(
    _$AppDatabase db,
    $ThumbCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThumbCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThumbCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThumbCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cleStable = const Value.absent(),
                Value<ThumbVariant> variant = const Value.absent(),
                Value<String> cachePath = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> pixelWidth = const Value.absent(),
                Value<int?> pixelHeight = const Value.absent(),
                Value<int?> averageColor = const Value.absent(),
              }) => ThumbCacheEntriesCompanion(
                id: id,
                cleStable: cleStable,
                variant: variant,
                cachePath: cachePath,
                byteSize: byteSize,
                createdAt: createdAt,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                averageColor: averageColor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cleStable,
                required ThumbVariant variant,
                required String cachePath,
                required int byteSize,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> pixelWidth = const Value.absent(),
                Value<int?> pixelHeight = const Value.absent(),
                Value<int?> averageColor = const Value.absent(),
              }) => ThumbCacheEntriesCompanion.insert(
                id: id,
                cleStable: cleStable,
                variant: variant,
                cachePath: cachePath,
                byteSize: byteSize,
                createdAt: createdAt,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                averageColor: averageColor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ThumbCacheEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cleStable = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cleStable) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cleStable,
                                referencedTable:
                                    $$ThumbCacheEntriesTableReferences
                                        ._cleStableTable(db),
                                referencedColumn:
                                    $$ThumbCacheEntriesTableReferences
                                        ._cleStableTable(db)
                                        .cleStable,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ThumbCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThumbCacheEntriesTable,
      ThumbCacheEntry,
      $$ThumbCacheEntriesTableFilterComposer,
      $$ThumbCacheEntriesTableOrderingComposer,
      $$ThumbCacheEntriesTableAnnotationComposer,
      $$ThumbCacheEntriesTableCreateCompanionBuilder,
      $$ThumbCacheEntriesTableUpdateCompanionBuilder,
      (ThumbCacheEntry, $$ThumbCacheEntriesTableReferences),
      ThumbCacheEntry,
      PrefetchHooks Function({bool cleStable})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PatternsTableTableManager get patterns =>
      $$PatternsTableTableManager(_db, _db.patterns);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$LayerInstancesTableTableManager get layerInstances =>
      $$LayerInstancesTableTableManager(_db, _db.layerInstances);
  $$CropExportsTableTableManager get cropExports =>
      $$CropExportsTableTableManager(_db, _db.cropExports);
  $$ExportMarksTableTableManager get exportMarks =>
      $$ExportMarksTableTableManager(_db, _db.exportMarks);
  $$TrashItemsTableTableManager get trashItems =>
      $$TrashItemsTableTableManager(_db, _db.trashItems);
  $$ThumbCacheEntriesTableTableManager get thumbCacheEntries =>
      $$ThumbCacheEntriesTableTableManager(_db, _db.thumbCacheEntries);
}
