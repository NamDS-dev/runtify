import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

// 제어 문자(U+0000~U+001F, U+007F~U+009F) 입력 차단 — 메모에는 줄바꿈(\n) 만 예외 허용.
class _NoControlCharsFormatter extends TextInputFormatter {
  final bool allowNewlines;

  const _NoControlCharsFormatter({this.allowNewlines = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = StringBuffer();
    for (final code in newValue.text.codeUnits) {
      final isControl = code <= 0x1F || (code >= 0x7F && code <= 0x9F);
      if (!isControl) {
        filtered.writeCharCode(code);
        continue;
      }
      if (allowNewlines && code == 0x0A) {
        filtered.writeCharCode(code);
      }
      // 그 외 제어 문자는 drop
    }
    final result = filtered.toString();
    if (result == newValue.text) return newValue;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// 러닝 세션 제목·메모 편집 다이얼로그
//
// 정책:
// - 제목 30자 / 메모 200자 제한
// - 제어 문자 입력 차단 (TextFormField inputFormatters)
// - 빈 값 허용 (제목·메모 모두 선택)
// - 저장 시 (title, memo) 튜플 반환 — 둘 다 null/빈 문자열이면 호출자가 필드 제거 처리
class EditSessionDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialMemo;

  const EditSessionDialog({
    super.key,
    this.initialTitle,
    this.initialMemo,
  });

  static const int titleMaxLength = 30;
  static const int memoMaxLength = 200;

  @override
  State<EditSessionDialog> createState() => _EditSessionDialogState();

  // 호출자 헬퍼 — 결과 (title, memo) 또는 null (취소)
  static Future<({String? title, String? memo})?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialMemo,
  }) {
    return showDialog<({String? title, String? memo})>(
      context: context,
      builder: (_) => EditSessionDialog(
        initialTitle: initialTitle,
        initialMemo: initialMemo,
      ),
    );
  }
}

class _EditSessionDialogState extends State<EditSessionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _memoController = TextEditingController(text: widget.initialMemo ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      (
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('러닝 정보 편집'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                maxLength: EditSessionDialog.titleMaxLength,
                inputFormatters: const [
                  _NoControlCharsFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '예: 한강 야간 러닝',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoController,
                maxLength: EditSessionDialog.memoMaxLength,
                maxLines: 4,
                inputFormatters: const [
                  _NoControlCharsFormatter(allowNewlines: true),
                ],
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '오늘의 컨디션, 코스 메모 등',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
