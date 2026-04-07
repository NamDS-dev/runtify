import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// 리워드 스토어 화면 (프로토타입)
class RewardPage extends StatelessWidget {
  const RewardPage({super.key});

  static final _rewards = [
    {
      'title': '스타벅스 아메리카노',
      'points': 500,
      'category': '카페',
      'icon': '☕',
    },
    {
      'title': '나이키 할인 쿠폰 10%',
      'points': 1000,
      'category': '스포츠',
      'icon': '👟',
    },
    {
      'title': 'GS25 편의점 3,000원',
      'points': 300,
      'category': '편의점',
      'icon': '🏪',
    },
    {
      'title': '런닝화 구매 20% 할인',
      'points': 2000,
      'category': '스포츠',
      'icon': '🏃',
    },
    {
      'title': '단백질 쉐이크 1팩',
      'points': 800,
      'category': '영양',
      'icon': '💪',
    },
    {
      'title': '네이버페이 포인트 5,000원',
      'points': 1500,
      'category': '현금성',
      'icon': '💰',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // 현재 보유 포인트 (프로토타입 고정값)
    const myPoints = 1230;

    return Scaffold(
      appBar: AppBar(
        title: const Text('리워드 스토어'),
      ),
      body: Column(
        children: [
          // 내 포인트 표시 (Sunset Fire 그라디언트)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '내 포인트',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '$myPoints P',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  '🏃 더 달려서\n포인트 적립!',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // 리워드 목록
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _rewards.length,
              itemBuilder: (context, index) {
                final reward = _rewards[index];
                final canAfford = myPoints >= (reward['points'] as int);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: canAfford
                        ? Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward['icon'] as String,
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reward['category'] as String,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward['title'] as String,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canAfford
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${reward['title']} 교환 준비 중!'),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            backgroundColor: canAfford
                                ? AppTheme.primary
                                : context.colors.surface,
                            foregroundColor: canAfford
                                ? Colors.white
                                : context.colors.textSecondary,
                          ),
                          child: Text(
                            '${reward['points']}P',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
