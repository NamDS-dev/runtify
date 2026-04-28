import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/running_sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fakeNow = DateTime(2026, 4, 28, 22, 0, 0);
  RunningSyncQueue newQueue() => RunningSyncQueue(now: () => fakeNow);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 4, 28, 22, 0, 0);
  });

  group('RunningSyncQueue', () {
    test('초기 상태는 빈 큐', () async {
      final q = newQueue();
      expect(await q.length(), 0);
      expect(await q.peekAll(), isEmpty);
    });

    test('enqueue 후 peekAll 에 노출 + length 증가', () async {
      final q = newQueue();
      await q.enqueue({'id': 'session_1', 'distance': 5.2});
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await q.enqueue({'id': 'session_2', 'distance': 3.1});

      expect(await q.length(), 2);
      final items = await q.peekAll();
      expect(items.length, 2);
      expect(items.first.session['id'], 'session_1');
      expect(items.last.session['id'], 'session_2');
    });

    test('enqueue 항목은 attempts=0, lastAttemptAt=null 로 시작', () async {
      final q = newQueue();
      await q.enqueue({'id': 's1'});
      final item = (await q.peekAll()).first;
      expect(item.attempts, 0);
      expect(item.lastAttemptAt, isNull);
    });

    test('bumpAttempt 는 attempts 증가 + lastAttemptAt 갱신', () async {
      final q = newQueue();
      await q.enqueue({'id': 's1'});
      final enqueuedAt = (await q.peekAll()).first.enqueuedAt;

      fakeNow = fakeNow.add(const Duration(minutes: 5));
      await q.bumpAttempt(enqueuedAt);

      final item = (await q.peekAll()).first;
      expect(item.attempts, 1);
      expect(item.lastAttemptAt, isNotNull);
      expect(
        item.lastAttemptAt!.difference(enqueuedAt).inSeconds,
        inInclusiveRange(298, 302),
      );
    });

    test('ackByEnqueuedAt 는 해당 항목만 제거', () async {
      final q = newQueue();
      await q.enqueue({'id': 's1'});
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await q.enqueue({'id': 's2'});

      final firstEnqueuedAt = (await q.peekAll()).first.enqueuedAt;
      await q.ackByEnqueuedAt(firstEnqueuedAt);

      final remaining = await q.peekAll();
      expect(remaining.length, 1);
      expect(remaining.first.session['id'], 's2');
    });

    test('clear 는 모든 항목 제거', () async {
      final q = newQueue();
      await q.enqueue({'id': 's1'});
      await q.enqueue({'id': 's2'});
      expect(await q.length(), 2);

      await q.clear();
      expect(await q.length(), 0);
    });

    test('직렬화 라운드트립 — enqueue 후 새 인스턴스로 읽어도 동일', () async {
      final q1 = newQueue();
      await q1.enqueue({'id': 's1', 'distance': 5.5, 'meta': {'k': 'v'}});

      final q2 = newQueue();
      final items = await q2.peekAll();
      expect(items.length, 1);
      expect(items.first.session['id'], 's1');
      expect(items.first.session['distance'], 5.5);
      expect((items.first.session['meta'] as Map)['k'], 'v');
    });
  });
}
