// 크루 이벤트 Riverpod Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event_entity.dart';
import 'crew_provider.dart';

// 크루 이벤트 목록 (실시간 스트림)
final crewEventsProvider =
    StreamProvider.family<List<CrewEventEntity>, String>((ref, crewId) {
  final datasource = ref.read(crewDataSourceProvider);
  return datasource.watchEvents(crewId);
});
