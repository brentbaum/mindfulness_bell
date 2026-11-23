import CoreAudio
import FlutterMacOS
import Foundation

/// Polls whether any app is using the default input device (a proxy for "in a
/// meeting") and tells Flutter when that changes. Needs no mic permission:
/// it only reads the device's running state, never audio.
final class MicrophoneMonitor {
  static let shared = MicrophoneMonitor()

  private var channel: FlutterMethodChannel?
  private var timer: Timer?
  private var inUse = false

  func initialize(channel: FlutterMethodChannel) { self.channel = channel }

  func startMonitoring() {
    stopMonitoring()
    let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
  }

  func currentStatus() -> Bool {
    poll()
    return inUse
  }

  private func defaultInputDevice() -> AudioDeviceID? {
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
    return status == noErr && id != 0 ? id : nil
  }

  private func poll() {
    // Re-resolve each time so switching headsets/AirPods is picked up.
    guard let device = defaultInputDevice() else { return }
    var running: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr else {
      return
    }
    let now = running != 0
    guard now != inUse else { return }
    inUse = now
    channel?.invokeMethod("microphoneStatusChanged", arguments: ["isInUse": now])
  }
}
