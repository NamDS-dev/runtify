import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/running_session_entity.dart';

// 이번 달 통계 요약 카드
class StatsOverviewWidget extends StatelessWidget {
  final List<RunningSessionEntity> sessions;

  const StatsOverviewWidget({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    // 이번 달 데이터만 필터링
    final now = DateTime.now();
    final thisMonthSessions = sessions.where((s) =>
        s.startTime.year == now.year && s.startTime.month == now.month).toList();

    final totalDistance = thisMonthSessions.fold(
      0.0, (total, s) => total + s.distanceKm);
    final totalPoints = thisMonthSessions.fold(
      0, (total, s) => total + s.pointsEarned);
    final runCount = thisMonthSessions.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 테마에 따라 그라디언트 색상 자동 전환
        gradient: LinearGradient(
          colors: [context.colors.surface, context.colors.cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '이번 달 러닝',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${now.month}월',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: '총 거리',
                value: totalDistance.toStringAsFixed(1),
                unit: 'km',
                icon: Icons.straighten,
              ),
              _StatItem(
                label: '획득 포인트',
                value: '$totalPoints',
                unit: 'P',
                icon: Icons.bolt,
                color: AppTheme.accent,
              ),
              _StatItem(
                label: '러닝 횟수',
                value: '$runCount',
                unit: '회',
                icon: Icons.replay,
                color: AppTheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
