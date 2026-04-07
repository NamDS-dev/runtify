// 배지 Riverpod Provider — 배지 조회/관리
// Phase 6: 배지 & 칭호 시스템

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/badge_firestore_datasource.dart';
import '../../domain/entities/badge_entity.dart';

// 배지 데이터소스 Provider
final badgeDatasourceProvider = Provider<BadgeFirestoreDatasource>((ref) {
  return BadgeFirestoreDatasource();
});

// 유저의 획득 배지 목록 (실시간 스트림)
final earnedBadgesProvider =
    StreamProvider.family<List<EarnedBadge>, String>((ref, userId) {
  final datasource = ref.read(badgeDatasourceProvider);
  return datasource.watchEarnedBadges(userId);
});
