import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/password_validator.dart';

// 비밀번호 입력 중 실시간 강도 표시
// 4단 막대 + 텍스트 라벨 (0=숨김, 1~4=표시)
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox(height: 24);
    }

    final score = PasswordValidator.strength(password);
    final label = PasswordValidator.strengthLabel(score);
    final color = _colorFor(score);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i < score;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active
                        ? color
                        : context.colors.surface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '비밀번호 강도: $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(int score) {
    if (score <= 1) return Colors.redAccent;
    if (score == 2) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
}
