# Simpleblue

### Features

- Supports both Android and iOS.
- Small codebase, so breaking changes on the underlying system (ex. bluetooth related updates) can be easily upgraded.
- Easy to use, only a few functions to create a working app.

### Android

Add the following permissions to your AndroidManifest.xml file. To handle permissions you can use permission_handler package.

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
```

### iOS

Add the following properties to Info.plist in Xcode.

* Privacy - Bluetooth Always Usage Description
* Privacy - Bluetooth Peripheral Usage Description



### Usage

```dart
import 'dart:io';

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

  var devices = <String, BluetoothDevice>{};

  String receivedData = '';

  @override
  void initState() {
    super.initState();

    _simplebluePlugin.listenConnectedDevice().listen((connectedDevice) {
      debugPrint("Connected device: $connectedDevice");

      if (connectedDevice != null) {
        setState(() {
          devices[connectedDevice.uuid] = connectedDevice;
        });
      }

      connectedDevice?.stream?.listen((received) {
        setState(() {
          receivedData += "${DateTime.now().toString()}: $received\n";
        });
      });
    }).onError((err) {
      debugPrint(err);
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      scan();
    });

    _simplebluePlugin.getDevices().then((value) => setState(() {
      for (var device in value) {
        devices[device.uuid] = device;
      }
    }));
  }

  void scan() async {
    final isBluetoothGranted = Platform.isIOS || (await Permission.bluetooth.status) == PermissionStatus.granted ||
        (await Permission.bluetooth.request()) == PermissionStatus.granted;

    if (isBluetoothGranted) {
      print("Bluetooth permission granted");

      final isLocationGranted = Platform.isIOS || (await Permission.location.status) == PermissionStatus.granted ||
          (await Permission.location.request()) == PermissionStatus.granted;

      if (isLocationGranted) {
        print("Location permission granted");
        _simplebluePlugin.scanDevices(serviceUUID: serviceUUID, timeout: scanTimeout).listen((event) {
          setState(() {
            for (var device in event) {
              devices[device.uuid] = device;
            }
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          TextButton(
              child: Text('Get Devices'),
              onPressed: () {
                _simplebluePlugin.getDevices().then((value) {
                  setState(() {
                    for (var device in value) {
                      devices[device.uuid] = device;
                    }
                  });
                });
              }),
          TextButton(
              child: Text('Scan Devices'),
              onPressed: () {
                scan();
              }),
          Expanded(
            child: buildDevices(),
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

  final _connectingUUIDs = <String>[];

  Widget buildDevices() {
    final devList = devices.values.toList();
    return ListView.builder(
        itemCount: devList.length,
        itemBuilder: (context, index) {
          final device = devList[index];

          return ListTile(
            onTap: () {
              if (device.isConnected) {
                _simplebluePlugin.disconnect(device.uuid);
              } else {
                setState(() {
                  _connectingUUIDs.add(device.uuid);
                });
                _simplebluePlugin.connect(device.uuid).then((value) {
                  setState(() {
                    _connectingUUIDs.remove(device.uuid);
                  });
                });
              }
            },
            leading: _connectingUUIDs.contains(device.uuid)
                ? Icon(Icons.bluetooth, color: Colors.orange)
                : (device.isConnected
                ? Icon(Icons.bluetooth_connected, color: Colors.blue)
                : Icon(
              Icons.bluetooth,
              color: Colors.grey.shade300,
            )),
            title: Text('${device.name ?? 'No name'}\n${device.uuid}'),
            subtitle: device.isConnected
                ? Row(
              children: [
                TextButton(
                    child: Text('Write 1'),
                    onPressed: () {
                      _simplebluePlugin.write(device.uuid, "sample data".codeUnits);
                    }),
                TextButton(
                    child: Text('Write 2'),
                    onPressed: () {
                      _simplebluePlugin.write(device.uuid, "sample data 2".codeUnits);
                    })
              ],
            )
                : null,
          );
        });
  }
}
```
