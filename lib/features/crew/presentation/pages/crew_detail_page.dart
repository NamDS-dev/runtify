import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/korea_regions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/content_validator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/crew_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/challenge_provider.dart';
import '../providers/crew_provider.dart';
import '../providers/post_provider.dart';

// 크루 상세 화면
// 라우터에서 extra: CrewEntity로 전달받음
class CrewDetailPage extends ConsumerWidget {
  final CrewEntity crew;

  const CrewDetailPage({super.key, required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    // 크루 상세 데이터를 실시간 갱신 (가입/탈퇴 후 반영)
    final crewAsync = ref.watch(crewDetailProvider(crew.id));

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox());

        // 최신 크루 데이터 (없으면 전달받은 초기 데이터 사용)
        final currentCrew = crewAsync.valueOrNull ?? crew;

        // 멤버 정보 조회 — 최신 memberIds 기준으로 조회 (가입/탈퇴 후 갱신 반영)
        final membersAsync = ref.watch(crewMembersProvider(currentCrew.memberIds));
        final isMember = currentCrew.memberIds.contains(user.id);
        final isLeader = currentCrew.leaderId == user.id;
        final isFull = currentCrew.memberCount >= currentCrew.maxMembers;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
          appBar: AppBar(
            title: Text(currentCrew.name),
            actions: [
              if (isLeader) ...[
                IconButton(
                  icon: const Icon(Icons.people_outline, size: 20),
                  onPressed: () => context.push('/crew/members', extra: currentCrew),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditSheet(context, ref, currentCrew),
                ),
              ],
            ],
            bottom: TabBar(
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: context.colors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: '정보'),
                Tab(text: '게시글'),
                Tab(text: '멤버'),
              ],
            ),
          ),
          // 게시글 탭에서 글쓰기 FAB 표시 (멤버만)
          floatingActionButton: isMember
              ? Builder(builder: (ctx) {
                  return FloatingActionButton(
                    backgroundColor: AppTheme.primary,
                    onPressed: () => _showWritePostSheet(ctx, ref, currentCrew.id, user.id, user.name),
                    child: const Icon(Icons.edit, color: Colors.white),
                  );
                })
              : null,
          body: TabBarView(
            children: [
              // ── 탭 1: 정보 ──────────────────────────────────
              SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 크루 기본 정보 카드 ────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 크루명
                      Text(
                        currentCrew.name,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 지역 + 멤버수
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            currentCrew.region,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.group_outlined,
                              size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            '${currentCrew.memberCount}/${currentCrew.maxMembers}명',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // 이번 달 크루 포인트
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            '이번 달 ${currentCrew.crewPoints}P',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),

                      // 소개글
                      if (currentCrew.description != null &&
                          currentCrew.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          currentCrew.description!,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 위클리 챌린지 섹션 카드 ───────────────────────────
                _WeeklyChallengeCard(
                  crew: currentCrew,
                ),
                const SizedBox(height: 12),

                // ── 크루 이벤트 진입 카드 ────────────────────────────
                GestureDetector(
                  onTap: () => context.push('/crew/events', extra: currentCrew),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('📅', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('크루 이벤트', style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('그룹 러닝을 만들어보세요!', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: context.colors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 가입 / 탈퇴 버튼 ──────────────────────────────────
                _ActionButton(
                  isMember: isMember,
                  isLeader: isLeader,
                  isFull: isFull,
                  hasOtherCrew: user.crewId != null &&
                      user.crewId!.isNotEmpty &&
                      user.crewId != currentCrew.id,
                  crewId: currentCrew.id,
                  crewName: currentCrew.name,
                  userId: user.id,
                  ref: ref,
                ),
                const SizedBox(height: 16),

                // 소개글 (있으면)
                if (currentCrew.description != null && currentCrew.description!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('소개', style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(currentCrew.description!, style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                ],

                // 멤버 목록은 "멤버" 탭으로 이동됨
              ],
            ),
          ),

              // ── 탭 2: 게시글 ──────────────────────────────────
              _CrewFeedTab(crewId: currentCrew.id, userId: user.id),

              // ── 탭 3: 멤버 ──────────────────────────────────
              _CrewMembersTab(
                membersAsync: membersAsync,
                currentCrew: currentCrew,
                isLeader: isLeader,
                context: context,
                ref: ref,
                showKickDialog: _showKickDialog,
              ),
            ],
          ),
        ));
      },
    );
  }

  // 글쓰기 BottomSheet
  void _showWritePostSheet(
    BuildContext context, WidgetRef ref,
    String crewId, String userId, String userName,
  ) {
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 48, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('✏️ 게시글 작성', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '크루원들에게 공유하고 싶은 이야기를\n자유롭게 작성해주세요...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFF252525),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterStyle: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final rawContent = contentController.text.trim();

                  // 입력 검증
                  final error = ContentValidator.validatePost(rawContent);
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFFF3333),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      ),
                    );
                    return;
                  }

                  // 제어 문자 정제
                  final content = ContentValidator.sanitize(rawContent);

                  final datasource = ref.read(crewDataSourceProvider);
                  await datasource.createPost(
                    crewId: crewId,
                    authorId: userId,
                    authorName: userName,
                    content: content,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('게시글이 등록되었습니다!', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('게시하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 멤버 퇴출 확인 다이얼로그 ──────────────────────────────────────────
  void _showKickDialog(
    BuildContext context, WidgetRef ref,
    String crewId, String memberId, String memberName,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('멤버 퇴출', style: TextStyle(color: Colors.white)),
        content: Text(
          '$memberName님을 크루에서 퇴출하시겠습니까?',
          style: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(crewActionsProvider.notifier).kickMember(
                crewId: crewId,
                memberId: memberId,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? '$memberName님이 퇴출되었습니다' : '퇴출 실패'),
                  backgroundColor: success ? AppTheme.primary : Colors.red,
                ));
              }
            },
            child: const Text('퇴출하기', style: TextStyle(color: Color(0xFFFF3333))),
          ),
        ],
      ),
    );
  }

  // ── 크루 정보 수정 BottomSheet (리더 전용) ─────────────────────────────
  void _showEditSheet(BuildContext context, WidgetRef ref, CrewEntity crew) {
    final nameController = TextEditingController(text: crew.name);
    final descController = TextEditingController(text: crew.description);
    int maxMembers = crew.maxMembers;

    // 현재 지역에서 시·도 / 구·군 파싱
    final regionParts = crew.region.split(' ');
    String? selectedSi = regionParts.isNotEmpty ? regionParts[0] : null;
    String? selectedGu = regionParts.length > 1 ? regionParts[1] : null;

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
                const Text('✏️ 크루 정보 수정', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // 크루 이름
                Text('크루 이름', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 20,
                  decoration: InputDecoration(
                    filled: true, fillColor: const Color(0xFF252525),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 12),

                // 활동 지역 (휠 피커)
                Text('활동 지역', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    _showRegionPickerForEdit(context, selectedSi, selectedGu, (si, gu) {
                      setSheetState(() { selectedSi = si; selectedGu = gu; });
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      selectedSi != null ? '$selectedSi $selectedGu' : '지역 선택',
                      style: TextStyle(color: selectedSi != null ? Colors.white : Colors.grey.shade600, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 크루 소개
                Text('크루 소개', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3, maxLength: 100,
                  decoration: InputDecoration(
                    filled: true, fillColor: const Color(0xFF252525),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterStyle: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 12),

                // 최대 인원
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('최대 인원: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
                      onPressed: maxMembers > 5 ? () => setSheetState(() => maxMembers--) : null,
                    ),
                    Text('$maxMembers명', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                      onPressed: maxMembers < 50 ? () => setSheetState(() => maxMembers++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 저장 버튼
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final region = selectedSi != null ? '$selectedSi $selectedGu' : crew.region;

                      final success = await ref.read(crewActionsProvider.notifier).updateCrew(
                        crewId: crew.id, name: name, region: region,
                        description: descController.text.trim(), maxMembers: maxMembers,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success ? '크루 정보가 수정되었습니다' : '수정 실패'),
                          backgroundColor: success ? AppTheme.primary : Colors.red,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('저장하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 수정용 지역 휠 피커
  void _showRegionPickerForEdit(
    BuildContext context, String? currentSi, String? currentGu,
    void Function(String si, String gu) onSelected,
  ) {
    int siIndex = currentSi != null ? koreaProvinces.indexOf(currentSi) : 0;
    if (siIndex < 0) siIndex = 0;
    List<String> guList = koreaRegions[koreaProvinces[siIndex]]!;
    int guIndex = currentGu != null ? guList.indexOf(currentGu) : 0;
    if (guIndex < 0) guIndex = 0;

    String tempSi = koreaProvinces[siIndex];
    String tempGu = guList[guIndex];
    final guController = FixedExtentScrollController(initialItem: guIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState2) => Container(
          height: 400,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Expanded(child: Row(children: [
              Expanded(child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: siIndex),
                itemExtent: 40,
                selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                onSelectedItemChanged: (i) { setState2(() { tempSi = koreaProvinces[i]; guList = koreaRegions[tempSi]!; tempGu = guList[0]; guController.jumpToItem(0); }); },
                children: koreaProvinces.map((s) => Center(child: Text(s, style: TextStyle(color: s == tempSi ? AppTheme.primary : Colors.white70, fontSize: s == tempSi ? 17 : 15, fontWeight: s == tempSi ? FontWeight.bold : FontWeight.normal)))).toList(),
              )),
              Expanded(child: CupertinoPicker(
                scrollController: guController,
                itemExtent: 40,
                selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                onSelectedItemChanged: (i) { setState2(() { if (i < guList.length) tempGu = guList[i]; }); },
                children: guList.map((g) => Center(child: Text(g, style: TextStyle(color: g == tempGu ? AppTheme.primary : Colors.white70, fontSize: g == tempGu ? 17 : 15, fontWeight: g == tempGu ? FontWeight.bold : FontWeight.normal)))).toList(),
              )),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
              onPressed: () { onSelected(tempSi, tempGu); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('선택 완료'),
            ))),
          ]),
        ),
      ),
    );
  }
}

// ── 가입 / 탈퇴 버튼 위젯 ────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final bool isMember;
  final bool isLeader;
  final bool isFull;
  final bool hasOtherCrew; // 이미 다른 크루에 가입된 상태
  final String crewId;
  final String crewName;
  final String userId;
  final WidgetRef ref;

  const _ActionButton({
    required this.isMember,
    required this.isLeader,
    required this.isFull,
    required this.hasOtherCrew,
    required this.crewId,
    required this.crewName,
    required this.userId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(crewActionsProvider);
    final isLoading = actionsState.isLoading;

    // 이미 다른 크루 가입 중
    if (hasOtherCrew) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '다른 크루에 가입 중이에요',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      );
    }

    if (isMember) {
      // 탈퇴 버튼 (리더는 탈퇴 불가)
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: (isLeader || isLoading) ? null : () => _leaveCrew(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(
              color: isLeader ? context.colors.textSecondary : Colors.red.shade400,
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isLeader ? '크루장은 탈퇴할 수 없어요' : '크루 탈퇴',
                  style: TextStyle(
                    color: isLeader ? context.colors.textSecondary : Colors.red.shade400,
                  ),
                ),
        ),
      );
    } else {
      // 가입 신청 버튼 (승인제)
      final requestAsync = ref.watch(
        joinRequestStatusProvider((crewId: crewId, userId: userId)),
      );
      final request = requestAsync.valueOrNull;
      final isPending = request?.isPending ?? false;

      if (isPending) {
        // 신청 대기 중 상태
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: context.colors.cardColor,
                  disabledBackgroundColor: context.colors.cardColor,
                ),
                child: Text(
                  '⏳ 가입 승인 대기 중',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _cancelJoinRequest(context),
              child: const Text('신청 취소', style: TextStyle(color: Color(0xFFFF3333), fontSize: 13)),
            ),
          ],
        );
      }

      // 신청 전 상태
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (isFull || isLoading) ? null : () => _requestJoinCrew(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppTheme.primary,
          ),
          child: isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  isFull ? '인원 마감' : '가입 신청하기',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
        ),
      );
    }
  }

  // 가입 신청
  Future<void> _requestJoinCrew(BuildContext context) async {
    try {
      final datasource = ref.read(crewDataSourceProvider);
      // 유저 이름 가져오기
      final user = ref.read(authProvider).valueOrNull;
      await datasource.requestJoinCrew(
        crewId: crewId,
        userId: userId,
        userName: user?.name ?? '',
      );
      // 신청 상태 갱신
      ref.invalidate(joinRequestStatusProvider((crewId: crewId, userId: userId)));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('가입 신청이 완료되었습니다!', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 가입 신청 취소
  Future<void> _cancelJoinRequest(BuildContext context) async {
    try {
      final datasource = ref.read(crewDataSourceProvider);
      await datasource.cancelJoinRequest(crewId: crewId, userId: userId);
      ref.invalidate(joinRequestStatusProvider((crewId: crewId, userId: userId)));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('가입 신청이 취소되었습니다', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFFF3333),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('취소 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveCrew(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('크루 탈퇴',
            style: TextStyle(color: context.colors.textPrimary)),
        content: Text('정말 $crewName에서 탈퇴하시겠습니까?',
            style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소',
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('탈퇴',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(crewActionsProvider.notifier).leaveCrew(
          crewId: crewId,
          userId: userId,
        );
    if (!context.mounted) return;

    if (success) {
      await ref.read(authProvider.notifier).refreshUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('크루에서 탈퇴했어요')),
      );
      Navigator.pop(context); // 상세 화면 닫기
    } else {
      final error = ref.read(crewActionsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴 실패: $error'), backgroundColor: Colors.red),
      );
    }
  }
}

// ── 위클리 챌린지 섹션 카드 ───────────────────────────────────────────────
// 크루 상세 화면에서 챌린지 화면으로 이동하는 진입점
class _WeeklyChallengeCard extends ConsumerWidget {
  final CrewEntity crew;

  const _WeeklyChallengeCard({required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 현재 active 챌린지 개수 미리 보기 (실패해도 카드 표시)
    final challengesAsync = ref.watch(challengesProvider(crew.id));

    final activeCount = challengesAsync.valueOrNull
            ?.where((c) => c.status.name == 'active')
            .length ??
        0;

    return GestureDetector(
      onTap: () => context.push('/crew/challenge', extra: crew),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '위클리 챌린지',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeCount > 0
                        ? '진행 중인 챌린지 $activeCount개'
                        : '챌린지에 도전해보세요!',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // 화살표
            Icon(
              Icons.chevron_right,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 크루 게시글 피드 탭 ──────────────────────────────────────────────────
class _CrewFeedTab extends ConsumerWidget {
  final String crewId;
  final String userId;

  const _CrewFeedTab({required this.crewId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(crewPostsProvider(crewId));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.colors.textSecondary))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💬', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('아직 게시글이 없어요', style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
                const SizedBox(height: 8),
                Text('첫 번째 게시글을 작성해보세요!', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _PostCard(post: post, userId: userId, crewId: crewId);
          },
        );
      },
    );
  }
}

// 게시글 카드
class _PostCard extends ConsumerWidget {
  final PostEntity post;
  final String userId;
  final String crewId;

  const _PostCard({required this.post, required this.userId, required this.crewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = post.isLikedBy(userId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (작성자 + 시간)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(post.authorName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(_timeAgo(post.createdAt), style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),

          // 본문
          Text(post.content, style: const TextStyle(color: Color(0xFFD9D9D9), fontSize: 14, height: 1.5)),

          // 사진 (있을 때)
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(post.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ],

          const SizedBox(height: 12),

          // 좋아요 + 댓글
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(crewDataSourceProvider).toggleLike(crewId: crewId, postId: post.id, userId: userId);
                },
                child: Text(
                  '${isLiked ? "❤️" : "🤍"} ${post.likeCount}',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 16),
              Text('💬 ${post.commentCount}', style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 크루 멤버 탭 (기존 멤버 목록 분리) ────────────────────────────────────
class _CrewMembersTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> membersAsync;
  final CrewEntity currentCrew;
  final bool isLeader;
  final BuildContext context;
  final WidgetRef ref;
  final void Function(BuildContext, WidgetRef, String, String, String) showKickDialog;

  const _CrewMembersTab({
    required this.membersAsync,
    required this.currentCrew,
    required this.isLeader,
    required this.context,
    required this.ref,
    required this.showKickDialog,
  });

  @override
  Widget build(BuildContext buildContext) {
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('멤버 조회 실패: $e')),
      data: (members) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, index) {
          final member = members[index];
          final isCrewLeader = member.id == currentCrew.leaderId;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: buildContext.colors.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index == 0 ? const Color(0xFFFFD700) : index == 1 ? const Color(0xFFC0C0C0) : index == 2 ? const Color(0xFFCD7F32) : buildContext.colors.textSecondary,
                      fontWeight: FontWeight.bold, fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(children: [
                    Text(member.name, style: TextStyle(color: buildContext.colors.textPrimary, fontWeight: FontWeight.w500)),
                    if (isCrewLeader) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFFFD700))],
                  ]),
                ),
                Text('${member.points}P', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                if (isLeader && !isCrewLeader) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => showKickDialog(context, ref, currentCrew.id, member.id, member.name),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFFFF3333)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
