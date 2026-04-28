import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// 러닝 세션 저장 실패 시 로컬에 큐잉하는 서비스.
//
// 정책: [POLICY.md § 3]
// - 러닝 종료 시점(saveSession) 호출 실패하면 세션 JSON + 시도 횟수 + 마지막 시도 시각을 큐에 push
// - 앱 재시작 또는 온라인 복귀 시 큐를 순회하며 재시도, 성공하면 dequeue
// - 큐 키: `running_sync_queue_v1` (배열 직렬화 형태)
//
// 본 클래스는 SharedPreferences 기반 동기 큐 인터페이스만 제공.
// flush/재시도 트리거(Connectivity 스트림, 앱 재시작 hook)는 별도 코디네이터에서 처리.
class RunningSyncQueue {
  static const String _key = 'running_sync_queue_v1';

  final DateTime Function() _now;

  RunningSyncQueue({DateTime Function()? now}) : _now = now ?? DateTime.now;

  // 큐에 항목 추가
  Future<void> enqueue(Map<String, dynamic> sessionJson) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    entries.add(_QueueEntry(
      session: sessionJson,
      attempts: 0,
      lastAttemptAt: null,
      enqueuedAt: _now(),
    ));
    await _write(prefs, entries);
  }

  // 큐에 있는 모든 항목을 (현재 시점 snapshot) 반환
  Future<List<RunningSyncQueueItem>> peekAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    return entries
        .map((e) => RunningSyncQueueItem(
              session: e.session,
              attempts: e.attempts,
              lastAttemptAt: e.lastAttemptAt,
              enqueuedAt: e.enqueuedAt,
            ))
        .toList(growable: false);
  }

  // 큐 길이
  Future<int> length() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).length;
  }

  // 가장 오래된 항목을 성공 처리 (제거). 일치하는 enqueuedAt 항목을 dequeue.
  Future<void> ackByEnqueuedAt(DateTime enqueuedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    entries.removeWhere(
      (e) => e.enqueuedAt.millisecondsSinceEpoch ==
          enqueuedAt.millisecondsSinceEpoch,
    );
    await _write(prefs, entries);
  }

  // 시도 실패 기록 — attempts 증가 + lastAttemptAt 갱신
  Future<void> bumpAttempt(DateTime enqueuedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    final idx = entries.indexWhere(
      (e) => e.enqueuedAt.millisecondsSinceEpoch ==
          enqueuedAt.millisecondsSinceEpoch,
    );
    if (idx < 0) return;
    final old = entries[idx];
    entries[idx] = _QueueEntry(
      session: old.session,
      attempts: old.attempts + 1,
      lastAttemptAt: _now(),
      enqueuedAt: old.enqueuedAt,
    );
    await _write(prefs, entries);
  }

  // 테스트용 — 큐 전체 제거
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── 내부 직렬화 ──────────────────────────────────────────────────
  List<_QueueEntry> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <_QueueEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <_QueueEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_QueueEntry.fromJson)
          .toList();
    } catch (_) {
      return <_QueueEntry>[];
    }
  }

  Future<void> _write(SharedPreferences prefs, List<_QueueEntry> entries) async {
    if (entries.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}

// 외부 노출 immutable view
class RunningSyncQueueItem {
  final Map<String, dynamic> session;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime enqueuedAt;

  const RunningSyncQueueItem({
    required this.session,
    required this.attempts,
    required this.lastAttemptAt,
    required this.enqueuedAt,
  });
}

// 내부 큐 엔트리
class _QueueEntry {
  final Map<String, dynamic> session;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime enqueuedAt;

  const _QueueEntry({
    required this.session,
    required this.attempts,
    required this.lastAttemptAt,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'session': session,
        'attempts': attempts,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };

  factory _QueueEntry.fromJson(Map<String, dynamic> j) => _QueueEntry(
        session: (j['session'] as Map?)?.cast<String, dynamic>() ?? const {},
        attempts: (j['attempts'] as int?) ?? 0,
        lastAttemptAt: j['lastAttemptAt'] is String
            ? DateTime.tryParse(j['lastAttemptAt'] as String)
            : null,
        enqueuedAt: j['enqueuedAt'] is String
            ? (DateTime.tryParse(j['enqueuedAt'] as String) ?? DateTime.now())
            : DateTime.now(),
      );
}
