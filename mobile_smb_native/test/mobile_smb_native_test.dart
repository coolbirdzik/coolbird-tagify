import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_smb_native/mobile_smb_native.dart';
import 'package:mobile_smb_native/mobile_smb_native_platform_interface.dart';
import 'package:mobile_smb_native/mobile_smb_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMobileSmbNativePlatform
    with MockPlatformInterfaceMixin
    implements MobileSmbNativePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MobileSmbNativePlatform initialPlatform = MobileSmbNativePlatform.instance;

  test('$MethodChannelMobileSmbNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMobileSmbNative>());
  });

  test('getPlatformVersion', () async {
    MobileSmbNative mobileSmbNativePlugin = MobileSmbNative();
    MockMobileSmbNativePlatform fakePlatform = MockMobileSmbNativePlatform();
    MobileSmbNativePlatform.instance = fakePlatform;

    expect(await mobileSmbNativePlugin.getPlatformVersion(), '42');
  });
}
