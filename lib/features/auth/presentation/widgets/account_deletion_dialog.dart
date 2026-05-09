import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// 회원 탈퇴 다이얼로그 (POLICY § 4 — 2026-05-09).
///
/// 흐름:
/// 1. 경고 페이지 — 탈퇴 결과 안내 (30일 유예, 데이터 숨김 등) + "계속" 버튼
/// 2. 크루 리더 + 멤버 1+ 시 양도 안내 페이지 (canRequestDeletion=false)
/// 3. 코드 입력 페이지 — `requestAccountDeletionCode` 후 `confirmAccountDeletion`
///
/// 1차 비밀번호 재인증은 Firebase Auth 측 정책 (최근 로그인 만료 시 자체 reauthenticate 요구).
/// 본 다이얼로그는 2차 이메일 코드 검증만 담당.
class AccountDeletionDialog extends ConsumerStatefulWidget {
  const AccountDeletionDialog({super.key});

  @override
  ConsumerState<AccountDeletionDialog> createState() =>
      _AccountDeletionDialogState();
}

enum _Stage { intro, leaderBlocked, code }

class _AccountDeletionDialogState extends ConsumerState<AccountDeletionDialog> {
  _Stage _stage = _Stage.intro;
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final canDelete =
        await ref.read(authProvider.notifier).canRequestAccountDeletion();
    if (!mounted) return;
    if (!canDelete) {
      setState(() {
        _stage = _Stage.leaderBlocked;
        _busy = false;
      });
      return;
    }
    final err =
        await ref.read(authProvider.notifier).requestAccountDeletionCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err != null) {
        _error = err;
      } else {
        _stage = _Stage.code;
      }
    });
  }

  Future<void> _onConfirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _error = '6자리 숫자 코드를 입력해주세요');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err =
        await ref.read(authProvider.notifier).confirmAccountDeletion(code);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // 성공 — 자동 로그아웃 처리됨. 다이얼로그 닫고 토스트
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('계정이 탈퇴 처리되었어요. 30일 내 재로그인 시 복구할 수 있어요'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(
        '계정 삭제',
        style: TextStyle(color: context.colors.textPrimary),
      ),
      content: switch (_stage) {
        _Stage.intro => _buildIntro(context),
        _Stage.leaderBlocked => _buildLeaderBlocked(context),
        _Stage.code => _buildCodeInput(context),
      },
      actions: switch (_stage) {
        _Stage.intro => [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text('취소',
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
            TextButton(
              onPressed: _busy ? null : _onContinue,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '계속',
                      style: TextStyle(color: Color(0xFFFF3333)),
                    ),
            ),
          ],
        _Stage.leaderBlocked => [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        _Stage.code => [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text('취소',
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
            TextButton(
              onPressed: _busy ? null : _onConfirm,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '탈퇴',
                      style: TextStyle(
                        color: Color(0xFFFF3333),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
      },
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '계정 삭제 시 다음 사항을 확인해주세요:',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        _bullet(context, '30일 동안 데이터가 숨김 처리되며 30일 후 영구 삭제됩니다'),
        _bullet(context, '30일 내 재로그인 시 복구할 수 있어요'),
        _bullet(context, '러닝 기록·배지·포인트가 모두 삭제됩니다'),
        _bullet(context, '본인 인증을 위해 이메일로 6자리 코드를 발송합니다'),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Color(0xFFFF3333), fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildLeaderBlocked(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🚫', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          '크루 리더는 다른 멤버에게 리더를 양도한 후에 탈퇴할 수 있어요.',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          '크루 → 멤버 관리 화면에서 양도하거나, 본인만 멤버로 남은 후 다시 시도해주세요.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCodeInput(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이메일로 발송된 6자리 코드를 입력해주세요. (10분 유효)',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          enabled: !_busy,
          style: const TextStyle(
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '------',
            border: const OutlineInputBorder(),
            errorText: _error,
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
