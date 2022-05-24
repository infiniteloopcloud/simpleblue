import 'package:flutter_test/flutter_test.dart';
import 'package:simpleblue/simpleblue.dart';
import 'package:simpleblue/simpleblue_platform_interface.dart';
import 'package:simpleblue/simpleblue_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSimplebluePlatform 
    with MockPlatformInterfaceMixin
    implements SimplebluePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SimplebluePlatform initialPlatform = SimplebluePlatform.instance;

  test('$MethodChannelSimpleblue is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSimpleblue>());
  });

  test('getPlatformVersion', () async {
    Simpleblue simplebluePlugin = Simpleblue();
    MockSimplebluePlatform fakePlatform = MockSimplebluePlatform();
    SimplebluePlatform.instance = fakePlatform;
  
    expect(await simplebluePlugin.getPlatformVersion(), '42');
  });
}
