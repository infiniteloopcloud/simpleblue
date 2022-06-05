class BluetoothDevice {
  final String? name;
  final String uuid;
  final bool isConnected;
  Stream<List<int>>? stream;

  BluetoothDevice(this.name, this.uuid, this.isConnected, {this.stream});


  @override
  bool operator==(dynamic other) {
    return other is BluetoothDevice && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() => '[$uuid] - $name - ${isConnected ? 'connected' : 'disconnected'}';
}