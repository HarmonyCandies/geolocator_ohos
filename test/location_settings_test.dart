import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_ohos/geolocator_ohos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/geolocator_ohos');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '{"latitude":30.5,"longitude":114.3,"accuracy":25.0,"timeStamp":1780000000000}';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('standard settings obtain a position through the native request',
      () async {
    final position = await GeolocatorOhos().getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );

    expect(position.latitude, 30.5);
    expect(position.longitude, 114.3);
    expect(position.accuracy, 25);
    expect(calls.single.method, 'getCurrentPosition');
    expect(jsonDecode(calls.single.arguments as String), {
      'priority': 0x201,
      'timeoutMs': 5000,
    });
  });

  test('explicit OHOS requests retain their scenario and accuracy', () async {
    await GeolocatorOhos().getCurrentPosition(
      locationSettings: const CurrentLocationSettingsOhos(
        scenario: LocationRequestScenario.dailyLifeService,
        maxAccuracy: 100,
        timeoutMs: 7000,
      ),
    );

    expect(jsonDecode(calls.single.arguments as String), {
      'scenario': 0x304,
      'maxAccuracy': 100,
      'timeoutMs': 7000,
    });
  });
}
