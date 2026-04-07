import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 앱 전체 공통 하단 탭 바 (5탭: 홈/러닝/크루/랭킹/리워드)
// currentIndex: 0=홈, 1=러닝, 2=크루, 3=랭킹, 4=리워드
class MainBottomNav extends StatelessWidget {
  final int currentIndex;

  const MainBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed, // 5탭에서 라벨이 잘리지 않도록
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/running-section');
            break;
          case 2:
            context.go('/crew');
            break;
          case 3:
            context.go('/ranking');
            break;
          case 4:
            context.go('/reward');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_run_outlined),
          activeIcon: Icon(Icons.directions_run),
          label: '러닝',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group_outlined),
          activeIcon: Icon(Icons.group),
          label: '크루',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.leaderboard_outlined),
          activeIcon: Icon(Icons.leaderboard),
          label: '랭킹',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.card_giftcard_outlined),
          activeIcon: Icon(Icons.card_giftcard),
          label: '리워드',
        ),
      ],
    );
  }
}
