// 코스 Riverpod Provider — 코스 목록/상세 조회
// Phase 8: 런닝 코스 저장 & 공유

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/course_firestore_datasource.dart';
import '../../domain/entities/course_entity.dart';

// 코스 데이터소스 Provider
final courseDatasourceProvider = Provider<CourseFirestoreDatasource>((ref) {
  return CourseFirestoreDatasource();
});

// 지역별 코스 목록 (regionGu로 필터, 빈 문자열이면 전체)
final coursesByRegionProvider =
    FutureProvider.family<List<CourseEntity>, String>((ref, regionGu) {
  final datasource = ref.read(courseDatasourceProvider);
  return datasource.getCoursesByRegion(regionGu);
});

// 코스 상세 조회
final courseDetailProvider =
    FutureProvider.family<CourseEntity?, String>((ref, courseId) {
  final datasource = ref.read(courseDatasourceProvider);
  return datasource.getCourse(courseId);
});
