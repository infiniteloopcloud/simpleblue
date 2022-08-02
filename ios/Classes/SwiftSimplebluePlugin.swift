import Flutter
import UIKit
import CoreBluetooth

@available(iOS 10.0, *)
public class SwiftSimplebluePlugin: NSObject,
                                    FlutterPlugin,
                                    FlutterStreamHandler,
                                    CBCentralManagerDelegate,
                                    CBPeripheralDelegate {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(name: "simpleblue", binaryMessenger: messenger)
        let instance = SwiftSimplebluePlugin()
        
        FlutterEventChannel.init(name: "simpleblue/events", binaryMessenger: messenger).setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        instance.initBluetooth()
    }
    
    let debugLog = true
    
    var cb: CBCentralManager?
    var devices: [String : CBPeripheral] = [:]
    var characteristics: [String : [CBCharacteristic]] = [:]
    var descriptors: [String : [CBDescriptor]] = [:]
    var eventSink: FlutterEventSink?
    
    private var serviceUUID: String?
    
    private func initBluetooth() {
        cb = CBCentralManager.init(delegate: self, queue: DispatchQueue.main)
    }
    
    
    // Central Manager START
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if let sink = eventSink {
            sink([
                "type": "state",
                "data": central.state.rawValue
            ])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (devices[peripheral.identifier.uuidString] == nil) {
            devices[peripheral.identifier.uuidString] = peripheral
        }
        
        if (eventSink != nil) {
            eventSink?([
                "type": "scanning",
                "data": devices.values.map({ convertDeviceToJson($0) })
            ])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        _connectResult?(nil)
        _connectResult = nil
        
        if (eventSink != nil) {
            eventSink?([
                "type": "connection",
                "data": [
                    "event": "connected",
                    "device": convertDeviceToJson(peripheral)
                ]
            ]
            )
        }
        
        if let serviceUUID = serviceUUID {
            peripheral.discoverServices([CBUUID(string: serviceUUID)])
        } else {
            peripheral.discoverServices(nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        _connectResult?(error)
        _connectResult = nil
        
        if (eventSink != nil) {
            eventSink?([
                "type": "connection",
                "data": [
                    "event": "connectionFailed",
                    "error": error?.localizedDescription,
                    "device": convertDeviceToJson(peripheral)
                ]
            ]
            )
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if (eventSink != nil) {
            eventSink?([
                "type": "connection",
                "data": [
                    "event": "disconnected",
                    "error": error?.localizedDescription,
                    "device": convertDeviceToJson(peripheral)
                ]
            ]
            )
        }
    }
    
    // Central Manager END
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil;
    }
    
    //    CBPeripheralDelegate START
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach({ service in
            if (serviceUUID == nil || service.uuid.uuidString == serviceUUID) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        })
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.forEach({ characteristic in
            peripheral.setNotifyValue(true, for: characteristic)
            
            peripheral.discoverDescriptors(for: characteristic)
        })
        
        if (service.characteristics?.isEmpty == false) {
            var chars = characteristics[peripheral.identifier.uuidString] ?? []
            
            chars.append(contentsOf: service.characteristics!)
            
            characteristics[peripheral.identifier.uuidString] = chars
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("didUpdateNotificationsStateFor: \(characteristic)\nError: \(error)")
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if (characteristic.descriptors?.isEmpty == false) {
            var descs = descriptors[characteristic.uuid.uuidString] ?? []
            
            descs.append(contentsOf: characteristic.descriptors!)
            
            descriptors[characteristic.uuid.uuidString] = descs
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("didWriteValueFor \(characteristic)")
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("didUpdateValueFor \(characteristic)")
        
        if let value = characteristic.value {
            var array = Array<UInt8>(repeating: 0, count: value.count/MemoryLayout<UInt8>.stride)
            _ = array.withUnsafeMutableBytes { value.copyBytes(to: $0) }
            
            debugPrint("  <<< \(array) \(characteristic)")
            
            eventSink?([
                "type": "data",
                "data": [
                    "bytes": array,
                    "device": convertDeviceToJson(peripheral)
                ]
            ])
        }
    }

    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        // to do nothing
    }
    
    //    CBPeripheralDelegate END
    
    
    // Methods START
    
    private func getDevices(_ call: FlutterMethodCall, _ args: NSDictionary, _ result: @escaping FlutterResult) {
        
        result(devices.values.map({ device in convertDeviceToJson(device) }))
    }
    
    private func scanDevices(_ call: FlutterMethodCall, _ args: NSDictionary, _ result: @escaping FlutterResult) {
        serviceUUID = args["serviceUUID"] as? String
        
        devices.removeAll()
        
        var cbuuids: [CBUUID]
        
        if let serviceUUID = serviceUUID {
            cbuuids = [CBUUID(string: serviceUUID)]
        } else {
            cbuuids = []
        }
        
        if let cb = cb {
            for device in cb.retrieveConnectedPeripherals(withServices: cbuuids) {
                devices[device.identifier.uuidString] = device
            }
            
            if (!devices.isEmpty) {
                eventSink?([
                    "type": "scanning",
                    "data": devices.values.map({ convertDeviceToJson($0) })
                ])
            }
            
            cb.scanForPeripherals(withServices: cbuuids)
            
            eventSink?([
                "type": "scanningState",
                "data": true
            ])
            
            let timeout = (args["timeout"] as? TimeInterval) ?? 5000
            debugPrint("Started scanning with \(timeout) ms timeout")
            
            Timer.scheduledTimer(withTimeInterval: timeout / 1000, repeats: false) { _ in
                self.cb?.stopScan()
                
                self.eventSink?([
                    "type": "scanningState",
                    "data": false
                ])
            }
        }
    }
    
    var _connectResult: FlutterResult? = nil
    
    private func connect(_ call: FlutterMethodCall, _ args: NSDictionary, _ result: @escaping FlutterResult) {
        if let uuid = args["uuid"] as? String {
            if let device = devices[uuid] {
                debugPrint("\(NSDate().timeIntervalSince1970) Connect to Device \(device.identifier.uuidString)")
                
                _connectResult = result
                
                cb?.connect(device)
                
                device.delegate = self
            }
        }
    }
    
    private func disconnect(_ call: FlutterMethodCall, _ args: NSDictionary, _ result: @escaping FlutterResult) {
        if let uuid = args["uuid"] as? String {
            if let device = devices[uuid] {
                cb?.cancelPeripheralConnection(device)
                device.delegate = nil
                characteristics.removeValue(forKey: uuid)
            }
        }
    }
    
    private func write(_ call: FlutterMethodCall, _ args: NSDictionary, _ result: @escaping FlutterResult) {
        guard let payload = args["data"] as? NSArray else {
            result("No data to write")
            return
        }
        
        guard let uuid = args["uuid"] as? String else {
            result("No uuid passed to write method")
            return
        }
        
        guard let device = devices[uuid] else {
            result("No device found with uuid (\(uuid))")
            return
        }
        
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: payload.count, alignment: 1)
        
        for i in 0..<payload.count {
            let byte = payload[i] as! UInt8
            
            rawData.storeBytes(of: byte, toByteOffset: i, as: UInt8.self)
        }
        
        let data = NSData(bytes: rawData, length: payload.count)
        
        
        var array = Array<UInt8>(repeating: 0, count: data.count/MemoryLayout<UInt8>.stride)
        _ = array.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        debugPrint(">>>   \(array)")
        
        
        let characteristics = self.characteristics[device.identifier.uuidString]
        
        characteristics?.forEach({ c in
            device.writeValue(data as Data, for: c, type: .withResponse)
            
        })
        
//        guard let characteristic = characteristics?.first(where: { c in c.properties.rawValue == 0x10 }) else {
//            result("No characteristic found for device (\(uuid))")
//            return
//        }
//
//        device.writeValue(data as Data, for: characteristic, type: .withResponse)
        result(nil)
    }
    
    // Methods END
    
    
    
    private func convertDeviceToJson(_ device: CBPeripheral) -> [String: Any] {
        return [
            "name": device.name,
            "uuid": device.identifier.uuidString,
            "isConnected": device.state == CBPeripheralState.connected
        ]
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        debugPrint("Received method call: \(call.method)")
        
        let args = call.arguments as? NSDictionary ?? [:]
        
        if (call.method.elementsEqual("getDevices")) {
            getDevices(call, args, result)
        } else if (call.method.elementsEqual("scanDevices")) {
            scanDevices(call, args, result)
        } else if (call.method.elementsEqual("connect")) {
            connect(call, args, result)
        } else if (call.method.elementsEqual("disconnect")) {
            disconnect(call, args, result)
        } else if (call.method.elementsEqual("write")) {
            write(call, args, result)
        }
    }
    
    func debugPrint(_ message: String) {
        if (debugLog) {
            print(message)
        }
    }
}
