import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:simpleblue/model/bluetooth_device.dart';
import 'package:simpleblue/simpleblue.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

const serviceUUID = null;
const scanTimeout = 15000;

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _simplebluePlugin = Simpleblue();

  BluetoothDevice? _connectedDevice;

  String receivedData = '';

  @override
  void initState() {
    super.initState();

    _simplebluePlugin.listenConnectedDevice().listen((connectedDevice) {
      debugPrint("Connected device: $connectedDevice");

      connectedDevice?.stream?.listen((received) {
        setState(() {
          receivedData += "${DateTime.now().toString()}: $received\n";
        });
      });

      setState(() {
        _connectedDevice = connectedDevice;
      });
    }).onError((err) {
      debugPrint(err);
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _simplebluePlugin.scanDevices(serviceUUID: serviceUUID, timeout: 5000);
    });
  }

  var devices = <String>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          Text('Running on: $_platformVersion\n'),
          TextButton(
              child: Text('Scan Devices'),
              onPressed: () {
                _simplebluePlugin.scanDevices(serviceUUID: serviceUUID, timeout: scanTimeout);
              }),
          Expanded(
            child: StreamBuilder<List<BluetoothDevice>>(
                stream: _simplebluePlugin.listenDevices(),
                builder: (_, snap) {
                  final devices = snap.data ?? [];

                  return ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isConnected = _connectedDevice == device;

                        return ListTile(
                          onTap: () {
                            if (isConnected) {
                              _simplebluePlugin.disconnect(device.uuid);
                            } else {
                              _simplebluePlugin.connect(device.uuid);
                            }
                          },
                          leading: isConnected
                              ? Icon(Icons.bluetooth_connected, color: Colors.blue)
                              : Icon(
                                  Icons.bluetooth,
                                  color: Colors.grey.shade300,
                                ),
                          title: Text('${device.name ?? 'No name'}\n${device.uuid}'),
                          subtitle: isConnected
                              ? Row(
                                  children: [
                                    TextButton(
                                        child: Text('Connect'),
                                        onPressed: () {
                                          _simplebluePlugin
                                              .write(device.uuid, [2, 1, 0, 1, 0, 1, 0, 0, 3, 3]);
                                        }),
                                    TextButton(
                                        child: Text('Write 1'),
                                        onPressed: () {
                                          _simplebluePlugin
                                              .write(device.uuid, [2, 1, 3, 232, 0, 1, 0, 2, 128, 0, 107, 3]);
                                        })
                                  ],
                                )
                              : null,
                        );
                      });
                }),
          ),
          SizedBox(
              height: 200,
              child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    receivedData,
                    style: const TextStyle(fontSize: 10),
                  )))
        ]),
      ),
    );
  }
}
