import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the macOS host (macos/Runner/AppDelegate.swift): the full-screen
/// flash overlay, mic monitoring, the menu bar item, the main window and
/// launch at login. All calls are no-ops off macOS.
class NativeBridge {
  NativeBridge._() {
    _channel.setMethodCallHandler(_handle);
  }
  static final NativeBridge instance = NativeBridge._();

  static const _channel = MethodChannel('com.mindfulnessbell/overlay');

  /// Mic started or stopped being used by any app.
  ValueChanged<bool>? onMicrophoneChanged;

  /// Menu bar actions: 'toggle', 'ringNow'.
  ValueChanged<String>? onMenuAction;

  /// Launch-at-login was flipped from the menu bar.
  ValueChanged<bool>? onLaunchAtLoginChanged;

  bool get _mac => defaultTargetPlatform == TargetPlatform.macOS && !kIsWeb;

  Future<dynamic> _handle(MethodCall call) async {
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'microphoneStatusChanged':
        onMicrophoneChanged?.call(args['isInUse'] == true);
      case 'menuAction':
        onMenuAction?.call(args['action'] as String);
      case 'launchAtLoginChanged':
        onLaunchAtLoginChanged?.call(args['enabled'] == true);
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!_mac) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.$method failed: ${e.message}');
    } on MissingPluginException {
      debugPrint('NativeBridge.$method: host channel not registered');
    }
    return null;
  }

  /// [color] is #RRGGBBAA. The overlay fades in, holds briefly, then fades out
  /// over [duration] seconds in total.
  Future<void> showFlash({double duration = 6, required String color}) =>
      _invoke('showFlash', {'duration': duration, 'color': color});

  Future<bool> microphoneInUse() async =>
      await _invoke<bool>('getMicrophoneStatus') ?? false;
  Future<void> startMicrophoneMonitoring() =>
      _invoke('startMicrophoneMonitoring');
  Future<void> stopMicrophoneMonitoring() =>
      _invoke('stopMicrophoneMonitoring');

  /// Keeps the menu bar item's "Next bell" line and Start/Pause label current.
  Future<void> updateStatus(
          {required bool running, required int remainingSeconds}) =>
      _invoke(
          'updateStatus', {'running': running, 'remaining': remainingSeconds});

  Future<void> showWindow() => _invoke('showWindow');
  Future<void> hideWindow() => _invoke('hideWindow');

  Future<bool> launchAtLogin() async =>
      await _invoke<bool>('getLaunchAtLogin') ?? false;

  /// Returns the resulting state (registration can fail, e.g. on macOS < 13).
  Future<bool> setLaunchAtLogin(bool enabled) async =>
      await _invoke<bool>('setLaunchAtLogin', {'enabled': enabled}) ?? false;
}
