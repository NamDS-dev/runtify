import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ShellRoute 용 공통 하단 탭 바 쉘 위젯
// go_router ShellRoute builder에서 child를 감싸는 역할
// 5개 메인 탭(홈/러닝/크루/랭킹/리워드)에 공통 BottomNav를 제공
class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;
  final String location;

  const ScaffoldWithBottomNav({
    super.key,
    required this.child,
    required this.location,
  });

  // 현재 경로 문자열 → 탭 인덱스 변환
  // 탭 순서: 0=홈, 1=러닝, 2=크루, 3=랭킹, 4=리워드
  int get _currentIndex {
    if (location.startsWith('/running-section')) return 1;
    if (location.startsWith('/crew')) return 2;
    if (location.startsWith('/ranking')) return 3;
    if (location.startsWith('/reward')) return 4;
    return 0; // /home 기본값
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // child는 각 탭 화면의 Scaffold (AppBar + body 포함)
      // 중첩 Scaffold: 외부는 BottomNav, 내부는 AppBar+body 담당
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // 5탭에서 라벨이 잘리지 않도록
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/running-section');
            case 2:
              context.go('/crew');
            case 3:
              context.go('/ranking');
            case 4:
              context.go('/reward');
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
      ),
    );
  }
}
