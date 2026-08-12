import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    VolumeChannel.register(
      with: flutterViewController.registrar(forPlugin: "VolumeChannel"))
    FinderChannel.register(
      with: flutterViewController.registrar(forPlugin: "FinderChannel"))

    super.awakeFromNib()
  }
}
