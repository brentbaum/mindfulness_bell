import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Stillwater chrome: content runs under a transparent title bar.
    title = "Eternal Now Doorbell"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    styleMask.remove(.resizable)
    backgroundColor = NSColor(srgbRed: 0xF4 / 255, green: 0xF7 / 255, blue: 0xF5 / 255, alpha: 1)
    isReleasedWhenClosed = false
    setContentSize(NSSize(width: 420, height: 700))
    center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}
