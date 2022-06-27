import 'package:simpleblue/model/bluetooth_device.dart';

import 'simpleblue_platform_interface.dart';

class Simpleblue {
  Future<List<BluetoothDevice>> getDevices() {
    return SimplebluePlatform.instance.getDevices();
  }

  Stream<List<BluetoothDevice>> scanDevices({String? serviceUUID, int timeout = 10000}) {
    return SimplebluePlatform.instance.scanDevices(serviceUUID: serviceUUID, timeout: timeout);
  }

  Future stopScanning() {
    return SimplebluePlatform.instance.stopScanning();
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
