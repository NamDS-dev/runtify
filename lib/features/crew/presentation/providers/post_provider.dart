// 크루 게시글 Riverpod Provider
// Phase: 크루 소셜 기능

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/post_entity.dart';
import 'crew_provider.dart';

// 크루 게시글 목록 (실시간 스트림)
final crewPostsProvider =
    StreamProvider.family<List<PostEntity>, String>((ref, crewId) {
  final datasource = ref.read(crewDataSourceProvider);
  return datasource.watchPosts(crewId);
});
