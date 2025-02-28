import Cocoa
import FlutterMacOS
import CoreAudio
import AVFoundation

// MicrophoneMonitor: A class to detect if the microphone is being used by any application
class MicrophoneMonitor {
    // Singleton instance
    static let shared = MicrophoneMonitor()
    
    // Flutter method channel for communication
    private var methodChannel: FlutterMethodChannel?
    
    // Polling timer to check microphone status
    private var pollingTimer: Timer?
    
    // Track if microphone is in use
    private var isMicrophoneInUse = false
    
    // Default microphone device ID
    private var defaultInputDeviceID: AudioDeviceID = 0
    
    // Initialize with method channel
    func initialize(methodChannel: FlutterMethodChannel) {
        NSLog("MicrophoneMonitor: Initializing")
        self.methodChannel = methodChannel
        
        // Find the default input device (microphone)
        updateDefaultInputDevice()
    }
    
    // Start monitoring microphone usage
    func startMonitoring() {
        NSLog("MicrophoneMonitor: Starting microphone monitoring")
        
        // Stop any existing timer
        stopMonitoring()
        
        // Set up a timer to check microphone status every 1 second
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMicrophoneStatus()
        }
        
        // Make timer work even when scrolling or performing other UI actions
        if let timer = pollingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        NSLog("MicrophoneMonitor: Monitoring started with timer: \(String(describing: pollingTimer))")
    }
    
    // Stop monitoring microphone usage
    func stopMonitoring() {
        NSLog("MicrophoneMonitor: Stopping microphone monitoring")
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // Update the default input device
    private func updateDefaultInputDevice() {
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultInputDeviceID
        )
        
        if status != noErr {
            NSLog("MicrophoneMonitor: Error getting default input device: \(status)")
        } else {
            NSLog("MicrophoneMonitor: Default input device ID: \(defaultInputDeviceID)")
        }
    }
    
    // Check if the microphone is currently in use by any app
    private func checkMicrophoneStatus() {
        // Make sure we have a valid device ID
        if defaultInputDeviceID == 0 {
            updateDefaultInputDevice()
            if defaultInputDeviceID == 0 {
                NSLog("MicrophoneMonitor: No valid input device found")
                return
            }
        }
        
        // Get the current device's input stream
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get the size of the property
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            defaultInputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        if status != noErr {
            NSLog("MicrophoneMonitor: Error getting property size: \(status)")
            return
        }
        
        // Get input stream configuration 
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propertySize))
        defer { bufferList.deallocate() }
        
        status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferList
        )
        
        if status != noErr {
            NSLog("MicrophoneMonitor: Error getting stream configuration: \(status)")
            return
        }
        
        // Check if device is active (has running streams)
        var isActive: UInt32 = 0
        propertySize = UInt32(MemoryLayout<UInt32>.size)
        propertyAddress.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        
        status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &isActive
        )
        
        if status != noErr {
            NSLog("MicrophoneMonitor: Error checking if device is active: \(status)")
            return
        }
        
        // Check if device is actually capturing audio
        let newMicrophoneInUse = isActive != 0
        
        // Only notify Flutter if the status has changed
        if newMicrophoneInUse != isMicrophoneInUse {
            isMicrophoneInUse = newMicrophoneInUse
            NSLog("MicrophoneMonitor: Microphone status changed - In use: \(isMicrophoneInUse)")
            
            // Notify Flutter through method channel
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let channel = self.methodChannel else { return }
                
                channel.invokeMethod("microphoneStatusChanged", arguments: ["isInUse": self.isMicrophoneInUse])
                NSLog("MicrophoneMonitor: Notified Flutter of microphone status: \(self.isMicrophoneInUse)")
            }
        }
    }
    
    // Check microphone status once and return result
    func getCurrentMicrophoneStatus() -> Bool {
        checkMicrophoneStatus()
        return isMicrophoneInUse
    }
}

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
    
    // Initialize the microphone monitor
    MicrophoneMonitor.shared.initialize(methodChannel: channel)
    
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
        
      // New microphone monitoring methods
      case "startMicrophoneMonitoring":
        NSLog("AppDelegate: Handling startMicrophoneMonitoring request")
        MicrophoneMonitor.shared.startMonitoring()
        result(true)
        
      case "stopMicrophoneMonitoring":
        NSLog("AppDelegate: Handling stopMicrophoneMonitoring request")
        MicrophoneMonitor.shared.stopMonitoring()
        result(true)
        
      case "getMicrophoneStatus":
        NSLog("AppDelegate: Handling getMicrophoneStatus request")
        let isInUse = MicrophoneMonitor.shared.getCurrentMicrophoneStatus()
        NSLog("AppDelegate: Current microphone status: \(isInUse)")
        result(isInUse)
        
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
      
      // Show the window and reset opacity to initial value
      guard let window = self.flashOverlayWindow else { return }
      
      // Get the current color and its components
      if let currentColor = window.backgroundColor {
        let red = currentColor.redComponent
        let green = currentColor.greenComponent
        let blue = currentColor.blueComponent
        let initialAlpha = currentColor.alphaComponent
        
        // Show the window with initial opacity
        window.orderFront(nil)
        NSLog("AppDelegate: Showing flash overlay with initial alpha: \(initialAlpha)")
        
        // Set up animation parameters
        let fadeTime: TimeInterval = 3.0 // 5 seconds fade duration
        let totalSteps = 40 // 40 steps for smooth animation (about 13 updates per second)
        let stepDuration = fadeTime / Double(totalSteps)
        
        // Start the fade animation
        var currentStep = 0
        
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
          currentStep += 1
          
          // Calculate current progress (0.0 to 1.0)
          let progress = Double(currentStep) / Double(totalSteps)
          
          // Apply ease-out curve: cubic ease-out function
          // This will decrease opacity quickly at first, then slow down
          // We'll use the cubic ease-out function: f(t) = 1 - (1-t)^3
          let easeOutProgress = 1.0 - pow(1.0 - progress, 3)
          
          // Calculate new alpha based on ease-out curve
          let newAlpha = initialAlpha * (1.0 - easeOutProgress)
          
          // Update window color with new alpha
          window.backgroundColor = NSColor(red: red, green: green, blue: blue, alpha: newAlpha)
          
          NSLog("AppDelegate: Fading - step \(currentStep)/\(totalSteps), progress: \(progress), eased: \(easeOutProgress), alpha: \(newAlpha)")
          
          // Check if we've reached the end of the animation
          if currentStep >= totalSteps || newAlpha <= 0.01 {
            timer.invalidate()
            
            // Ensure we end at exactly 0 opacity
            window.backgroundColor = NSColor(red: red, green: green, blue: blue, alpha: 0)
            
            // Hide the window after the fade completes
            window.orderOut(nil)
            NSLog("AppDelegate: Fade complete, hiding overlay")
          }
        }
        
        // Ensure the timer continues to fire even when there are no user events
        RunLoop.current.add(fadeTimer, forMode: .common)
        
        // If duration is longer than fade time, we'll hide after duration
        if duration > fadeTime {
          DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            // Only hide if the fade timer is no longer valid (animation completed)
            if !fadeTimer.isValid {
              NSLog("AppDelegate: Hiding flash overlay after \(duration) seconds")
              self?.flashOverlayWindow?.orderOut(nil)
            }
          }
        }
      } else {
        // Fallback if no color is set
        window.orderFront(nil)
        NSLog("AppDelegate: Showing flash overlay without animation (no color set)")
        
        // Automatically hide after the duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
          NSLog("AppDelegate: Hiding flash overlay after \(duration) seconds")
          self?.flashOverlayWindow?.orderOut(nil)
        }
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
