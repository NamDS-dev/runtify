import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../running/presentation/providers/running_provider.dart';

// ── 색상 상수 (Sunset Fire 팔레트) ──────────────────────────────────────
const _colorPrimary = Color(0xFFFF4D00);   // 주요 강조 (내 지역 하이라이트 등)
const _colorAccent = Color(0xFFFFE566);    // 경험치/레벨 등 3번째 강조
const _colorBg = Color(0xFF0D0D0D);        // 배경
const _colorCard = Color(0xFF252525);      // 카드
const _colorGold = Color(0xFFFFD700);      // 금메달
const _colorSilver = Color(0xFFC0C0C0);   // 은메달
const _colorBronze = Color(0xFFCD7F32);   // 동메달

// 페이지당 보여줄 항목 수
const _kPageSize = 10;

// ── 랭킹 페이지 (ConsumerStatefulWidget) ────────────────────────────────
class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 탭 순서: 구/군(기본) → 시·도 → 동네
  static const _tabs = [
    (label: '구/군', level: 'gu'),
    (label: '시·도', level: 'si'),
    (label: '동네', level: 'dong'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 현재 로그인한 유저 ID 조회
    final authState = ref.watch(authProvider);
    final userId = authState.valueOrNull?.id ?? '';

    // 이번 달 연/월 문자열 (예: "2025-03")
    final now = DateTime.now();
    final month =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: _colorBg,
      appBar: AppBar(
        backgroundColor: _colorBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '지역 랭킹',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _colorPrimary,
          labelColor: _colorPrimary,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: _tabs
              .map((t) => Tab(text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((t) => _RankingTab(
                  level: t.level,
                  userId: userId,
                  month: month,
                ))
            .toList(),
      ),
    );
  }
}

// ── 유저 지역 정보 Provider (users/{userId} 문서에서 읽기) ────────────────
final _userRegionProvider =
    FutureProvider.family<Map<String, String?>, String>((ref, userId) async {
  if (userId.isEmpty) return {};

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();

  if (!doc.exists) return {};

  final data = doc.data() ?? {};

  // homeRegion* 필드가 있으면 우선 사용, 없으면 region* 필드로 fallback
  // Phase 4에서 GPS 기반으로 homeRegion*을 저장함
  final gu = (data['homeRegionGu'] as String?)?.isNotEmpty == true
      ? data['homeRegionGu'] as String?
      : data['regionGu'] as String?;
  final si = (data['homeRegionSi'] as String?)?.isNotEmpty == true
      ? data['homeRegionSi'] as String?
      : data['regionSi'] as String?;
  final dong = (data['homeRegionDong'] as String?)?.isNotEmpty == true
      ? data['homeRegionDong'] as String?
      : data['regionDong'] as String?;

  return {
    'gu': gu,
    'si': si,
    'dong': dong,
  };
});

// ── 탭 하나 (구/군 또는 시·도 또는 동네) ─────────────────────────────────
class _RankingTab extends ConsumerStatefulWidget {
  final String level;   // 'gu' | 'si' | 'dong'
  final String userId;
  final String month;   // "YYYY-MM" 형식

  const _RankingTab({
    required this.level,
    required this.userId,
    required this.month,
  });

  @override
  ConsumerState<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends ConsumerState<_RankingTab> {
  // 현재 페이지 (0-indexed)
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    // 랭킹 데이터 조회 (최대 30개)
    final rankingAsync = ref.watch(
      regionRankingProvider((level: widget.level, month: widget.month)),
    );

    // 유저 지역 정보 조회
    final userRegionAsync = ref.watch(_userRegionProvider(widget.userId));

    return rankingAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _colorPrimary),
      ),
      error: (e, _) => ErrorView(
        error: e,
        message: '랭킹을 불러오지 못했어요',
        onRetry: () => ref.invalidate(
          regionRankingProvider((level: widget.level, month: widget.month)),
        ),
      ),
      data: (entries) {
        // 데이터 없을 때 안내 메시지
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              '이번 달 아직 러닝 기록이 없어요',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          );
        }

        // 유저 현재 레벨의 지역 이름
        final myRegion = userRegionAsync.valueOrNull?[widget.level];

        // 내 지역 순위 찾기 (0-indexed → 1-indexed)
        int myRank = -1;
        int myPoints = 0;
        for (var i = 0; i < entries.length; i++) {
          if (entries[i].region == myRegion) {
            myRank = i + 1;
            myPoints = entries[i].totalPoints;
            break;
          }
        }

        // 페이지네이션 계산
        final totalPages = (entries.length / _kPageSize).ceil();
        final pageStart = _currentPage * _kPageSize;
        final pageEnd = (pageStart + _kPageSize).clamp(0, entries.length);
        final pageEntries = entries.sublist(pageStart, pageEnd);

        return Column(
          children: [
            // ── 내 지역 배너 (상단 고정) ──────────────────────────
            _MyRegionBanner(
              myRegion: myRegion,
              myRank: myRank,
              myPoints: myPoints,
            ),

            // ── 랭킹 목록 ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: pageEntries.length,
                itemBuilder: (context, index) {
                  // 실제 전체 순위 (1-indexed)
                  final rank = pageStart + index + 1;
                  final entry = pageEntries[index];
                  final isMyRegion = entry.region == myRegion;

                  return _RankEntryTile(
                    rank: rank,
                    entry: entry,
                    isMyRegion: isMyRegion,
                  );
                },
              ),
            ),

            // ── 페이지네이션 버튼 ────────────────────────────────
            if (totalPages > 1)
              _PaginationBar(
                currentPage: _currentPage,
                totalPages: totalPages,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
              ),
          ],
        );
      },
    );
  }
}

