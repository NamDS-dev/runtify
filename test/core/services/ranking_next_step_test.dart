import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/ranking_next_step.dart';

void main() {
  group('RankingNextStep.calc', () {
    test('1위면 null', () {
      final result = RankingNextStep.calc(
        myRank: 1,
        myPoints: 1000,
        sortedTotalPoints: [1000, 800, 500],
      );
      expect(result, null);
    });

    test('순위권 밖 (-1) → null', () {
      final result = RankingNextStep.calc(
        myRank: -1,
        myPoints: 0,
        sortedTotalPoints: [1000, 800, 500],
      );
      expect(result, null);
    });

    test('빈 sortedTotalPoints → null', () {
      final result = RankingNextStep.calc(
        myRank: 2,
        myPoints: 100,
        sortedTotalPoints: [],
      );
      expect(result, null);
    });

    test('2위 → 1위까지 gap', () {
      // 1위 1000P / 2위 800P → gap 200P = 20km
      final result = RankingNextStep.calc(
        myRank: 2,
        myPoints: 800,
        sortedTotalPoints: [1000, 800, 500],
      );
      expect(result, isNotNull);
      expect(result!.gapKm, 20.0);
      expect(result.targetRank, 1);
    });

    test('5위 → 4위까지 gap', () {
      // 4위 600P / 5위 500P → gap 100P = 10km
      final result = RankingNextStep.calc(
        myRank: 5,
        myPoints: 500,
        sortedTotalPoints: [1000, 900, 800, 600, 500, 400],
      );
      expect(result, isNotNull);
      expect(result!.gapKm, 10.0);
      expect(result.targetRank, 4);
    });

    test('동점 (gap = 0) → null', () {
      final result = RankingNextStep.calc(
        myRank: 2,
        myPoints: 800,
        sortedTotalPoints: [800, 800, 500],
      );
      expect(result, null);
    });

    test('1포인트 차이 → 0.1km', () {
      final result = RankingNextStep.calc(
        myRank: 2,
        myPoints: 999,
        sortedTotalPoints: [1000, 999, 500],
      );
      expect(result!.gapKm, closeTo(0.1, 0.001));
    });

    test('myRank 가 sortedTotalPoints 길이보다 크면 null', () {
      final result = RankingNextStep.calc(
        myRank: 100,
        myPoints: 0,
        sortedTotalPoints: [1000, 800],
      );
      expect(result, null);
    });
  });
}
