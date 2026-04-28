import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/friendly_error.dart';

// AsyncValue.error / FutureBuilder 에러 상태를 표시하는 공통 위젯.
//
// 사용:
// ```dart
// asyncValue.when(
//   loading: () => const CircularProgressIndicator(),
//   error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(myProvider)),
//   data: (v) => ...,
// );
// ```
//
// `inline: true` 면 Center 없이 컴팩트하게 (작은 영역용)
class ErrorView extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final bool inline;

  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.inline = false,
  });

  String _resolvedMessage() {
    if (message != null) return message!;
    if (error != null) return friendlyErrorMessage(error!);
    return '잠시 후 다시 시도해주세요';
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          size: 36,
          color: Color(0xFF9E9E9E),
        ),
        const SizedBox(height: 8),
        Text(
          _resolvedMessage(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('다시 시도'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ],
      ],
    );

    if (inline) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: body,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: body,
      ),
    );
  }
}
