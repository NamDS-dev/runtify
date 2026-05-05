import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/services/stats_aggregator.dart';
import '../providers/running_provider.dart';

/// 주간/월간 러닝 통계 페이지 — 합계 거리·평균 페이스·횟수 + 막대 그래프.
class StatsPage extends ConsumerStatefulWidget {
  final String userId;
  const StatsPage({super.key, required this.userId});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  StatsRange _range = StatsRange.weekly;

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(recentRunsProvider(widget.userId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(recentRunsProvider(widget.userId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RangeToggle(
              value: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 16),
            runsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, inline: true),
              data: (sessions) {
                final summary = StatsSummary.aggregate(
                  sessions: sessions,
                  range: _range,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(summary: summary, range: _range),
                    const SizedBox(height: 16),
                    Text(
                      _range == StatsRange.weekly ? '일별 거리' : '주차별 거리',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: summary.totalDistanceKm == 0
                          ? Center(
                              child: Text(
                                '이 기간에 러닝 기록이 없어요',
                                style: TextStyle(
                                    color: context.colors.textSecondary),
                              ),
                            )
                          : _DistanceBarChart(bars: summary.bars),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final StatsRange value;
  final ValueChanged<StatsRange> onChanged;

  const _RangeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: '주간',
            isSelected: value == StatsRange.weekly,
            onTap: () => onChanged(StatsRange.weekly),
          ),
          _ToggleButton(
            label: '월간',
            isSelected: value == StatsRange.monthly,
            onTap: () => onChanged(StatsRange.monthly),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final StatsSummary summary;
  final StatsRange range;
  const _SummaryCard({required this.summary, required this.range});

  String _formatPace(double p) {
    if (p <= 0) return "--'--\"";
    final m = p.floor();
    final s = ((p - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final periodLabel = range == StatsRange.weekly ? '이번 주' : '이번 달';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$periodLabel 요약',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryStat(
                label: '총 거리',
                value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
              ),
              _SummaryStatDivider(),
              _SummaryStat(
                label: '횟수',
                value: '${summary.runCount}회',
              ),
              _SummaryStatDivider(),
              _SummaryStat(
                label: '평균 페이스',
                value: _formatPace(summary.avgPaceMinPerKm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: context.colors.textSecondary.withValues(alpha: 0.2),
    );
  }
}

class _DistanceBarChart extends StatelessWidget {
  final List<StatsBar> bars;

  const _DistanceBarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final maxVal = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    final yMax = maxVal < 1 ? 1.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        maxY: yMax,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= bars.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    bars[i].label,
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
        barGroups: List.generate(
          bars.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bars[i].value,
                color: AppTheme.primary,
                width: bars.length <= 7 ? 18 : 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
