import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

// 미인증 사용자가 인증 필요 기능을 시도할 때 노출되는 공통 다이얼로그.
// 정책: [POLICY.md § 1] — 러닝 저장/크루 가입/리워드 교환/랭킹 등록 시 호출.
//
// 반환값:
// - true  : 사용자가 "인증 완료했어요" 눌렀고 실제로 인증이 확인됨
// - false/null : 다이얼로그 닫힘 (나중에/외부 탭 등)
class VerifyEmailDialog extends ConsumerStatefulWidget {
  // 어떤 기능을 막았는지 맥락 메시지 (예: "러닝 기록을 저장하려면")
  final String contextMessage;

  const VerifyEmailDialog({
    super.key,
    this.contextMessage = '이 기능을 사용하려면',
  });

  @override
  ConsumerState<VerifyEmailDialog> createState() => _VerifyEmailDialogState();

  // 간편 호출 헬퍼
  static Future<bool?> show(
    BuildContext context, {
    String contextMessage = '이 기능을 사용하려면',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VerifyEmailDialog(contextMessage: contextMessage),
    );
  }
}

class _VerifyEmailDialogState extends ConsumerState<VerifyEmailDialog> {
  bool _sending = false;
  bool _checking = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _statusMessage = null;
    });

    final rateLimiter = ref.read(emailVerificationRateLimiterProvider);
    final error = await ref
        .read(authProvider.notifier)
        .resendEmailVerification(rateLimiter: rateLimiter);

    if (!mounted) return;
    setState(() {
      _sending = false;
      _statusMessage = error ?? '인증 메일이 발송되었습니다. 메일함을 확인해주세요';
      _statusIsError = error != null;
    });
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    final verified = await ref.read(authProvider.notifier).reloadEmailVerification();

    if (!mounted) return;
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _checking = false;
      _statusMessage = '아직 인증이 완료되지 않았습니다. 메일함의 링크를 확인해주세요';
      _statusIsError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _sending || _checking;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: const Row(
        children: [
          Text('📧', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '이메일 인증이 필요해요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.contextMessage}\n이메일 인증을 완료해주세요.',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? Colors.red.withValues(alpha: 0.12)
                    : AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusIsError ? Colors.red[200] : Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            '나중에',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        ),
        TextButton(
          onPressed: isBusy ? null : _resend,
          child: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '인증 메일 재발송',
                  style: TextStyle(color: AppTheme.primary),
                ),
        ),
        ElevatedButton(
          onPressed: isBusy ? null : _checkVerified,
          child: _checking
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('인증 완료했어요'),
        ),
      ],
    );
  }
}
