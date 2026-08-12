import Cocoa
import FlutterMacOS

/// Native half of the Finder channel: showing an exported file, and taking one
/// back.
///
/// Both are native for the same reason the volume channel is. A sandboxed app's
/// child processes inherit its sandbox, so `open -R` is not an option; and an
/// export the user regrets should go to the Trash the way anything else on the
/// Mac does — recoverable, in the place they already know to look — which means
/// `FileManager.trashItem` rather than an unlink.
final class FinderChannel: NSObject {
  static let methodChannelName = "obscura_pro/finder"

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FinderChannel()
    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    methods.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    objc_setAssociatedObject(
      registrar, "obscura_pro.finder_channel", instance, .OBJC_ASSOCIATION_RETAIN)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(
        FlutterError(
          code: "bad_arguments", message: "\(call.method) requires a path",
          details: nil))
      return
    }

    switch call.method {
    case "reveal":
      result(reveal(path: path))
    case "moveToTrash":
      result(moveToTrash(path: path))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Opens a Finder window on the file's folder, with the file selected.
  ///
  /// Returns whether there was a file to show rather than throwing: an export
  /// the user has already moved is an ordinary thing to have happened, and the
  /// list says so instead of the app raising an error about it.
  private func reveal(path: String) -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      return ["status": "missing"]
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
    return ["status": "shown"]
  }

  /// Moves the file to the user's Trash.
  ///
  /// Never an unlink. This app deletes exactly one class of thing for good --
  /// the photographs the user emptied the trash on, from the card -- and an
  /// export is not that: it is a file on their Mac, and taking it away without
  /// the ordinary means of getting it back would be a promise this app does not
  /// make anywhere else.
  private func moveToTrash(path: String) -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      return ["status": "missing"]
    }
    do {
      var trashed: NSURL?
      try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
      return ["status": "trashed", "trashPath": trashed?.path ?? ""]
    } catch {
      return ["status": "refused", "message": error.localizedDescription]
    }
  }
}
