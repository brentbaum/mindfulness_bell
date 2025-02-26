
import 'flash_overlay_platform_interface.dart';

class FlashOverlay {
  Future<String?> getPlatformVersion() {
    return FlashOverlayPlatform.instance.getPlatformVersion();
  }
}
