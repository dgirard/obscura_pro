import 'package:drift/drift.dart';

/// Which of an entity's two files a trash row tracks.
///
/// One photo entity on a Q3 card is a `.DNG` plus a `.JPG` sharing a DCF
/// radical, but the card operations that move them are two distinct unlinks.
enum TrashFileKind { dng, jpg }

/// The deletion state machine (KTD-14), including the in-flight intent states.
///
/// The intents (`movingToMacTrash`, `restoringToCard`, `deleting`) are states in
/// their own right and not transient flags: they are committed *before* the card
/// operation runs, so a crash mid-operation leaves a row that startup
/// reconciliation can resolve by observing the files.
enum TrashState {
  onCard,
  marked,
  movingToMacTrash,
  movedToMacTrash,
  restoringToCard,
  deleting,
  deleted,
  uncertain,
}

/// Thumbnail size class. `small` feeds the grid, `full` the viewer.
enum ThumbVariant { small, full }

/// The composition-pattern library ("Grammaire du cadre").
///
/// Patterns are reference data seeded from the generated catalog, not user
/// content; [code] is the seed's identity across re-seeds.
///
/// The spec's `svg` and `aspect_ratio` columns are gone (schema v3), and their
/// absence is the finding of U12. The Grammaire's inline SVGs are teaching
/// diagrams rather than overlay assets, so a guide's geometry is *built* from
/// the frame it lands on — `layers/patterns/constructions.dart` — and five of
/// the fifteen change shape with that frame. A stored path would have been a
/// 3:2 shape stretched onto an XPan, and a stored reference ratio would have
/// been the excuse for stretching it.
class Patterns extends Table {
  @override
  String get tableName => 'pattern';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get nom => text()();
  TextColumn get categorie => text()();

  /// `guide` for the fifteen that can be laid over a photograph, `reference`
  /// for the fifteen that are a card to read. Stored as text for the same
  /// reason [TrashItems.state] is: these rows get read by hand.
  TextColumn get kind => text().withDefault(const Constant('guide'))();
}

/// Photos known to the app, keyed by stable identity rather than by path.
///
/// A card can be remounted at a different mount point, so the absolute path is
/// not an identity; [cleStable] is (see CLE-PHOTO in the spec).
class Photos extends Table {
  @override
  String get tableName => 'photo';

  IntColumn get id => integer().autoIncrement()();

  /// Hash of radical + DateTimeOriginal + body serial (+ size/mtime fallback).
  /// Unique because two rows for one file would let the app delete a card file
  /// while another row still claims it is on the card.
  TextColumn get cleStable => text().unique()();

  /// DCF radical, e.g. `100LEICA/L1000001` -- folder plus 8.3 stem, without the
  /// extension, since the two files of one entity share it.
  TextColumn get radicalDcf => text()();

  /// EXIF DateTimeOriginal. The camera records no timezone, so this is a
  /// wall-clock instant and must not be shifted when displayed.
  DateTimeColumn get dateOrigin => dateTime().nullable()();

  TextColumn get serialBoitier => text().nullable()();

  BoolColumn get dngPresent => boolean().withDefault(const Constant(false))();
  BoolColumn get jpgPresent => boolean().withDefault(const Constant(false))();

  /// Byte range of the embedded grid preview inside the DNG.
  ///
  /// Cached here so decode workers never walk the IFD chain twice; the JPG
  /// sibling needs no offsets because the file is itself a decodable frame.
  /// Null until the header parser has run.
  IntColumn get previewSmallOffset => integer().nullable()();
  IntColumn get previewSmallLength => integer().nullable()();

  /// Byte range of the embedded full-size preview used by the viewer.
  IntColumn get previewFullOffset => integer().nullable()();
  IntColumn get previewFullLength => integer().nullable()();
}

/// A composition pattern placed on a photo.
///
/// Geometry is normalized 0..1 against the frame (KTD-6): the same row must
/// render identically in the grid, the viewer, and an export of any pixel size.
class LayerInstances extends Table {
  @override
  String get tableName => 'layer_instance';

  IntColumn get id => integer().autoIncrement()();

