import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/running_firestore_datasource.dart';
import '../../domain/entities/running_session_entity.dart';
import '../providers/running_provider.dart';

// 러닝 기록 상세 화면 (홈 카드 탭 시 표시)
class RunningDetailPage extends ConsumerWidget {
  final RunningSessionEntity session;

  const RunningDetailPage({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── 지도 ─────────────────────────────────────────────
            SizedBox(
              height: 240,
              child: _buildRouteMap(session),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 날짜 + 지역 ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(session.startTime),
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (session.region.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.region,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── 거리 + 시간 (2열) ─────────────────────────
                  Row(
                    children: [
                      _DetailStatBox(
                        label: '거리',
                        value: '${session.distanceKm.toStringAsFixed(2)} km',
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      _DetailStatBox(
                        label: '시간',
                        value: _formatTime(session.durationSeconds),
                        color: context.colors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ─── 심박수 + 칼로리 (2열) ─────────────────────
                  Row(
                    children: [
                      _DetailStatBox(
                        label: '평균 심박수',
                        value: session.avgHeartRate > 0
                            ? '${session.avgHeartRate.round()} bpm'
                            : '-- bpm',
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      _DetailStatBox(
                        label: '칼로리',
                        value: '${session.calories.round()} kcal',
                        color: AppTheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ─── 총 포인트 보유 배너 ───────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '이 러닝에서 획득',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              '+${session.pointsEarned}P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.bolt, color: Colors.white, size: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── 구간 페이스 (있을 때만) ───────────────────
                  if (session.splitPaces.isNotEmpty) ...[
                    _SplitPacesDetail(splits: session.splitPaces),
                    const SizedBox(height: 12),
                  ],

                  // ─── 삭제 버튼 ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('삭제하기',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 삭제 확인 다이얼로그
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text('기록 삭제',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text('이 러닝 기록을 삭제하시겠어요?\n삭제하면 복구할 수 없습니다.',
            style: TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () async {
              ctx.pop();
              await _deleteSession(context, ref);
            },
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(BuildContext context, WidgetRef ref) async {
    try {
      final dataSource = ref.read(runningDataSourceProvider);
      // RunningFirestoreDataSource에만 delete 존재 (mock은 no-op)
      if (dataSource is RunningFirestoreDataSource) {
        await dataSource.deleteSession(session.id);
      }
      final user = ref.read(authProvider).valueOrNull;
      if (user != null) ref.invalidate(recentRunsProvider(user.id));
      if (context.mounted) context.go('/home');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }

  // 경로 지도
  Widget _buildRouteMap(RunningSessionEntity s) {
    if (s.routePoints.isEmpty) {
      return Container(
        color: const Color(0xFF0F1923),
        child: const Center(
          child: Text(
            '경로 정보 없음',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final points = s.routePoints
        .map((p) => ll.LatLng(p.lat, p.lng))
        .toList();

    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    return FlutterMap(
      options: MapOptions(
        initialCenter: ll.LatLng(centerLat, centerLng),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.runtify.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
              width: 14,
              height: 14,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            Marker(
              point: points.last,
              width: 14,
              height: 14,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ($wd) $h:$m';
  }
}

// 스탯 박스 (2열 레이아웃)
class _DetailStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 구간 페이스 섹션
class _SplitPacesDetail extends StatelessWidget {
  final List<SplitPace> splits;

  const _SplitPacesDetail({required this.splits});

  String _paceStr(double pace) {
    if (pace <= 0) return "--'--\"";
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구간별 페이스',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...splits.map(
            (split) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${split.km} km',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _paceStr(split.pace),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
