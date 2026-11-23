import Cocoa
import ServiceManagement

/// The menu bar item: ripple icon, next-bell countdown, Start/Pause, Ring now,
/// open window, launch at login, quit.
final class StatusBarController: NSObject, NSMenuDelegate {
  var onAction: ((String) -> Void)?
  var onOpenWindow: (() -> Void)?
  var onLaunchAtLoginChanged: ((Bool) -> Void)?

  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let statusLine = NSMenuItem(title: "Paused", action: nil, keyEquivalent: "")
  private let toggleItem = NSMenuItem(title: "Start", action: #selector(toggle), keyEquivalent: "")
  private let loginItem = NSMenuItem(
    title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

  override init() {
    super.init()
    if let button = item.button {
      button.image = Self.rippleIcon()
      button.toolTip = "Eternal Now Doorbell"
    }
    statusLine.isEnabled = false
    let ring = NSMenuItem(title: "Ring Now", action: #selector(ringNow), keyEquivalent: "")
    let open = NSMenuItem(
      title: "Open Eternal Now…", action: #selector(openWindow), keyEquivalent: ",")
    let quit = NSMenuItem(
      title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    for i in [toggleItem, ring, open, loginItem] { i.target = self }
    [statusLine, .separator(), toggleItem, ring, .separator(), open, loginItem, .separator(), quit]
      .forEach(menu.addItem)
    menu.delegate = self
    item.menu = menu
    update(running: false, remaining: 0)
  }

  func update(running: Bool, remaining: Int) {
    statusLine.title =
      running ? "Next bell in \(remaining / 60):\(String(format: "%02d", remaining % 60))" : "Paused"
    toggleItem.title = running ? "Pause" : "Start"
    item.button?.appearsDisabled = !running
  }

  func menuWillOpen(_ menu: NSMenu) {
    loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
  }

  @objc private func toggle() { onAction?("toggle") }
  @objc private func ringNow() { onAction?("ringNow") }
  @objc private func openWindow() { onOpenWindow?() }
  @objc private func toggleLogin() {
    let enabled = LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    loginItem.state = enabled ? .on : .off
    onLaunchAtLoginChanged?(enabled)
  }

  /// 18pt template image of the ripple mark; macOS tints it for light/dark menu bars.
  static func rippleIcon() -> NSImage {
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
      let c = NSPoint(x: rect.midX, y: rect.midY)
      func ring(_ r: CGFloat, _ w: CGFloat, _ a: CGFloat) {
        let p = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.lineWidth = w
        NSColor.black.withAlphaComponent(a).setStroke()
        p.stroke()
      }
      ring(7.75, 1.1, 0.45)
      ring(4.75, 1.4, 0.8)
      NSColor.black.setFill()
      NSBezierPath(ovalIn: NSRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)).fill()
      return true
    }
    img.isTemplate = true
    return img
  }
}

/// Launch at login via SMAppService (macOS 13+). No-op on older systems.
enum LaunchAtLogin {
  static var isEnabled: Bool {
    if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
    return false
  }

  /// Returns the resulting state.
  @discardableResult
  static func set(_ enabled: Bool) -> Bool {
    if #available(macOS 13.0, *) {
      do {
        if enabled { try SMAppService.mainApp.register() } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        NSLog("LaunchAtLogin: \(error.localizedDescription)")
      }
    }
    return isEnabled
  }
}
