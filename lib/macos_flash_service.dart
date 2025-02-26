import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MacOSFlashService {
  static const String channelName = 'com.mindfulnessbell/overlay';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Request accessibility permissions required for system-wide overlay
  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint(
          'MacOSFlashService: Calling requestPermissions on channel: $channelName');
      try {
        final result = await _channel.invokeMethod('requestPermissions');
        debugPrint(
            'MacOSFlashService: requestPermissions succeeded with result: $result');
      } on PlatformException catch (e) {
        debugPrint(
            'MacOSFlashService: Failed to request permissions: ${e.message}');
        debugPrint(
            'MacOSFlashService: PlatformException details: code=${e.code}, details=${e.details}');
        await _openSystemPreferencesDirectly();
      } on MissingPluginException catch (e) {
        debugPrint('MacOSFlashService: Plugin not available: ${e.message}');
        debugPrint(
            'MacOSFlashService: This suggests channel "$channelName" is not registered in Swift side');
        // Try to open the settings directly with url_launcher
        await _openSystemPreferencesDirectly();
      } catch (e) {
        debugPrint(
            'MacOSFlashService: Unexpected error calling requestPermissions: $e');
        await _openSystemPreferencesDirectly();
      }
    } else {
      debugPrint(
          'MacOSFlashService: Not on macOS, platform is ${defaultTargetPlatform.toString()}');
    }
  }

  // A fallback method to open System Preferences directly
  Future<void> _openSystemPreferencesDirectly() async {
    debugPrint(
        'MacOSFlashService: Attempting to open System Preferences directly via url_launcher');
    try {
      final Uri url = Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility');
      final bool success = await launchUrl(url);
      debugPrint(
          'MacOSFlashService: Directly opening System Preferences result: $success');
    } catch (e) {
      debugPrint(
          'MacOSFlashService: Error opening system preferences directly: $e');
    }
  }

  /// Show a system-wide flash overlay
  ///
  /// [duration] is in seconds
  /// [color] is a hex string in format #RRGGBBAA
  Future<void> showFlash({
    double duration = 0.8,
    String color = '#FFF3E080', // Default warm color with 50% opacity
  }) async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint(
          'MacOSFlashService: Calling showFlash on channel: $channelName');

      // Debug the plugin registration state first
      await _validatePluginRegistration();

      try {
        debugPrint(
            'MacOSFlashService: Preparing to invoke showFlash with params: '
            'duration=$duration, color=$color');

        final result = await _channel.invokeMethod('showFlash', {
          'duration': duration,
          'color': color,
        });
        debugPrint(
            'MacOSFlashService: showFlash succeeded with result: $result');
      } on PlatformException catch (e) {
        debugPrint('MacOSFlashService: Failed to show flash: ${e.message}');
        debugPrint('MacOSFlashService: PlatformException details - '
            'code: ${e.code}, details: ${e.details}');
      } on MissingPluginException catch (e) {
        debugPrint(
            'MacOSFlashService: Plugin not available for showFlash: ${e.message}');
        debugPrint(
            'MacOSFlashService: MissingPluginException suggests that either:');
        debugPrint(
            '  1. The plugin is not properly registered in the GeneratedPluginRegistrant');
        debugPrint(
            '  2. The plugin channel name ($channelName) does not match between Flutter and native');
        debugPrint(
            '  3. The method name (showFlash) does not exist in the native implementation');

        // Try to ping the channel to see if it exists at all
        await _pingChannel();
      }
    }
  }

  /// Attempts to validate if the plugin is registered and responsive
  Future<bool> _validatePluginRegistration() async {
    debugPrint('MacOSFlashService: Validating plugin registration...');
    try {
      // First test with the ping method
      final bool pingResult = await _pingChannel();

      if (pingResult) {
        debugPrint(
            'MacOSFlashService: Plugin appears to be registered and responsive');
        return true;
      }
    } catch (e) {
      debugPrint('MacOSFlashService: Error validating plugin registration: $e');
    }
    return false;
  }

  /// Attempts to ping the channel to see if it's responsive
  Future<bool> _pingChannel() async {
    debugPrint('MacOSFlashService: Testing channel with ping method...');
    try {
      final result = await _channel.invokeMethod<bool>('ping').timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint(
              'MacOSFlashService: Channel ping timed out, suggesting the plugin is not registered');
          return false;
        },
      );
      debugPrint('MacOSFlashService: Ping result: $result');
      return result ?? false;
    } on MissingPluginException catch (e) {
      debugPrint('MacOSFlashService: Channel does not exist: ${e.message}');
      return false;
    } on PlatformException catch (e) {
      // This could be good - it means the channel exists but ping method isn't implemented
      debugPrint(
          'MacOSFlashService: Channel exists but ping method not implemented: ${e.message}');
      debugPrint(
          'MacOSFlashService: The channel exists but the ping method is not recognized');
      return true;
    } catch (e) {
      debugPrint('MacOSFlashService: Unexpected error pinging channel: $e');
      return false;
    }
  }

  /// Singleton instance
  static final MacOSFlashService _instance = MacOSFlashService._internal();
  factory MacOSFlashService() => _instance;
  MacOSFlashService._internal() {
    debugPrint(
        'MacOSFlashService: Initialized with channel name: $channelName');
  }
}
