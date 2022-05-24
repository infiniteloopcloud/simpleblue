import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:simpleblue/model/bluetooth_device.dart';

import 'simpleblue_platform_interface.dart';

/// An implementation of [SimplebluePlatform] that uses method channels.
class MethodChannelSimpleblue extends SimplebluePlatform {
  final _scanningStreamController = StreamController<List<BluetoothDevice>>();
  final _connectionStreamController = StreamController<BluetoothDevice?>();

  final _dataStreamControllers = <String, StreamController<List<int>>>{};

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('simpleblue');

  final _scanningEventChannel = const EventChannel('simpleblue/events');

  MethodChannelSimpleblue() {
    _scanningEventChannel.receiveBroadcastStream().map((event) => event as Map).listen((event) {
      debugPrint('OnNewPlatformEvent: $event');

      switch (event["type"]) {
        case "scanning":
          _onScanningEvent(event["data"] as List);
          break;
        case "connection":
          _onConnectionEvent(event["data"] as Map);
          break;
        case "data":
          _onReceivedData(event["data"] as Map);
          break;
      }
    });
  }

  _onScanningEvent(List data) {
    _scanningStreamController.add(data.map((e) => e as Map).map((e) => _deviceFromJson(e)).toList());
  }

  _onConnectionEvent(Map data) {
    final device = _deviceFromJson(data["device"] as Map);

    switch (data["event"]) {
      case "connected":
        {
          final streamController = StreamController<List<int>>();
          _dataStreamControllers[device.uuid] = streamController;
          device.stream = streamController.stream;
          _connectionStreamController.add(device);
          break;
        }
      case "failedToConnect":
        {
          _connectionStreamController.addError(Error());
          break;
        }
      case "disconnected":
        {
          _dataStreamControllers.remove(device.uuid);
          device.stream = null;
          _connectionStreamController.add(null);
          break;
        }
    }
  }

  _onReceivedData(Map data) {
    final device = _deviceFromJson(data["device"] as Map);

    _dataStreamControllers[device.uuid]?.add((data["bytes"] as List).map((e) => e as int).toList());
  }

  @override
  Future<List<String>> getDevices() async {
    final devices = await methodChannel.invokeMethod<List<dynamic>>('getDevices');
    return devices?.map((e) => e.toString()).toList() ?? [];
  }

  @override
  Future scanDevices({String? serviceUUID, int timeout = 10000}) {
    return methodChannel.invokeMethod(
        'scanDevices', {'timeout': timeout, if (serviceUUID != null) 'serviceUUID': serviceUUID});
  }

  @override
  Stream<List<BluetoothDevice>> listenDevices() {
    return _scanningStreamController.stream;
  }

  @override
  Future connect(String uuid) {
    return methodChannel.invokeMethod('connect', {'uuid': uuid});
  }

  @override
  Future disconnect(String uuid) {
    return methodChannel.invokeMethod('disconnect', {'uuid': uuid});
  }

  @override
  Stream<BluetoothDevice?> listenConnectedDevice() {
    return _connectionStreamController.stream;
  }

  @override
  Future write(String uuid, List<int> data) {
    return methodChannel.invokeMethod('write', {'uuid': uuid, 'data': data});
  }
}

BluetoothDevice _deviceFromJson(Map json) =>
    BluetoothDevice(json["name"] as String?, json["uuid"] as String, json['isConnected'] as bool);