// ── 내 지역 배너 위젯 (상단 고정 회색 카드) ────────────────────────────────
class _MyRegionBanner extends StatelessWidget {
  final String? myRegion;
  final int myRank;       // -1이면 순위권 밖
  final int myPoints;

  const _MyRegionBanner({
    required this.myRegion,
    required this.myRank,
    required this.myPoints,
  });

  @override
  Widget build(BuildContext context) {
    // 지역 정보 없거나 순위권 밖이면 안내 문구 표시
    final hasRegion = myRegion != null && myRegion!.isNotEmpty;
    final hasRank = myRank > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Text('📍', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: hasRegion
                ? RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: '내 지역: ',
                          style: TextStyle(color: Colors.white60),
                        ),
                        TextSpan(
                          text: myRegion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasRank) ...[
                          TextSpan(
                            text: ' · ',
                            style: TextStyle(color: Colors.white38),
                          ),
                          TextSpan(
                            text: '$myRank위',
                            style: const TextStyle(
                              color: _colorAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' · ',
                            style: TextStyle(color: Colors.white38),
                          ),
                          TextSpan(
                            text: '${myPoints}P',
                            style: const TextStyle(
                              color: _colorPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else
                          TextSpan(
                            text: ' · 이번 달 순위권 밖',
                            style: TextStyle(color: Colors.white38),
                          ),
                      ],
                    ),
                  )
                : const Text(
                    '프로필에서 지역을 설정하면 내 순위를 볼 수 있어요',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 랭킹 항목 타일 ────────────────────────────────────────────────────────
class _RankEntryTile extends StatelessWidget {
  final int rank;
  final RegionRankEntry entry;
  final bool isMyRegion; // 내 지역 여부 → Primary 하이라이트

  const _RankEntryTile({
    required this.rank,
    required this.entry,
    required this.isMyRegion,
  });

  @override
  Widget build(BuildContext context) {
    // 1~3위 메달 색상
    final medalColor = switch (rank) {
      1 => _colorGold,
      2 => _colorSilver,
      3 => _colorBronze,
      _ => null,
    };
    final isMedal = medalColor != null;

    // 내 지역이면 Primary 배경·테두리
    final bgColor = isMyRegion
        ? _colorPrimary.withValues(alpha: 0.15)
        : _colorCard;
    final borderColor = isMyRegion ? _colorPrimary : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          // ── 순위 표시 ──────────────────────────────────────────
          SizedBox(
            width: 36,
            child: isMedal
                ? Text(
                    // 1~3위 메달 이모지
                    switch (rank) {
                      1 => '🥇',
                      2 => '🥈',
                      _ => '🥉',
                    },
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: isMyRegion ? _colorPrimary : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 8),

          // ── 지역 이름 + 상위 지역 ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.region,
                  style: TextStyle(
                    color: isMedal
                        ? medalColor
                        : isMyRegion
                            ? Colors.white
                            : Colors.white,
                    fontWeight: isMedal || isMyRegion
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: isMedal ? 15 : 14,
                  ),
                ),
                // 상위 지역이 있으면 작게 표시
                if (entry.parentRegion != null &&
                    entry.parentRegion!.isNotEmpty)
                  Text(
                    entry.parentRegion!,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),

          // ── 포인트 + 러너 수 ───────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalPoints}P',
                style: TextStyle(
                  color: isMedal ? medalColor : _colorPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${entry.runnerCount}명',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 페이지네이션 바 ── ◀ 1/3 ▶ 형식 ─────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage;   // 0-indexed
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ◀ 이전 버튼
          IconButton(
            onPressed: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: currentPage > 0 ? Colors.white70 : Colors.white24,
          ),

          // 페이지 표시 (예: 1/3)
          Text(
            '${currentPage + 1} / $totalPages',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),

          // ▶ 다음 버튼
          IconButton(
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            color:
                currentPage < totalPages - 1 ? Colors.white70 : Colors.white24,
          ),
        ],
      ),
    );
  }
}
