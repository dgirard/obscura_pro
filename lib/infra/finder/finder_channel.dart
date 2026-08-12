import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What happened to a file the user asked the Finder to deal with.
///
/// Values rather than exceptions, for the reason ejecting a card uses them: a
/// file that has been moved or a Trash that refuses are ordinary outcomes on
/// someone else's Mac, and a screen has to be able to say which one happened.
enum FinderOutcome {
  done,

  /// There is nothing at that path any more.
  missing,

  /// The system refused. [FinderChannel.lastRefusal] carries what it said.
  refused,
}

/// Dart side of the Finder channel.
///
/// Two operations, both about files this app wrote to the Mac: show one, and
/// take one back. Neither ever touches the card.
class FinderChannel {
  FinderChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'obscura_pro/finder';

  final MethodChannel _channel;

  /// What the system said the last time it refused, for the interface to quote.
  String? lastRefusal;

  /// Opens a Finder window on the file's folder, with the file selected.
  Future<FinderOutcome> reveal(String path) => _call('reveal', path);

  /// Moves the file to the user's Trash — never an unlink.
  Future<FinderOutcome> moveToTrash(String path) => _call('moveToTrash', path);

  Future<FinderOutcome> _call(String method, String path) async {
    lastRefusal = null;
    try {
      final result =
          await _channel.invokeMapMethod<String, Object?>(method, {'path': path});
      final status = result?['status'] as String?;
      return switch (status) {
        'shown' || 'trashed' => FinderOutcome.done,
        'missing' => FinderOutcome.missing,
        _ => _refused(result?['message'] as String?),
      };
    } on PlatformException catch (error) {
      return _refused(error.message);
    } on MissingPluginException {
      // The channel is not there: a test, or a platform this app does not ship
      // on. Saying "refused" is the honest answer -- nothing was revealed and
      // nothing was trashed.
      return _refused('le canal Finder n\'est pas disponible');
    }
  }

  FinderOutcome _refused(String? message) {
    lastRefusal = message;
    return FinderOutcome.refused;
  }
}

/// Records what it was asked to do, and does none of it.
@visibleForTesting
class FakeFinder implements FinderChannel {
  FakeFinder({this.outcome = FinderOutcome.done});

  final FinderOutcome outcome;
  final List<String> revealed = [];
  final List<String> trashed = [];

  @override
  String? lastRefusal;

  @override
  Future<FinderOutcome> reveal(String path) async {
    revealed.add(path);
    return outcome;
  }

  @override
  Future<FinderOutcome> moveToTrash(String path) async {
    trashed.add(path);
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
