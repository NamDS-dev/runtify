import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// 30일 내 재로그인 시 자동 표시되는 복구 페이지 (POLICY § 4 / 2026-05-09).
///
/// 라우터 redirect 가 `user.isPendingDeletion == true` 사용자를 이 경로로 강제 이동.
/// 사용자 선택:
/// - **복구**: `recoverAccount` 호출 → deletedAt/scheduledHardDeleteAt = null → 홈으로
/// - **계속 탈퇴**: 즉시 로그아웃 → /login (Cloud Functions 가 30일 후 hard delete)
class RecoverAccountPage extends ConsumerStatefulWidget {
  const RecoverAccountPage({super.key});

  @override
  ConsumerState<RecoverAccountPage> createState() =>
      _RecoverAccountPageState();
}

class _RecoverAccountPageState extends ConsumerState<RecoverAccountPage> {
  bool _busy = false;
  String? _error;

  Future<void> _recover() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(authProvider.notifier).recoverAccount();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // 복구 성공 → 홈으로
    context.go('/home');
  }

  Future<void> _continueWithDeletion() async {
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  String _formatDaysLeft(DateTime? scheduledHardDeleteAt) {
    if (scheduledHardDeleteAt == null) return '';
    final remaining = scheduledHardDeleteAt.difference(DateTime.now()).inDays;
    if (remaining <= 0) return '오늘';
    return 'D-$remaining';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final daysLeft = _formatDaysLeft(user?.scheduledHardDeleteAt);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: Text('🛟', style: TextStyle(fontSize: 64))),
              const SizedBox(height: 24),
              Text(
                '계정이 탈퇴 처리 중이에요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                daysLeft.isNotEmpty
                    ? '$daysLeft 후 모든 데이터가 영구 삭제됩니다.\n지금 복구하면 모든 기록이 그대로 돌아와요.'
                    : '복구하면 모든 기록이 그대로 돌아와요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFFFF3333), fontSize: 12),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _busy ? null : _recover,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '계정 복구',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _continueWithDeletion,
                child: Text(
                  '복구하지 않고 로그아웃',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
