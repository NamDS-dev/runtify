// 코스 상세 화면 — 지도 + 통계 + "이 코스로 달리기"
// Phase 8: 런닝 코스 저장 & 공유

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/course_entity.dart';
import '../providers/course_provider.dart';

class CourseDetailPage extends ConsumerWidget {
  final String courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('코스 상세'),
      ),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (course) {
          if (course == null) {
            return const Center(child: Text('코스를 찾을 수 없습니다'));
          }
          return _CourseDetailBody(course: course);
        },
      ),
    );
  }
}

class _CourseDetailBody extends StatelessWidget {
  final CourseEntity course;

  const _CourseDetailBody({required this.course});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지도 (경로 표시)
          SizedBox(
            height: 280,
            child: _buildRouteMap(),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 코스 이름
                Text(
                  course.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // 메타 정보
                Text(
                  'by ${course.creatorName} · ${course.regionGu} · ${_formatDate(course.createdAt)}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),

                // 통계 카드 (거리 / 난이도 / 달린 횟수)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: context.colors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                        value: '${course.distanceKm.toStringAsFixed(1)}km',
                        label: '거리',
                        color: AppTheme.primary,
                      ),
                      _StatItem(
                        value: course.difficultyStars,
                        label: '난이도',
                        color: AppTheme.accent,
                      ),
                      _StatItem(
                        value: '${course.runCount}회',
                        label: '달린 횟수',
                        color: AppTheme.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CTA 버튼 — "이 코스로 달리기"
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // 러닝 화면으로 이동 (가이드 경로 전달)
                      context.push('/running', extra: {
                        'guideCourse': course,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('🏃 이 코스로 달리기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 경로 지도
  Widget _buildRouteMap() {
    if (course.routePoints.isEmpty) {
      return Container(
        color: const Color(0xFF0F1923),
        child: const Center(
          child: Text('경로 없음', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final points = course.routePoints
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
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// 통계 아이템
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
