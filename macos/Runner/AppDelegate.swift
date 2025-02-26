import Cocoa
import FlutterMacOS

// There's no need to import the plugin file here as it's in the same module
// We just need to make sure it's included in the build

@main
class AppDelegate: FlutterAppDelegate {
  private var flashOverlayWindow: NSWindow?
  private static let channelName = "com.mindfulnessbell/overlay"
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("AppDelegate: applicationDidFinishLaunching")
    
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    // Set up the method channel
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: controller.engine.binaryMessenger)
    
    // Set method call handler
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      NSLog("AppDelegate: Received method call: \(call.method)")
      
      switch call.method {
      case "ping":
        NSLog("AppDelegate: Handling ping request")
        result(true)
        
      case "showFlash":
        NSLog("AppDelegate: Handling showFlash request")
        if let args = call.arguments as? [String: Any],
           let duration = args["duration"] as? Double {
          
          NSLog("AppDelegate: Flash requested with duration: \(duration)")
          
          // Parse the color if provided
          if let colorString = args["color"] as? String {
            NSLog("AppDelegate: Color provided: \(colorString)")
            
            // Basic hex color parsing
            if colorString.hasPrefix("#") && colorString.count >= 8 {
              let hexString = String(colorString.dropFirst())
              if let colorInt = UInt32(hexString, radix: 16) {
                let red = CGFloat((colorInt >> 24) & 0xFF) / 255.0
                let green = CGFloat((colorInt >> 16) & 0xFF) / 255.0
                let blue = CGFloat((colorInt >> 8) & 0xFF) / 255.0
                let alpha = CGFloat(colorInt & 0xFF) / 255.0
                
                // Update window color if it exists
                DispatchQueue.main.async {
                  self?.flashOverlayWindow?.backgroundColor = NSColor(red: red, green: green, blue: blue, alpha: alpha)
                  NSLog("AppDelegate: Updated flash color - r:\(red), g:\(green), b:\(blue), a:\(alpha)")
                }
              }
            }
          }
          
          self?.showFlashOverlay(duration: duration)
          result(true)
        } else {
          NSLog("AppDelegate: Invalid arguments for showFlash")
          result(FlutterError(code: "INVALID_ARGS", message: "Missing required parameters", details: nil))
        }
        
      case "requestPermissions":
        NSLog("AppDelegate: Handling requestPermissions request")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
          let success = NSWorkspace.shared.open(url)
          NSLog("AppDelegate: Opened system preferences, success: \(success)")
          result(success)
        } else {
          NSLog("AppDelegate: Failed to create URL for system preferences")
          result(FlutterError(code: "URL_ERROR", message: "Failed to create URL", details: nil))
        }
        
      default:
        NSLog("AppDelegate: Method not implemented: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    }
    
    // We'll register our plugin in the MainFlutterWindow.swift file
    super.applicationDidFinishLaunching(notification)
    
    NSLog("AppDelegate: Plugin registered on channel: \(Self.channelName)")
  }
  
  private func showFlashOverlay(duration: Double) {
    NSLog("AppDelegate: Creating flash overlay with duration: \(duration)")
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      // Create the overlay window if it doesn't exist
      if self.flashOverlayWindow == nil {
        guard let mainScreen = NSScreen.main else {
          NSLog("AppDelegate: Cannot get main screen")
          return
        }
        
        self.flashOverlayWindow = NSWindow(
          contentRect: mainScreen.frame,
          styleMask: .borderless,
          backing: .buffered,
          defer: false
        )
        
        guard let window = self.flashOverlayWindow else {
          NSLog("AppDelegate: Failed to create overlay window")
          return
        }
        
        // Configure window properties - match app's warm gradient
        // Use a color between the app's gradient colors (soft peach F8D6B3 and warm amber E8A87C)
        // with 60% opacity for a subtle effect
        window.backgroundColor = NSColor(red: 0.95, green: 0.85, blue: 0.75, alpha: 0.6)
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isOpaque = false
      }
      
      // Show the window
      self.flashOverlayWindow?.orderFront(nil)
      
      NSLog("AppDelegate: Showing flash overlay")
      
      // Automatically hide after the duration
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
        NSLog("AppDelegate: Hiding flash overlay after \(duration) seconds")
        self?.flashOverlayWindow?.orderOut(nil)
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
