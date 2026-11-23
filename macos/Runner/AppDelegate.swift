import Cocoa
import FlutterMacOS

// AIDEV-NOTE: menu bar app (LSUIElement in Info.plist): no Dock icon, closing the
// window only hides it, and the bell timer keeps running in the Flutter engine.
// Channel contract mirrors lib/native_bridge.dart.
@main
class AppDelegate: FlutterAppDelegate {
  private static let channelName = "com.mindfulnessbell/overlay"
  private let overlay = FlashOverlay()
  private var statusBar: StatusBarController?
  private var channel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: Self.channelName, binaryMessenger: controller.engine.binaryMessenger)
    self.channel = channel
    MicrophoneMonitor.shared.initialize(channel: channel)

    let bar = StatusBarController()
    bar.onAction = { channel.invokeMethod("menuAction", arguments: ["action": $0]) }
    bar.onOpenWindow = { [weak self] in self?.showMainWindow() }
    bar.onLaunchAtLoginChanged = {
      channel.invokeMethod("launchAtLoginChanged", arguments: ["enabled": $0])
    }
    statusBar = bar

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    super.applicationDidFinishLaunching(notification)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "ping":
      result(true)
    case "showFlash":
      let duration = args["duration"] as? Double ?? 6
      let color =
        (args["color"] as? String).flatMap(FlashOverlay.color(fromHex:))
        ?? NSColor(srgbRed: 0.81, green: 0.88, blue: 0.84, alpha: 0.6)
      overlay.flash(color: color, duration: duration)
      result(true)
    case "startMicrophoneMonitoring":
      MicrophoneMonitor.shared.startMonitoring()
      result(true)
    case "stopMicrophoneMonitoring":
      MicrophoneMonitor.shared.stopMonitoring()
      result(true)
    case "getMicrophoneStatus":
      result(MicrophoneMonitor.shared.currentStatus())
    case "updateStatus":
      statusBar?.update(
        running: args["running"] as? Bool ?? false, remaining: args["remaining"] as? Int ?? 0)
      result(nil)
    case "showWindow":
      showMainWindow()
      result(nil)
    case "hideWindow":
      mainFlutterWindow?.orderOut(nil)
      result(nil)
    case "getLaunchAtLogin":
      result(LaunchAtLogin.isEnabled)
    case "setLaunchAtLogin":
      result(LaunchAtLogin.set(args["enabled"] as? Bool ?? false))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
  }

  // Reopening from Finder/Spotlight while already running shows the window.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool)
    -> Bool
  {
    showMainWindow()
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}
