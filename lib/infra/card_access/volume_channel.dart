import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Dart side of the native volume channel.
///
/// Everything here is native rather than a shell-out on purpose. A child process
/// spawned by a sandboxed app inherits the sandbox, so `diskutil eject` is denied
/// its lookup of `diskarbitrationd` — it would fail on precisely the operation
/// the app relies on to make card writes durable. Volume enumeration has the
/// mirror-image problem: listing `/Volumes` cannot tell a camera card from an
/// internal disk, and the resource keys that can are only reachable through
/// `FileManager`.
class VolumeChannel {
  VolumeChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ?? const MethodChannel(methodChannelName),
        _events = eventChannel ?? const EventChannel(eventChannelName);

  static const methodChannelName = 'obscura_pro/volumes';
  static const eventChannelName = 'obscura_pro/volume_events';

  final MethodChannel _methods;
  final EventChannel _events;

  /// Volumes the system currently has mounted, unfiltered.
  Future<List<MountedVolume>> listVolumes() async {
    final raw = await _methods.invokeListMethod<Object?>('listVolumes') ?? const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(MountedVolume.fromMap)
        .toList(growable: false);
  }

  /// Unmounts and ejects the volume at [path].
  ///
  /// Refusal is an expected outcome, not an exception: something as ordinary as
  /// a Finder window on the card blocks it. So every failure — including a
  /// platform error — comes back as a value the UI can render, and the reason
  /// travels with it.
  Future<EjectOutcome> eject(String path) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'eject',
        {'path': path},
      );
      final status = result?['status'] as String?;
      return switch (status) {
        'ejected' => EjectSucceeded(path),
        'notFound' => const EjectVolumeNotFound(),
        'refused' => EjectRefused(
            code: result?['code'] as String? ?? 'unknown',
            message: refusalMessage(
              code: result?['code'] as String?,
              dissenter: result?['dissenter'] as String?,
            ),
          ),
        _ => EjectRefused(
            code: 'unknown',
            message: 'Réponse inattendue du système : $status',
          ),
      };
    } on PlatformException catch (e) {
      return EjectRefused(
        code: 'platform',
        message: "L'éjection a échoué : ${e.message ?? e.code}",
      );
    } on MissingPluginException {
      return const EjectRefused(
        code: 'platform',
        message: 'Le canal volumes natif est indisponible.',
      );
    }
  }

  /// Builds the sentence the user reads when the card will not eject.
  ///
  /// The dissenter text names the process holding the volume, which is the only
  /// part the user can act on, so it is appended verbatim when present. Without
  /// it the message still has to stand on its own — never trailing a bare null.
  @visibleForTesting
  static String refusalMessage({String? code, String? dissenter}) {
    final head = switch (code) {
      'busy' => 'La carte est occupée',
      'notPermitted' => "Le système a refusé l'éjection",
      _ => "L'éjection a échoué",
    };
    final detail = dissenter?.trim();
    return (detail == null || detail.isEmpty) ? '$head.' : '$head : $detail';
  }

  /// Mount and unmount notifications.
  ///
  /// `willUnmount` matters as much as `unmounted`: it is the last moment at
  /// which an operation in flight can be stopped before the bytes go away.
  Stream<VolumeEvent> watchVolumes() => _events
      .receiveBroadcastStream()
      .whereType<Map<Object?, Object?>>()
      .map(VolumeEvent.fromMap)
      .where((e) => e != null)
      .cast<VolumeEvent>();
}

extension _WhereType on Stream<dynamic> {
  Stream<T> whereType<T>() => where((e) => e is T).cast<T>();
}
