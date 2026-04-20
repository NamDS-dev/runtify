// 크루 멤버 관리 화면 (리더 전용)
// 가입 대기 목록 (승인/거절) + 현재 멤버 (퇴출)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/crew_entity.dart';
import '../providers/crew_provider.dart';

class CrewMemberManagePage extends ConsumerWidget {
  final CrewEntity crew;

  const CrewMemberManagePage({super.key, required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRequestsProvider(crew.id));
    final membersAsync = ref.watch(crewMembersProvider(crew.memberIds));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('멤버 관리'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 가입 대기 섹션 ──────────────────────────────────
            pendingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (requests) {
                if (requests.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      '대기 중인 가입 신청이 없습니다',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가입 대기 (${requests.length}명)',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...requests.map((request) => _PendingCard(
                          request: request,
                          crewId: crew.id,
                          ref: ref,
                          context: context,
                        )),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // ── 현재 멤버 섹션 ──────────────────────────────────
            membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('멤버 조회 실패: $e'),
              data: (members) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 멤버 (${members.length}명)',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...members.asMap().entries.map((entry) {
                    final index = entry.key;
                    final member = entry.value;
                    final isCrewLeader = member.id == crew.leaderId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: index == 0 ? const Color(0xFFFFD700) : context.colors.textSecondary,
                                fontWeight: FontWeight.bold, fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(children: [
                              Text(member.name, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w500)),
                              if (isCrewLeader) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFFFD700)),
                              ],
                            ]),
                          ),
                          Text('${member.points}P', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (!isCrewLeader) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _showKickDialog(context, ref, member.id, member.name),
                              child: const Icon(Icons.close, size: 18, color: Color(0xFFFF3333)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKickDialog(BuildContext context, WidgetRef ref, String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('멤버 퇴출', style: TextStyle(color: Colors.white)),
        content: Text('$memberName님을 크루에서 퇴출하시겠습니까?', style: const TextStyle(color: Color(0xFF9E9E9E))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(crewActionsProvider.notifier).kickMember(crewId: crew.id, memberId: memberId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$memberName님이 퇴출되었습니다', textAlign: TextAlign.center),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ));
              }
            },
            child: const Text('퇴출하기', style: TextStyle(color: Color(0xFFFF3333))),
          ),
        ],
      ),
    );
  }
}

// 가입 대기 카드
class _PendingCard extends StatelessWidget {
  final dynamic request;
  final String crewId;
  final WidgetRef ref;
  final BuildContext context;

  const _PendingCard({
    required this.request,
    required this.crewId,
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext buildContext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: buildContext.colors.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_timeAgo(request.requestedAt), style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
              ],
            ),
          ),
          // 승인 버튼
          GestureDetector(
            onTap: () => _approve(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('승인', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          // 거절 버튼
          GestureDetector(
            onTap: () => _reject(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('거절', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    try {
      final datasource = ref.read(crewDataSourceProvider);
      await datasource.approveJoinRequest(crewId: crewId, userId: request.userId);
      ref.invalidate(pendingRequestsProvider(crewId));
      ref.invalidate(crewDetailProvider(crewId));
      ref.invalidate(crewMembersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${request.userName}님의 가입을 승인했습니다', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('승인 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject() async {
    try {
      final datasource = ref.read(crewDataSourceProvider);
      await datasource.rejectJoinRequest(crewId: crewId, userId: request.userId);
      ref.invalidate(pendingRequestsProvider(crewId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${request.userName}님의 가입을 거절했습니다', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFFF3333),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('거절 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 신청';
    if (diff.inHours < 24) return '${diff.inHours}시간 전 신청';
    return '${diff.inDays}일 전 신청';
  }
}
