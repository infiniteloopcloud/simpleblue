import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
      scan();
    });

    _simplebluePlugin.getDevices().then((value) => setState(() {
          devices = value;
        }));
  }

  void scan() async {
    final isBluetoothGranted = (await Permission.bluetooth.status) == PermissionStatus.granted ||
        (await Permission.bluetooth.request()) == PermissionStatus.granted;

    if (isBluetoothGranted) {
      print("Bluetooth permission granted");

      final isLocationGranted = (await Permission.location.status) == PermissionStatus.granted ||
          (await Permission.location.request()) == PermissionStatus.granted;

      if (isLocationGranted) {
        print("Location permission granted");
        _simplebluePlugin.scanDevices(serviceUUID: serviceUUID, timeout: scanTimeout);
      }
    }
  }

  var devices = <BluetoothDevice>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          TextButton(
              child: Text('Scan Devices'),
              onPressed: () {
                scan();
              }),
          Expanded(
            child: StreamBuilder<List<BluetoothDevice>>(
                stream: _simplebluePlugin.listenDevices(),
                builder: (_, snap) {
                  final deviceSet = (snap.data ?? []).toSet();
                  deviceSet.addAll(this.devices);

                  final devices = deviceSet.toList();

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
                                        child: Text('Write 1'),
                                        onPressed: () {
                                          _simplebluePlugin
                                              .write(device.uuid, "sample data".codeUnits);
                                        }),
                                    TextButton(
                                        child: Text('Write 2'),
                                        onPressed: () {
                                          _simplebluePlugin
                                              .write(device.uuid, "sample data 2".codeUnits);
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
