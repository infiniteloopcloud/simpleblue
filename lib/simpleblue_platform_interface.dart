import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:simpleblue/model/bluetooth_device.dart';

import 'simpleblue_method_channel.dart';

abstract class SimplebluePlatform extends PlatformInterface {
  /// Constructs a SimplebluePlatform.
  SimplebluePlatform() : super(token: _token);

  static final Object _token = Object();

  static SimplebluePlatform _instance = MethodChannelSimpleblue();

  /// The default instance of [SimplebluePlatform] to use.
  ///
  /// Defaults to [MethodChannelSimpleblue].
  static SimplebluePlatform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SimplebluePlatform] when
  /// they register themselves.
  static set instance(SimplebluePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<BluetoothDevice>> getDevices() {
    throw UnimplementedError('getDevices() has not been implemented.');
  }

  Stream<List<BluetoothDevice>> scanDevices({String? serviceUUID, int timeout = 10000}) {
    throw UnimplementedError('scanDevices() has not been implemented.');
  }

  Future stopScanning() {
    throw UnimplementedError('stopScanning() has not been implemented.');
  }

  Future connect(String uuid) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future disconnect(String uuid) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Stream<BluetoothDevice?> listenConnectedDevice() {
    throw UnimplementedError('listenConnectedDevice() has not been implemented.');
  }

  Future write(String uuid, List<int> data) {
    throw UnimplementedError('write() has not been implemented.');
  }
}
