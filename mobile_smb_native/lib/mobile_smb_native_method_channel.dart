import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mobile_smb_native_platform_interface.dart';

/// An implementation of [MobileSmbNativePlatform] that uses method channels.
class MethodChannelMobileSmbNative extends MobileSmbNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mobile_smb_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
