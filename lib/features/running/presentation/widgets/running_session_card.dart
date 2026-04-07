import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/running_session_entity.dart';

// 러닝 기록 카드 위젯
class RunningSessionCard extends StatelessWidget {
  final RunningSessionEntity session;

  const RunningSessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final minutes = session.durationSeconds ~/ 60;
    final seconds = session.durationSeconds % 60;

    return GestureDetector(
      // 탭하면 러닝 상세 페이지로 이동 (session을 extra로 전달)
      onTap: () => context.go('/running/detail', extra: session),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 러닝 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_run,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // 거리 + 날짜
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.distanceKm.toStringAsFixed(2)} km',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.startTime.month}/${session.startTime.day} · '
                  '$minutes분 ${seconds.toString().padLeft(2, '0')}초 · '
                  '${session.avgPaceMinPerKm.toStringAsFixed(2)}/km',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                // 심박수 데이터가 있을 때만 표시 (갤럭시 워치 연동 시 채워짐)
                if (session.avgHeartRate > 0)
                  Text(
                    '❤️ ${session.avgHeartRate.round()}bpm · '
                    '🔥 ${session.calories.round()}kcal',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // 획득 포인트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${session.pointsEarned}P',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
