import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/wakelock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WakelockService — 토글 영속화', () {
    test('초기값은 true (기본 ON)', () async {
      expect(await WakelockService.isEnabled(), true);
    });

    test('setEnabled(false) 후 isEnabled false', () async {
      await WakelockService.setEnabled(false);
      expect(await WakelockService.isEnabled(), false);
    });

    test('setEnabled(true) 후 isEnabled true', () async {
      await WakelockService.setEnabled(false);
      await WakelockService.setEnabled(true);
      expect(await WakelockService.isEnabled(), true);
    });
  });
}
