import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flash_overlay_method_channel.dart';

abstract class FlashOverlayPlatform extends PlatformInterface {
  /// Constructs a FlashOverlayPlatform.
  FlashOverlayPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlashOverlayPlatform _instance = MethodChannelFlashOverlay();

  /// The default instance of [FlashOverlayPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlashOverlay].
  static FlashOverlayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlashOverlayPlatform] when
  /// they register themselves.
  static set instance(FlashOverlayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
