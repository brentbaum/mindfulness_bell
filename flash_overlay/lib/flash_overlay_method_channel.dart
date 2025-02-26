import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flash_overlay_platform_interface.dart';

/// An implementation of [FlashOverlayPlatform] that uses method channels.
class MethodChannelFlashOverlay extends FlashOverlayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flash_overlay');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
