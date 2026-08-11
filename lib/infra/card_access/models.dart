import 'package:flutter/foundation.dart';

/// A volume currently mounted on the Mac.
///
/// Reported by the native side from `FileManager.mountedVolumeURLs` and its
/// resource keys rather than by listing `/Volumes`: only the resource keys can
/// tell a camera card apart from an internal disk or a network share.
@immutable
class MountedVolume {
  const MountedVolume({
    required this.name,
    required this.path,
    required this.isRemovable,
    required this.isEjectable,
    this.isInternal = false,
    this.isRoot = false,
    this.freeBytes,
    this.totalBytes,
  });

  final String name;
  final String path;

  /// The medium itself can be taken out of the reader.
  final bool isRemovable;

  /// The volume can be unmounted under software control.
  final bool isEjectable;

  /// Sits on an internal bus.
  ///
  /// Reported, but deliberately *not* used to decide what is a card. This key
  /// describes the bus, not the medium: a Mac's built-in SD reader is internal,
  /// and the card in it is the single most important volume this app will ever
  /// see. Measured on the real reader — `Protocol: Secure Digital`,
  /// `Device Location: Internal`, `Removable Media: Removable` — where filtering
  /// on this key hid the Leica card while leaving two disk images in the picker.
  final bool isInternal;

  /// The volume the system booted from.
  final bool isRoot;

  /// Null when the file system did not report a capacity, which is normal for
  /// some mounts. Distinct from zero, which would mean a full card.
  final int? freeBytes;
  final int? totalBytes;

  /// Whether this volume is worth offering as a camera card.
  ///
  /// Removable or ejectable, and not the startup disk. The test is deliberately
  /// loose — an external SSD passes it — because what actually decides is the
  /// `DCIM/` check that follows, and a picker that hides the user's card is a
  /// far worse failure than one that lists a volume they will not choose.
  bool get isCardCandidate => !isRoot && (isRemovable || isEjectable);

  factory MountedVolume.fromMap(Map<Object?, Object?> map) => MountedVolume(
        name: map['name'] as String? ?? '',
        path: map['path'] as String? ?? '',
        isRemovable: map['isRemovable'] as bool? ?? false,
        isEjectable: map['isEjectable'] as bool? ?? false,
        isInternal: map['isInternal'] as bool? ?? false,
        isRoot: map['isRoot'] as bool? ?? false,
        freeBytes: (map['freeBytes'] as num?)?.toInt(),
        totalBytes: (map['totalBytes'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is MountedVolume && other.path == path && other.name == name;

  @override
  int get hashCode => Object.hash(path, name);

  @override
  String toString() => 'MountedVolume($name at $path)';
}

/// Why a volume list changed. The catalog must react to a card leaving even
/// when the user did not ask for it -- an operation in flight has to stop.
enum VolumeEventKind { mounted, willUnmount, unmounted }

@immutable
class VolumeEvent {
  const VolumeEvent(this.kind, this.path, {this.name = ''});

  final VolumeEventKind kind;
  final String path;
  final String name;

  /// Null for a notification kind this build does not model.
  ///
  /// Unknown kinds are dropped rather than folded into a default: mapping one
  /// onto [VolumeEventKind.unmounted] would tell the app a card had been pulled
  /// when it had not, and stopping an operation on a card that is still there is
  /// exactly the false alarm this stream exists to avoid.
  static VolumeEvent? fromMap(Map<Object?, Object?> map) {
    final kind = VolumeEventKind.values
        .where((k) => k.name == map['kind'])
        .firstOrNull;
    if (kind == null) return null;
    return VolumeEvent(
      kind,
      map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }

  @override
  String toString() => 'VolumeEvent(${kind.name}, $path)';
}

/// Result of asking the system to eject a card.
///
/// Ejection is not a nicety: on a non-journaled exFAT card it is the point at
/// which pending writes are guaranteed to have landed. A refusal must therefore
/// reach the user with its reason rather than being swallowed.
sealed class EjectOutcome {
  const EjectOutcome();
}

class EjectSucceeded extends EjectOutcome {
  const EjectSucceeded(this.volumePath);
  final String volumePath;
}

/// The system declined.
///
/// [code] lets the UI react (busy is recoverable, denied is not); [message] is
/// the sentence shown to the user, and it embeds the DiskArbitration dissenter
/// text whenever there is one, because "the card is busy" is not actionable but
/// "Preview is holding it" is.
class EjectRefused extends EjectOutcome {
  const EjectRefused({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'EjectRefused($code: $message)';
}

class EjectVolumeNotFound extends EjectOutcome {
  const EjectVolumeNotFound();
}

/// Whether a chosen folder is laid out like a camera card.
sealed class CardCheck {
  const CardCheck();
}

/// `DCIM/` exists and holds at least one camera folder.
class CardAccepted extends CardCheck {
  const CardAccepted({required this.dcimPath, required this.cameraFolders});

  final String dcimPath;

  /// DCF folder names such as `100LEICA`, in the order found.
  final List<String> cameraFolders;
}

/// No `DCIM/` directory -- the user most likely picked the wrong folder.
class CardMissingDcim extends CardCheck {
  const CardMissingDcim(this.inspectedPath);
  final String inspectedPath;
}

/// `DCIM/` exists but holds no `###`-prefixed camera folder. The card is
/// readable and simply empty; this is not an error state.
class CardEmpty extends CardCheck {
  const CardEmpty(this.dcimPath);
  final String dcimPath;
}

/// Outcome of resolving a stored security-scoped bookmark.
sealed class BookmarkResolution {
  const BookmarkResolution();
}

class BookmarkResolved extends BookmarkResolution {
  const BookmarkResolved(this.path);
  final String path;
}

/// The bookmark no longer points anywhere usable -- the card was reformatted,
/// renamed, or is simply absent. The user must pick the volume again; this is
/// an ordinary outcome, not a failure.
class BookmarkStale extends BookmarkResolution {
  const BookmarkStale();
}

/// Nothing was ever stored for this key.
class BookmarkAbsent extends BookmarkResolution {
  const BookmarkAbsent();
}
