import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

// 소셜 로그인 화면 (앱 첫 진입 화면)
class SocialLoginPage extends ConsumerStatefulWidget {
  const SocialLoginPage({super.key});

  @override
  ConsumerState<SocialLoginPage> createState() => _SocialLoginPageState();
}

class _SocialLoginPageState extends ConsumerState<SocialLoginPage> {
  bool _isLoading = false;

  // 소셜 로그인 공통 처리
  Future<void> _handleSocialLogin(Future<String?> Function() loginFn) async {
    setState(() => _isLoading = true);

    final errorMessage = await loginFn();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // BG 다크
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── 로고 영역 ──────────────────────────────────────────────────
              _buildLogo(),

              const Spacer(flex: 2),

              // ── 소셜 로그인 버튼들 (디자인 확정 순서: 카카오 → 네이버 → Google → Apple) ──
              _buildKakaoButton(),
              const SizedBox(height: 12),

              _buildNaverButton(),
              const SizedBox(height: 12),

              _buildGoogleButton(),
              const SizedBox(height: 12),

              _buildAppleButton(),

              const SizedBox(height: 28),

              // ── 구분선 ─────────────────────────────────────────────────────
              _buildDivider(),

              const SizedBox(height: 28),

              // ── Runtify 계정으로 로그인 버튼 ───────────────────────────────
              _buildRuntifyLoginButton(),

              const SizedBox(height: 24),

              // ── 약관 텍스트 ────────────────────────────────────────────────
              _buildTermsText(),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  // 로고
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🔥', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'RUNTIFY',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '달리는 만큼 성장하는 게임',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '소셜 계정으로 간편하게 시작하세요',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF9E9E9E),
          ),
        ),
      ],
    );
  }

  // Apple 로그인 버튼 (흰색 배경)
  Widget _buildAppleButton() {
    return _SocialButton(
      onTap: _isLoading
          ? null
          : () => _handleSocialLogin(
                () => ref.read(authProvider.notifier).signInWithApple(),
              ),
      backgroundColor: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apple, color: Colors.black, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Apple로 계속하기',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Google 로그인 버튼 (다크 카드)
  Widget _buildGoogleButton() {
    return _SocialButton(
      onTap: _isLoading
          ? null
          : () => _handleSocialLogin(
                () => ref.read(authProvider.notifier).signInWithGoogle(),
              ),
      backgroundColor: const Color(0xFF252525), // Card 색상
      border: Border.all(color: const Color(0xFF3A3A3A)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google 'G' 로고 (색상 텍스트로 표현)
          _GoogleLogo(),
          SizedBox(width: 10),
          Text(
            'Google로 계속하기',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 카카오 로그인 버튼 (카카오 노란색)
  // Figma에는 💬 이모지로 카카오 공식 말풍선 로고를 암시 — SVG 에셋 확보 전까지 유지
  Widget _buildKakaoButton() {
    return _SocialButton(
      onTap: _isLoading ? null : _showComingSoonSnackBar,
      backgroundColor: const Color(0xFFFEE500), // 카카오 노란색
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('💬', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text(
            '카카오로 계속하기',
            style: TextStyle(
              color: Color(0xFF191919),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 네이버 로그인 버튼 (네이버 공식 그린 #03C75A)
  // SDK 연동 전까지 "곧 만나보실 수 있어요!" 안내 (카카오와 동일 처리)
  Widget _buildNaverButton() {
    return _SocialButton(
      onTap: _isLoading ? null : _showComingSoonSnackBar,
      backgroundColor: const Color(0xFF03C75A), // 네이버 그린
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NaverLogo(),
          SizedBox(width: 10),
          Text(
            '네이버로 계속하기',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 준비 중인 소셜 로그인(카카오/네이버) 공통 안내
  void _showComingSoonSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('곧 만나보실 수 있어요!'),
        backgroundColor: Color(0xFF3A3A3A),
      ),
    );
  }

  // 구분선 "또는"
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '또는',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
        ),
      ],
    );
  }

  // Runtify 계정으로 로그인 버튼 (이메일 로그인 페이지로 이동)
  Widget _buildRuntifyLoginButton() {
    return _SocialButton(
      onTap: _isLoading ? null : () => context.push('/login/email'),
      backgroundColor: const Color(0xFF1A1A1A), // Surface 색상
      border: Border.all(
        color: AppTheme.primary.withValues(alpha: 0.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔥', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Text(
            'Runtify 계정으로 로그인',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 하단 약관 텍스트
  Widget _buildTermsText() {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 11,
        ),
        children: [
          const TextSpan(text: '계속 진행하면 '),
          TextSpan(
            text: '서비스 이용약관',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' 및 '),
          TextSpan(
            text: '개인정보 처리방침',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: '에 동의하는 것으로 간주합니다'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── 소셜 버튼 공통 위젯 ─────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Border? border;
  final Widget child;

  const _SocialButton({
    required this.onTap,
    required this.backgroundColor,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Google 'G' 로고 위젯 ────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4285F4), // Google 파란색
            ),
          ),
        ],
      ),
    );
  }
}

// ── 네이버 'N' 로고 위젯 ────────────────────────────────────────────────────
// 공식 SVG 에셋 확보 전까지 흰색 Bold 'N' 텍스트로 대체
class _NaverLogo extends StatelessWidget {
  const _NaverLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
