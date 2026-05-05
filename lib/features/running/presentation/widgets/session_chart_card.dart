import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/running_sample.dart';

/// 결과/상세 페이지의 페이스·고도·심박 라인 차트 카드.
///
/// 탭 전환 — 페이스(분/km, 낮을수록 좋음 → 라인은 위로 갈수록 페이스 빠름이 직관적이지 않으므로 그대로 표시),
/// 고도(m, 영역 차트), 심박(bpm, 영역 차트).
class SessionChartCard extends StatefulWidget {
  final List<RunningSample> samples;

  const SessionChartCard({super.key, required this.samples});

  @override
  State<SessionChartCard> createState() => _SessionChartCardState();
}

enum _ChartTab { pace, elevation, heartRate }

class _SessionChartCardState extends State<SessionChartCard> {
  _ChartTab _tab = _ChartTab.pace;

  @override
  Widget build(BuildContext context) {
    if (widget.samples.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartTabBar(
            current: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: switch (_tab) {
              _ChartTab.pace => _LineChart(
                  samples: widget.samples,
                  yExtractor: (s) => s.paceMinPerKm,
                  color: AppTheme.secondary,
                  yLabel: '분/km',
                  invert: true, // 페이스는 낮을수록 좋음 → y축 반전
                  ignoreZeros: true,
                ),
              _ChartTab.elevation => _LineChart(
                  samples: widget.samples,
                  yExtractor: (s) => s.altitudeM,
                  color: AppTheme.accent,
                  yLabel: 'm',
                  filled: true,
                ),
              _ChartTab.heartRate => _LineChart(
                  samples: widget.samples,
                  yExtractor: (s) => s.heartRate,
                  color: const Color(0xFFFF3333),
                  yLabel: 'bpm',
                  filled: true,
                  ignoreZeros: true,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _ChartTabBar extends StatelessWidget {
  final _ChartTab current;
  final ValueChanged<_ChartTab> onChanged;

  const _ChartTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(label: '페이스', tab: _ChartTab.pace, current: current, onChanged: onChanged),
        const SizedBox(width: 8),
        _Tab(label: '고도', tab: _ChartTab.elevation, current: current, onChanged: onChanged),
        const SizedBox(width: 8),
        _Tab(label: '심박수', tab: _ChartTab.heartRate, current: current, onChanged: onChanged),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final _ChartTab tab;
  final _ChartTab current;
  final ValueChanged<_ChartTab> onChanged;

  const _Tab({
    required this.label,
    required this.tab,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == tab;
    return GestureDetector(
      onTap: () => onChanged(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : context.colors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : context.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// 단일 라인(또는 영역) 차트 — fl_chart LineChart 래퍼.
class _LineChart extends StatelessWidget {
  final List<RunningSample> samples;
  final double Function(RunningSample) yExtractor;
  final Color color;
  final String yLabel;
  final bool filled;
  /// 페이스용 — 낮을수록 좋음 → y축 반전(rotated chart 흉내)
  final bool invert;
  /// 0인 샘플 무시 (BLE 미연결 시 hr=0, 페이스 0)
  final bool ignoreZeros;

  const _LineChart({
    required this.samples,
    required this.yExtractor,
    required this.color,
    required this.yLabel,
    this.filled = false,
    this.invert = false,
    this.ignoreZeros = false,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (final s in samples) {
      final y = yExtractor(s);
      if (ignoreZeros && y <= 0) continue;
      spots.add(FlSpot(s.elapsedSeconds.toDouble(), y));
    }

    if (spots.length < 2) {
      return Center(
        child: Text(
          '데이터 부족',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      );
    }

    final minY = spots.fold<double>(double.infinity, (m, s) => s.y < m ? s.y : m);
    final maxY = spots.fold<double>(-double.infinity, (m, s) => s.y > m ? s.y : m);
    final padding = (maxY - minY).abs() * 0.1 + 0.5;

    return LineChart(
      LineChartData(
        minY: invert ? maxY + padding : (minY - padding).clamp(0, double.infinity),
        maxY: invert ? (minY - padding).clamp(0, double.infinity) : maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).abs().clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.colors.textSecondary.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final m = (value ~/ 60).toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${m}m',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: filled
                ? BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
