import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/analytics_events.dart';

void main() {
  group('AnalyticsEvents 카탈로그', () {
    test('이벤트명은 영문 소문자 + underscore 형식', () {
      final names = [
        AnalyticsEvents.signUp,
        AnalyticsEvents.login,
        AnalyticsEvents.runningStarted,
        AnalyticsEvents.runningSaved,
        AnalyticsEvents.rankingTabOpened,
        AnalyticsEvents.rankingViewDwell,
        AnalyticsEvents.levelUp,
        AnalyticsEvents.timeToNextRun,
        AnalyticsEvents.badgeEarned,
        AnalyticsEvents.runningCompleted,
        AnalyticsEvents.accountDeletionRequested,
        AnalyticsEvents.accountDeletionConfirmed,
        AnalyticsEvents.accountRecovered,
      ];
      final regex = RegExp(r'^[a-z][a-z_]*[a-z]$');
      for (final n in names) {
        expect(regex.hasMatch(n), true,
            reason: '"$n" 은 영문 소문자/underscore 형식이 아님');
      }
    });

    test('이벤트명은 중복 없음', () {
      final names = {
        AnalyticsEvents.signUp,
        AnalyticsEvents.login,
        AnalyticsEvents.logout,
        AnalyticsEvents.emailVerificationSent,
        AnalyticsEvents.passwordResetRequested,
        AnalyticsEvents.runningStarted,
        AnalyticsEvents.runningSaved,
        AnalyticsEvents.crewJoined,
        AnalyticsEvents.crewLeft,
        AnalyticsEvents.rankingTabOpened,
        AnalyticsEvents.rankingViewDwell,
        AnalyticsEvents.levelUp,
        AnalyticsEvents.timeToNextRun,
        AnalyticsEvents.badgeEarned,
        AnalyticsEvents.runningCompleted,
        AnalyticsEvents.accountDeletionRequested,
        AnalyticsEvents.accountDeletionConfirmed,
        AnalyticsEvents.accountRecovered,
      };
      // Set 으로 변환 후 길이 비교 — 중복 있으면 set 길이가 작아짐
      expect(names.length, 18);
    });
  });

  group('bucketDwellSeconds', () {
    test('기본 3초 bucket', () {
      expect(AnalyticsEvents.bucketDwellSeconds(0), 0);
      expect(AnalyticsEvents.bucketDwellSeconds(2), 0);
      expect(AnalyticsEvents.bucketDwellSeconds(3), 3);
      expect(AnalyticsEvents.bucketDwellSeconds(5), 3);
      expect(AnalyticsEvents.bucketDwellSeconds(6), 6);
      expect(AnalyticsEvents.bucketDwellSeconds(10), 9);
    });

    test('음수는 0 반환', () {
      expect(AnalyticsEvents.bucketDwellSeconds(-1), 0);
    });

    test('60초 bucket — 분 단위 그룹', () {
      expect(AnalyticsEvents.bucketDwellSeconds(45, bucketSize: 60), 0);
      expect(AnalyticsEvents.bucketDwellSeconds(60, bucketSize: 60), 60);
      expect(AnalyticsEvents.bucketDwellSeconds(125, bucketSize: 60), 120);
    });
  });
}
