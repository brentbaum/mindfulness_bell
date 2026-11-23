import Cocoa

/// A soft full-screen color wash on every display, above full-screen apps,
/// that never takes clicks or focus.
final class FlashOverlay {
  private var windows: [NSWindow] = []

  func flash(color: NSColor, duration: TimeInterval) {
    windows.forEach { $0.orderOut(nil) }
    windows = NSScreen.screens.map { screen in
      let w = NSWindow(
        contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
      w.setFrame(screen.frame, display: false)
      w.isReleasedWhenClosed = false
      w.backgroundColor = color
      w.isOpaque = false
      w.hasShadow = false
      w.ignoresMouseEvents = true
      w.level = .screenSaver
      w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
      w.alphaValue = 0
      w.orderFrontRegardless()
      return w
    }

    // Rise quickly, fall slowly: ~1/6 in, 5/6 out (matches the original feel).
    let fadeIn = duration / 6
    let fadeOut = duration - fadeIn
    let current = windows
    NSAnimationContext.runAnimationGroup({ ctx in
      ctx.duration = fadeIn
      ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
      current.forEach { $0.animator().alphaValue = 1 }
    }, completionHandler: {
      NSAnimationContext.runAnimationGroup({ ctx in
        ctx.duration = fadeOut
        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
        current.forEach { $0.animator().alphaValue = 0 }
      }, completionHandler: { [weak self] in
        current.forEach { $0.orderOut(nil) }
        self?.windows.removeAll { w in current.contains { $0 === w } }
      })
    })
  }

  /// Parses #RRGGBBAA (or #RRGGBB).
  static func color(fromHex hex: String) -> NSColor? {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    if s.count == 6 { s += "FF" }
    guard s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
    return NSColor(
      srgbRed: CGFloat((v >> 24) & 0xFF) / 255, green: CGFloat((v >> 16) & 0xFF) / 255,
      blue: CGFloat((v >> 8) & 0xFF) / 255, alpha: CGFloat(v & 0xFF) / 255)
  }
}
