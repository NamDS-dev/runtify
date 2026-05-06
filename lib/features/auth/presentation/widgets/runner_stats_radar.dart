import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/runner_stats.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../running/domain/entities/running_session_entity.dart';

/// 러너 능력치 레이더 차트 — 속도/지구력/꾸준함 3축 (가설 2 — 2026-05-06).
///
/// 데이터가 비어있거나 단일 세션이면 빈 상태 안내. 그 외에는 fl_chart RadarChart.
class RunnerStatsRadar extends StatelessWidget {
  final List<RunningSessionEntity> sessions;

  const RunnerStatsRadar({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final speed = RunnerStats.calcSpeedScore(sessions);
    final endurance = RunnerStats.calcEnduranceScore(sessions);
    final consistency = RunnerStats.calcConsistencyScore(sessions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '러너 능력치',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '러닝 기록이 쌓이면 능력치가 표시됩니다',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: RadarChart(
                RadarChartData(
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData: BorderSide(
                    color: context.colors.textSecondary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  gridBorderData: BorderSide(
                    color: context.colors.textSecondary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  tickBorderData: BorderSide.none,
                  ticksTextStyle:
                      const TextStyle(color: Colors.transparent, fontSize: 10),
                  tickCount: 4,
                  titlePositionPercentageOffset: 0.2,
                  titleTextStyle: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  getTitle: (i, angle) {
                    const labels = ['속도', '지구력', '꾸준함'];
                    return RadarChartTitle(text: labels[i]);
                  },
                  dataSets: [
                    RadarDataSet(
                      fillColor: AppTheme.primary.withValues(alpha: 0.3),
                      borderColor: AppTheme.primary,
                      borderWidth: 2,
                      entryRadius: 3,
                      dataEntries: [
                        RadarEntry(value: speed),
                        RadarEntry(value: endurance),
                        RadarEntry(value: consistency),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 점수 텍스트 (접근성 + 차트 미지원 환경 폴백)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ScoreLabel(label: '속도', score: speed),
              _ScoreLabel(label: '지구력', score: endurance),
              _ScoreLabel(label: '꾸준함', score: consistency),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  final String label;
  final double score;
  const _ScoreLabel({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          score.round().toString(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
