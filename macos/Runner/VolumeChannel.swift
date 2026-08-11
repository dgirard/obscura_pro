import Cocoa
import DiskArbitration
import FlutterMacOS

/// Native half of the volume channel.
///
/// None of this can be done by shelling out. A child process spawned by a
/// sandboxed app inherits the sandbox, so `diskutil` is denied its lookup of
/// `diskarbitrationd` and fails on the very operation the app depends on to make
/// card writes durable. Volume enumeration has the mirror-image problem: reading
/// `/Volumes` cannot tell a camera card from an internal disk, while the volume
/// resource keys can.
final class VolumeChannel: NSObject {
  static let methodChannelName = "obscura_pro/volumes"
  static let eventChannelName = "obscura_pro/volume_events"

  private var eventSink: FlutterEventSink?
  private let session: DASession?

  override init() {
    session = DASessionCreate(kCFAllocatorDefault)
    super.init()
    if let session {
      DASessionScheduleWithRunLoop(
        session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VolumeChannel()

    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    methods.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }

    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)

    // Held by the channels; the registrar keeps those alive for the app's life.
    objc_setAssociatedObject(
      registrar, "obscura_pro.volume_channel", instance, .OBJC_ASSOCIATION_RETAIN)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listVolumes":
      result(listVolumes())
    case "eject":
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(
          FlutterError(
            code: "bad_arguments", message: "eject requires a volume path",
            details: nil))
        return
      }
      eject(path: path, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Enumeration

  private func listVolumes() -> [[String: Any]] {
    let keys: [URLResourceKey] = [
      .volumeNameKey,
      .volumeIsRemovableKey,
      .volumeIsEjectableKey,
      .volumeIsInternalKey,
      .volumeAvailableCapacityKey,
      .volumeTotalCapacityKey,
    ]

    let urls =
      FileManager.default.mountedVolumeURLs(
        includingResourceValuesForKeys: keys,
        options: [.skipHiddenVolumes]) ?? []

    return urls.compactMap { url in
      guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
        return nil
      }
      return [
        "name": values.volumeName ?? url.lastPathComponent,
        "path": url.path,
        "isRemovable": values.volumeIsRemovable ?? false,
        "isEjectable": values.volumeIsEjectable ?? false,
        "isInternal": values.volumeIsInternal ?? false,
        // Omitted rather than zeroed when the file system reports nothing: a
        // missing capacity and a full card must not look alike.
        "freeBytes": values.volumeAvailableCapacity as Any,
        "totalBytes": values.volumeTotalCapacity as Any,
      ]
    }
  }

  // MARK: - Eject

  /// Unmounts the volume, then ejects the medium it sits on.
  ///
  /// Both steps are needed: unmounting alone leaves the card spun up in the
  /// reader, and ejecting the whole disk is what actually lets the user pull it
  /// out safely. A refusal carries the dissenter's own words back to the UI --
  /// something as ordinary as an open Finder window blocks this, and the user
  /// can only act on it if told what.
  private func eject(path: String, result: @escaping FlutterResult) {
    guard let session else {
      result(["status": "failed", "reason": "DiskArbitration indisponible"])
      return
    }

    let url = URL(fileURLWithPath: path) as CFURL
    guard let volume = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url)
    else {
      result(["status": "notFound"])
      return
    }

    // Eject acts on the medium, not the partition mounted from it.
    let medium = DADiskCopyWholeDisk(volume) ?? volume
    let request = EjectRequest(medium: medium, result: result)
    let context = Unmanaged.passRetained(request).toOpaque()

    DADiskUnmount(volume, DADiskUnmountOptions(kDADiskUnmountOptionDefault), unmountDone, context)
  }
}

// MARK: - Event stream

extension VolumeChannel: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events

    let center = NSWorkspace.shared.notificationCenter
    for (name, kind) in [
      (NSWorkspace.didMountNotification, "mounted"),
      // `willUnmount` is the last moment an operation in flight can be stopped
      // before the bytes go away, so it is reported alongside the completion.
      (NSWorkspace.willUnmountNotification, "willUnmount"),
      (NSWorkspace.didUnmountNotification, "unmounted"),
    ] {
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
        self?.eventSink?(["kind": kind, "path": url?.path ?? ""])
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    eventSink = nil
    return nil
  }
}

// MARK: - Eject callbacks

private final class EjectRequest {
  let medium: DADisk
  let result: FlutterResult

  init(medium: DADisk, result: @escaping FlutterResult) {
    self.medium = medium
    self.result = result
  }

  func finish(_ payload: [String: Any]) {
    DispatchQueue.main.async { self.result(payload) }
  }
}

/// Splits a refusal into a code the UI can branch on and the system's own words.
///
/// The dissenter string names the process holding the volume. That is the only
/// part of a refusal the user can act on, so it is passed through untouched
/// rather than being replaced by a generic message.
private func describe(_ dissenter: DADissenter) -> [String: Any] {
  let status = Int(DADissenterGetStatus(dissenter))
  let code: String
  switch status {
  case kDAReturnBusy:
    code = "busy"
  case kDAReturnNotPermitted, kDAReturnNotPrivileged:
    code = "notPermitted"
  default:
    code = "unknown"
  }

  var payload: [String: Any] = ["status": "refused", "code": code]
  if let text = DADissenterGetStatusString(dissenter) {
    payload["dissenter"] = text as String
  }
  return payload
}

private let unmountDone: DADiskUnmountCallback = { _, dissenter, context in
  guard let context else { return }
  let request = Unmanaged<EjectRequest>.fromOpaque(context).takeRetainedValue()

  if let dissenter {
    request.finish(describe(dissenter))
    return
  }

  let next = Unmanaged.passRetained(request).toOpaque()
  DADiskEject(request.medium, DADiskEjectOptions(kDADiskEjectOptionDefault), ejectDone, next)
}

private let ejectDone: DADiskEjectCallback = { _, dissenter, context in
  guard let context else { return }
  let request = Unmanaged<EjectRequest>.fromOpaque(context).takeRetainedValue()

  if let dissenter {
    // The volume is already unmounted here, so the data is safe even though the
    // medium did not spin down.
    request.finish(describe(dissenter))
    return
  }
  request.finish(["status": "ejected"])
}
