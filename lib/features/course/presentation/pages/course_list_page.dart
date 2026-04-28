// 인기 코스 목록 화면 — 지역별 코스 리스트
// Phase 8: 런닝 코스 저장 & 공유

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/entities/course_entity.dart';
import '../providers/course_provider.dart';

class CourseListPage extends ConsumerStatefulWidget {
  const CourseListPage({super.key});

  @override
  ConsumerState<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends ConsumerState<CourseListPage> {
  String _filterRegion = ''; // 빈 문자열 = 전체

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesByRegionProvider(_filterRegion));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('인기 코스'),
        actions: [
          // 지역 필터 버튼
          TextButton.icon(
            onPressed: _showRegionFilter,
            icon: const Icon(Icons.location_on, size: 16, color: AppTheme.primary),
            label: Text(
              _filterRegion.isEmpty ? '전체' : _filterRegion,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    '아직 등록된 코스가 없어요',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '러닝 완료 후 코스를 저장해보세요!',
                    style: TextStyle(
                      color: context.colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _CourseCard(
                course: courses[index],
                onTap: () => context.push('/courses/${courses[index].id}'),
              );
            },
          );
        },
      ),
    );
  }

  // 지역 필터 선택 (간단한 다이얼로그)
  void _showRegionFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '지역 필터',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 전체 보기
            ListTile(
              title: const Text('전체', style: TextStyle(color: Colors.white)),
              leading: Icon(
                _filterRegion.isEmpty ? Icons.check_circle : Icons.circle_outlined,
                color: _filterRegion.isEmpty ? AppTheme.primary : Colors.grey,
              ),
              onTap: () {
                setState(() => _filterRegion = '');
                Navigator.pop(context);
              },
            ),
            // TODO: 유저의 homeRegionGu 기반 추천 지역 추가
          ],
        ),
      ),
    );
  }
}

// 코스 카드
class _CourseCard extends StatelessWidget {
  final CourseEntity course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🗺️ ${course.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${course.distanceKm.toStringAsFixed(1)}km · ${course.difficultyStars} · 🏃 ${course.runCount}회 달림',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${course.creatorName} · ${course.regionGu}',
                    style: TextStyle(
                      color: context.colors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: context.colors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
