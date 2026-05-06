import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nickname_change_policy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/name_validator.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

/// 닉네임 사후 변경 다이얼로그 (30일 1회 정책 — 2026-05-06).
///
/// 정책: [NicknameChangePolicy.canChange] false 시 disabled + 남은 일수 안내.
/// 검증 흐름: 길이/형식/제어문자 → 30일 정책 → 중복 검사(`AuthNotifier.changeNickname` 내부).
class ChangeNicknameDialog extends ConsumerStatefulWidget {
  final UserEntity user;
  const ChangeNicknameDialog({super.key, required this.user});

  @override
  ConsumerState<ChangeNicknameDialog> createState() =>
      _ChangeNicknameDialogState();
}

class _ChangeNicknameDialogState extends ConsumerState<ChangeNicknameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result =
        await ref.read(authProvider.notifier).changeNickname(_controller.text);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임을 변경했어요'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canChange = NicknameChangePolicy.canChange(
        lastChangedAt: widget.user.nameChangedAt);
    final remainingDays = NicknameChangePolicy.daysUntilChangeable(
        lastChangedAt: widget.user.nameChangedAt);

    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(
        '닉네임 변경',
        style: TextStyle(color: context.colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canChange)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '닉네임은 30일에 1번만 변경할 수 있어요.\n$remainingDays일 후에 다시 변경할 수 있어요.',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            controller: _controller,
            enabled: canChange && !_saving,
            decoration: InputDecoration(
              hintText: '새 닉네임',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            maxLength: NameValidator.maxLength,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: (canChange && !_saving) ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : const Text(
                  '변경',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