  /// Cascades: a layer describes a photo and means nothing without it.
  IntColumn get photoId => integer().references(Photos, #id, onDelete: KeyAction.cascade)();

  /// Restricted, not cascading: deleting a pattern still in use would silently
  /// erase the user's composition instead of refusing an unsafe edit.
  IntColumn get patternId =>
      integer().references(Patterns, #id, onDelete: KeyAction.restrict)();

  RealColumn get posX => real().withDefault(const Constant(0.5))();
  RealColumn get posY => real().withDefault(const Constant(0.5))();
  RealColumn get scaleX => real().withDefault(const Constant(1))();
  RealColumn get scaleY => real().withDefault(const Constant(1))();

  /// Radians, clockwise from the frame's horizontal.
  RealColumn get rotation => real().withDefault(const Constant(0))();

  RealColumn get opacity => real().withDefault(const Constant(1))();

  /// ARGB, stored as a plain int so it does not depend on a Flutter type.
  IntColumn get color => integer()();

  IntColumn get zIndex => integer().withDefault(const Constant(0))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  /// Whether the layer was placed in obscura mode; kept so the placement can be
  /// re-read in the same perceptual context it was judged in.
  BoolColumn get obscura => boolean().withDefault(const Constant(false))();
}

/// Photographs the user has decided to export.
///
/// The other half of culling. `trash_item` records the frames that are going;
/// this records the frames that are wanted, and it is a decision made in the
/// same pass, with the same keyboard, about the same photograph — so it is kept
/// the same way: on the Mac, keyed by the photo, written the moment it is made.
///
/// A row is a queue entry rather than a permanent attribute: it is removed when
/// the file has been written, and what is left afterwards is the `crop_export`
/// row and the file itself.
class ExportMarks extends Table {
  @override
  String get tableName => 'export_mark';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get photoId =>
      integer().references(Photos, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// One mark per photograph: marking twice is the same decision.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {photoId},
      ];
}

/// Traceability of a non-destructive export.
///
/// The card file is never modified: the crop lives here and the pixels are
/// written to [exportPath] on the Mac.
class CropExports extends Table {
  @override
  String get tableName => 'crop_export';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get photoId => integer().references(Photos, #id, onDelete: KeyAction.cascade)();

  /// Nominal ratio label, e.g. `3:2` or `65:24`.
  TextColumn get ratio => text()();

  /// `landscape` or `portrait`.
  TextColumn get orientation => text()();

  RealColumn get rectX => real()();
  RealColumn get rectY => real()();
  RealColumn get rectW => real()();
  RealColumn get rectH => real()();

  /// Always a Mac path. Exports never land on the card.
  TextColumn get exportPath => text()();

  /// Pixel size of the file that was written.
  ///
  /// Recorded at export rather than read back from the file: the list of
  /// exports has to be able to say what a crop actually produced without
  /// decoding a few dozen multi-megabyte JPEGs to find out, and the number is
  /// in hand at the moment the file is written. Nullable because rows written
  /// before this column existed have no honest answer.
  IntColumn get pixelWidth => integer().nullable()();
  IntColumn get pixelHeight => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One row per *file* in the deletion state machine (KTD-14).
///
/// Per file, not per entity: a crash between the two unlinks of one photo can
/// leave the DNG deleted and the JPG still on the card, and a per-entity row
/// could not express that.
class TrashItems extends Table {
  @override
  String get tableName => 'trash_item';

  IntColumn get id => integer().autoIncrement()();

  /// Cascades with the photo. The Mac-trash *bytes* are not at risk: files are
  /// never touched by a DB delete, and a Mac-trash folder with no row is
  /// re-adopted by reconciliation rather than discarded.
  IntColumn get photoId => integer().references(Photos, #id, onDelete: KeyAction.cascade)();

  TextColumn get fileKind => textEnum<TrashFileKind>()();

  /// Path relative to the volume root, e.g. `DCIM/100LEICA/L1000001.DNG`.
  /// Relative because the mount point changes between sessions.
  TextColumn get cardRelativePath => text()();

  /// Stored as text, not as an ordinal: recovery from an interrupted operation
  /// may involve reading these rows by hand, and an integer would be a riddle.
  TextColumn get state => textEnum<TrashState>()();

  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// Where the Mac-side copy lives, once there is one.
  TextColumn get macTrashPath => text().nullable()();

  /// Content hash of the card file, written only once a copy has actually been
  /// hashed and compared. Null means "never verified" -- the app must never
  /// unlink a card original on the strength of an unverified Mac copy.
  TextColumn get sourceHash => text().nullable()();

  /// When [sourceHash] was last confirmed to match the Mac copy. Null for the
  /// same reason as [sourceHash]: absence of proof, not proof of absence.
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// One row per file of an entity, so an intent cannot be recorded twice.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {photoId, fileKind},
  ];
}

/// Index of decoded thumbnails cached on the Mac.
///
/// Rows are keyed by the stable key rather than by the photo row id because the
/// cache files on disk are named by it and outlive any given DB row.
class ThumbCacheEntries extends Table {
  @override
  String get tableName => 'thumb_cache';

  IntColumn get id => integer().autoIncrement()();

  /// Foreign key onto the *stable key* rather than the row id, so the cascade
  /// that keeps the index free of orphans costs nothing at lookup time: the
  /// pipeline asks for a key it already holds, without joining through `photo`.
  TextColumn get cleStable =>
      text().references(Photos, #cleStable, onDelete: KeyAction.cascade)();

  TextColumn get variant => textEnum<ThumbVariant>()();

  /// Under application-support. Cache files are never written to the card.
  TextColumn get cachePath => text()();

  IntColumn get byteSize => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Pixel size of the cached image, so the grid can reserve a cell of the right
  /// aspect before any file is read.
  IntColumn get pixelWidth => integer().nullable()();
  IntColumn get pixelHeight => integer().nullable()();

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
  IntColumn get averageColor => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {cleStable, variant},
  ];
}
