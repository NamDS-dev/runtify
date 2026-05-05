import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lap_data.dart';

/// 1km 자동 분할 랩 테이블 — 결과/상세 페이지용.
///
/// 컬럼: KM · 시간 · 페이스 · 심박. 가장 빠른 랩(최저 페이스)은 Primary 컬러로 강조.
class LapTable extends StatelessWidget {
  final List<LapData> laps;

  const LapTable({super.key, required this.laps});

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) return const SizedBox.shrink();

    // 가장 빠른 랩 찾기 (pace 가 양수인 것 중 최저)
    LapData? fastest;
    for (final l in laps) {
      if (l.pace > 0 && (fastest == null || l.pace < fastest.pace)) {
        fastest = l;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '랩 (1km)',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // 헤더
          _LapHeaderRow(),
          const SizedBox(height: 4),
          Divider(
            color: context.colors.textSecondary.withValues(alpha: 0.2),
            height: 1,
          ),
          // 데이터 행
          ...laps.map((l) => _LapRow(
                lap: l,
                isFastest: fastest != null && l.km == fastest.km,
              )),
        ],
      ),
    );
  }
}

class _LapHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.colors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('KM', style: style)),
          Expanded(child: Text('시간', style: style)),
          Expanded(child: Text('페이스', style: style)),
          SizedBox(width: 64, child: Text('심박', style: style, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  final LapData lap;
  final bool isFastest;

  const _LapRow({required this.lap, required this.isFastest});

  @override
  Widget build(BuildContext context) {
    final color = isFastest ? AppTheme.primary : context.colors.textPrimary;
    final weight = isFastest ? FontWeight.bold : FontWeight.normal;
    final style = TextStyle(color: color, fontSize: 13, fontWeight: weight);

    final hrText =
        lap.avgHeartRate > 0 ? '${lap.avgHeartRate.round()} bpm' : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Row(
              children: [
                Text('${lap.km}', style: style),
                if (isFastest) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.flash_on,
                    color: AppTheme.primary,
                    size: 12,
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: Text(lap.formattedSplitTime, style: style)),
          Expanded(child: Text(lap.formattedPace, style: style)),
          SizedBox(
            width: 64,
            child: Text(hrText, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
