// 크루 이벤트 목록 + 생성 BottomSheet
// 그룹 러닝 모집 — Strava Club Event 패턴

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/content_validator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/crew_entity.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/crew_provider.dart';
import '../providers/event_provider.dart';

class CrewEventPage extends ConsumerWidget {
  final CrewEntity crew;

  const CrewEventPage({super.key, required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(crewEventsProvider(crew.id));
    final user = ref.watch(authProvider).valueOrNull;
    final isLeader = user != null && crew.leaderId == user.id;
    final isMember = user != null && crew.memberIds.contains(user.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('크루 이벤트'),
      ),
      // 리더에게만 이벤트 만들기 FAB
      floatingActionButton: isLeader
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              onPressed: () => _showCreateEventSheet(context, ref, crew.id, user.id),
              child: const Text('📅', style: TextStyle(fontSize: 24)),
            )
          : null,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📅', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('아직 이벤트가 없어요',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    isLeader ? '첫 번째 이벤트를 만들어보세요!' : '크루 리더가 곧 이벤트를 만들 거예요!',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          // 다가오는 / 지난 이벤트 분리
          final upcoming = events.where((e) => e.isUpcoming).toList();
          final past = events.where((e) => !e.isUpcoming).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 다가오는 이벤트
                if (upcoming.isNotEmpty) ...[
                  const Text('다가오는 이벤트',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...upcoming.map((event) => _EventCard(
                        event: event,
                        userId: user?.id ?? '',
                        crewId: crew.id,
                        isMember: isMember,
                        isUpcoming: true,
                      )),
                  const SizedBox(height: 24),
                ],

                // 지난 이벤트
                if (past.isNotEmpty) ...[
                  Text('지난 이벤트',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...past.map((event) => _EventCard(
                        event: event,
                        userId: user?.id ?? '',
                        crewId: crew.id,
                        isMember: isMember,
                        isUpcoming: false,
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // 이벤트 생성 BottomSheet
  void _showCreateEventSheet(BuildContext context, WidgetRef ref, String crewId, String userId) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    int selectedHour = 7;
    int selectedMinute = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 핸들바
                Center(child: Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                const Text('📅 이벤트 만들기',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // 이벤트 제목
                Text('이벤트 제목', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  maxLength: 30,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '예) 토요 한강 러닝',
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: const Color(0xFF252525),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 12),

                // 날짜 (캘린더)
                Text('날짜', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '📅 ${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일 (${_weekday(selectedDate)})',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 시간 (CupertinoPicker)
                Text('시간', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showTimePicker(context, selectedHour, selectedMinute, (h, m) {
                    setSheetState(() {
                      selectedHour = h;
                      selectedMinute = m;
                    });
                  }),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⏰ ${selectedHour < 12 ? "오전" : "오후"} ${selectedHour == 0 ? 12 : selectedHour > 12 ? selectedHour - 12 : selectedHour}:${selectedMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 장소
                Text('장소', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '예) 반포한강공원 주차장 앞',
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: const Color(0xFF252525),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // 이벤트 만들기 버튼
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final location = locationController.text.trim();

                      // 검증
                      final titleError = ContentValidator.validatePost(title);
                      if (title.isEmpty || titleError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(titleError ?? '이벤트 제목을 입력해주세요', textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFFF3333),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        ));
                        return;
                      }

                      if (location.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('장소를 입력해주세요', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFFF3333),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        ));
                        return;
                      }

                      // 날짜 + 시간 합치기
                      final eventDate = DateTime(
                        selectedDate.year, selectedDate.month, selectedDate.day,
                        selectedHour, selectedMinute,
                      );

                      final datasource = ref.read(crewDataSourceProvider);
                      await datasource.createEvent(
                        crewId: crewId,
                        title: ContentValidator.sanitize(title),
                        date: eventDate,
                        locationName: ContentValidator.sanitize(location),
                        createdBy: userId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('이벤트가 생성되었습니다!', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('이벤트 만들기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 시간 휠 피커 BottomSheet
  void _showTimePicker(BuildContext context, int initHour, int initMinute, void Function(int h, int m) onSelected) {
    int tempHour = initHour;
    int tempMinute = initMinute;
    final hourController = FixedExtentScrollController(initialItem: initHour);
    final minuteController = FixedExtentScrollController(initialItem: initMinute ~/ 5); // 5분 단위

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState2) => Container(
          height: 320,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // 시 : 분 피커
              Expanded(
                child: Row(
                  children: [
                    // 시 (0~23)
                    Expanded(child: CupertinoPicker(
                      scrollController: hourController,
                      itemExtent: 40,
                      selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                      onSelectedItemChanged: (i) => setState2(() => tempHour = i),
                      children: List.generate(24, (i) => Center(child: Text(
                        '${i < 12 ? "오전" : "오후"} ${i == 0 ? 12 : i > 12 ? i - 12 : i}시',
                        style: TextStyle(color: i == tempHour ? AppTheme.primary : Colors.white70, fontSize: i == tempHour ? 17 : 15, fontWeight: i == tempHour ? FontWeight.bold : FontWeight.normal),
                      ))),
                    )),
                    // 분 (0, 5, 10, ..., 55)
                    Expanded(child: CupertinoPicker(
                      scrollController: minuteController,
                      itemExtent: 40,
                      selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                      onSelectedItemChanged: (i) => setState2(() => tempMinute = i * 5),
                      children: List.generate(12, (i) => Center(child: Text(
                        '${(i * 5).toString().padLeft(2, '0')}분',
                        style: TextStyle(color: i * 5 == tempMinute ? AppTheme.primary : Colors.white70, fontSize: i * 5 == tempMinute ? 17 : 15, fontWeight: i * 5 == tempMinute ? FontWeight.bold : FontWeight.normal),
                      ))),
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                  onPressed: () { onSelected(tempHour, tempMinute); Navigator.pop(ctx); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('선택 완료'),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekday(DateTime dt) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[dt.weekday - 1];
  }
}

// ── 이벤트 카드 ──────────────────────────────────────────────────────────
class _EventCard extends ConsumerWidget {
  final CrewEventEntity event;
  final String userId;
  final String crewId;
  final bool isMember;
  final bool isUpcoming;

  const _EventCard({
    required this.event,
    required this.userId,
    required this.crewId,
    required this.isMember,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isJoined = event.isJoinedBy(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUpcoming ? context.colors.cardColor : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜
          Text(
            _formatDate(event.date, isUpcoming),
            style: TextStyle(
              color: isUpcoming ? AppTheme.primary : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // 제목
          Text(
            isUpcoming ? '🏃 ${event.title}' : event.title,
            style: TextStyle(
              color: isUpcoming ? Colors.white : context.colors.textSecondary,
              fontSize: isUpcoming ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // 장소 + 참가자
          if (event.locationName.isNotEmpty)
            Text(
              '📍 ${event.locationName}',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(
            '👥 ${event.participantCount}명 참가',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),

          // 참가하기 버튼 (다가오는 이벤트 + 멤버만)
          if (isUpcoming && isMember) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(crewDataSourceProvider).toggleEventParticipation(
                    crewId: crewId,
                    eventId: event.id,
                    userId: userId,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isJoined ? context.colors.surface : AppTheme.primary,
                  foregroundColor: isJoined ? context.colors.textSecondary : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isJoined ? '참가 취소' : '참가하기',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt, bool upcoming) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final dayStr = days[dt.weekday - 1];
    final ampm = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;

    if (upcoming) {
      return '${dt.month}월 ${dt.day}일 ($dayStr) $ampm $hour:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}월 ${dt.day}일 ($dayStr) · 완료';
  }
}
