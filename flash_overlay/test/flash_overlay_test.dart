import 'package:flutter_test/flutter_test.dart';
import 'package:flash_overlay/flash_overlay.dart';
import 'package:flash_overlay/flash_overlay_platform_interface.dart';
import 'package:flash_overlay/flash_overlay_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlashOverlayPlatform
    with MockPlatformInterfaceMixin
    implements FlashOverlayPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlashOverlayPlatform initialPlatform = FlashOverlayPlatform.instance;

  test('$MethodChannelFlashOverlay is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlashOverlay>());
  });

  test('getPlatformVersion', () async {
    FlashOverlay flashOverlayPlugin = FlashOverlay();
    MockFlashOverlayPlatform fakePlatform = MockFlashOverlayPlatform();
    FlashOverlayPlatform.instance = fakePlatform;

    expect(await flashOverlayPlugin.getPlatformVersion(), '42');
  });
}
