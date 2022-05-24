import 'package:simpleblue/model/bluetooth_device.dart';

import 'simpleblue_platform_interface.dart';

class Simpleblue {
  Future<List<String>> getDevices() {
    return SimplebluePlatform.instance.getDevices();
  }

  Future scanDevices({String? serviceUUID, int timeout = 10000}) {
    return SimplebluePlatform.instance.scanDevices(serviceUUID: serviceUUID, timeout: timeout);
  }

  Stream<List<BluetoothDevice>> listenDevices() {
    return SimplebluePlatform.instance.listenDevices();
  }

  Future connect(String uuid) {
    return SimplebluePlatform.instance.connect(uuid);
  }

  Future disconnect(String uuid) {
    return SimplebluePlatform.instance.disconnect(uuid);
  }

  Stream<BluetoothDevice?> listenConnectedDevice() {
    return SimplebluePlatform.instance.listenConnectedDevice();
  }

  Future write(String uuid, List<int> data) {
    return SimplebluePlatform.instance.write(uuid, data);
  }
}
