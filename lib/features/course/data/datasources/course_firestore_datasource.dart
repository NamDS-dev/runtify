// 코스 Firestore 데이터소스 — 코스 CRUD + 지역별 조회
// Phase 8: 런닝 코스 저장 & 공유

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/course_entity.dart';

class CourseFirestoreDatasource {
  final FirebaseFirestore _firestore;

  CourseFirestoreDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      _firestore.collection('courses');

  // ── 코스 저장 ──────────────────────────────────────────────────
  Future<CourseEntity> saveCourse(CourseEntity course) async {
    final docRef = _coursesRef.doc(course.id);
    await docRef.set(course.toFirestore());
    return course;
  }

  // ── 지역별 인기 코스 목록 (runCount 내림차순, 최대 20개) ──────
  Future<List<CourseEntity>> getCoursesByRegion(String regionGu) async {
    Query<Map<String, dynamic>> query = _coursesRef;

    // 지역 필터 (빈 문자열이면 전체)
    if (regionGu.isNotEmpty) {
      query = query.where('regionGu', isEqualTo: regionGu);
    }

    final snapshot = await query
        .orderBy('runCount', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => CourseEntity.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // ── 코스 상세 조회 ────────────────────────────────────────────
  Future<CourseEntity?> getCourse(String courseId) async {
    final doc = await _coursesRef.doc(courseId).get();
    if (!doc.exists) return null;
    return CourseEntity.fromFirestore(doc.data()!, doc.id);
  }

  // ── 코스 달린 횟수 증가 ───────────────────────────────────────
  Future<void> incrementRunCount(String courseId) async {
    await _coursesRef.doc(courseId).update({
      'runCount': FieldValue.increment(1),
    });
  }
}
