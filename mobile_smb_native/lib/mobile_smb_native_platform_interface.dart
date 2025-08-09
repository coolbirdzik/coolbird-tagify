import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mobile_smb_native_method_channel.dart';

abstract class MobileSmbNativePlatform extends PlatformInterface {
  /// Constructs a MobileSmbNativePlatform.
  MobileSmbNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static MobileSmbNativePlatform _instance = MethodChannelMobileSmbNative();

  /// The default instance of [MobileSmbNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelMobileSmbNative].
  static MobileSmbNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MobileSmbNativePlatform] when
  /// they register themselves.
  static set instance(MobileSmbNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
