import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/email_validator.dart';
import '../../../../core/validators/name_validator.dart';
import '../../../../core/validators/password_validator.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_strength_bar.dart';

// 로그인 화면
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUpMode = false; // true면 회원가입 모드
  bool _isLoading = false;
  String _password = ''; // 실시간 강도 표시용
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 이메일 회원가입 시 필수 동의 체크박스 (소셜 로그인은 탭 행위로 간주, 해당 없음)
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    // 회원가입 모드에서만 실시간 강도 표시 → 불필요한 rebuild 최소화
    if (!_isSignUpMode) return;
    if (_password == _passwordController.text) return;
    setState(() => _password = _passwordController.text);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authNotifier = ref.read(authProvider.notifier);
    String? errorMessage;

    // 이메일은 서버 전달 직전 일관된 형태(소문자/trim)로 정규화
    final normalizedEmail = EmailValidator.normalize(_emailController.text);

    if (_isSignUpMode) {
      errorMessage = await authNotifier.signUp(
        normalizedEmail,
        _passwordController.text.trim(),
        NameValidator.normalize(_nameController.text),
      );
    } else {
      errorMessage = await authNotifier.signIn(
        normalizedEmail,
        _passwordController.text.trim(),
      );
    }

    setState(() => _isLoading = false);

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이메일 로그인/회원가입은 소셜 로그인과 동일하게 다크 테마 고정
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            // AutofillGroup — iOS Keychain / 1Password / Google Smart Lock 등이 폼을 인식하도록 묶음
            child: AutofillGroup(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 로고 영역
                const Icon(
                  Icons.directions_run,
                  size: 72,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'RUNTIFY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  '달리는 만큼 성장하는 게임',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 48),

                // 회원가입 모드일 때만 이름 입력창 표시
                if (_isSignUpMode) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: '닉네임',
                    icon: Icons.person_outline,
                    validator: NameValidator.validate,
                    autofillHints: const [
                      AutofillHints.name,
                      AutofillHints.nickname,
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _emailController,
                  label: '이메일',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: EmailValidator.validate,
                  // 비번 매니저가 username/email 폼을 인식하도록 두 hint 모두 명시
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                ),
                const SizedBox(height: 16),

                _buildPasswordField(
                  controller: _passwordController,
                  label: '비밀번호',
                  obscure: _obscurePassword,
                  onToggle: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  validator: _isSignUpMode
                      ? PasswordValidator.validateForSignUp
                      : PasswordValidator.validateForSignIn,
                  // 회원가입은 newPassword (강한 비번 제안), 로그인은 password (저장된 비번 호출)
                  autofillHints: _isSignUpMode
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                ),
                if (_isSignUpMode)
                  PasswordStrengthBar(password: _password),

                // 회원가입 시 비밀번호 확인 입력 — 오타로 인한 즉시 로그인 실패 방지
                if (_isSignUpMode) ...[
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: '비밀번호 확인',
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 한 번 더 입력해주세요';
                      }
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않습니다';
                      }
                      return null;
                    },
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  // 약관·개인정보 동의 체크박스 (이메일 가입 한정 필수)
                  const SizedBox(height: 12),
                  _buildConsentRow(
                    checked: _agreedToTerms,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                    label: '[필수] 이용약관 동의',
                    detailRoutePath: '/legal/terms',
                  ),
                  _buildConsentRow(
                    checked: _agreedToPrivacy,
                    onChanged: (v) =>
                        setState(() => _agreedToPrivacy = v ?? false),
                    label: '[필수] 개인정보 처리방침 동의',
                    detailRoutePath: '/legal/privacy',
                  ),
                ],
                const SizedBox(height: 32),

                // 로그인/회원가입 버튼 — 회원가입 모드에서 두 약관 모두 동의 시에만 활성
                ElevatedButton(
                  onPressed: (_isLoading ||
                          (_isSignUpMode &&
                              !(_agreedToTerms && _agreedToPrivacy)))
                      ? null
                      : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUpMode ? '회원가입' : '로그인'),
                ),
                const SizedBox(height: 16),

                // 로그인/회원가입 전환 버튼
                TextButton(
                  onPressed: () =>
                      setState(() => _isSignUpMode = !_isSignUpMode),
                  child: Text(
                    _isSignUpMode
                        ? '이미 계정이 있으신가요? 로그인'
                        : '계정이 없으신가요? 회원가입',
                  ),
                ),

                // 비밀번호 찾기 (로그인 모드에서만 노출)
                if (!_isSignUpMode)
                  TextButton(
                    onPressed: _isLoading ? null : _openForgotPasswordSheet,
                    child: Text(
                      '비밀번호를 잊으셨나요?',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            ), // AutofillGroup
          ),
        ),
      ),
    ),
    );
  }

  // 비밀번호 찾기 BottomSheet — 로그인 모드에서 "비밀번호를 잊으셨나요?" 탭 시 열림
  // 보안: user-not-found 와 성공을 구분하지 않고 동일 안내 문구로 통일
  void _openForgotPasswordSheet() {
    final seededEmail = EmailValidator.normalize(_emailController.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _ForgotPasswordSheet(initialEmail: seededEmail),
    );
  }

  // 이메일 회원가입 필수 동의 체크박스 1줄 — 체크박스 + 라벨 + "자세히 보기" 링크
  Widget _buildConsentRow({
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String detailRoutePath,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!checked),
            behavior: HitTestBehavior.opaque,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.push(detailRoutePath),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '자세히 보기',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // 비밀번호 전용 TextFormField — suffix 눈 아이콘으로 표시/숨김 토글
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      autofillHints: autofillHints,
      // 자동완성·개인사전 학습 차단 (비밀번호 노출/힌트 방지)
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textSecondary),
        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: context.colors.textSecondary,
          ),
          tooltip: obscure ? '비밀번호 표시' : '비밀번호 숨기기',
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.surface),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppTheme.primary),
        ),
        filled: true,
        fillColor: context.colors.surface,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      autofillHints: autofillHints,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textSecondary),
        prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.surface),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppTheme.primary),
        ),
        filled: true,
        fillColor: context.colors.surface,
      ),
    );
  }
}

// ── 비밀번호 재설정 BottomSheet ──────────────────────────────────────────────
// 사용자가 이메일을 입력하면 Firebase 기본 템플릿(한국어) 재설정 메일 발송.
// 보안 원칙:
// - 등록 여부와 무관하게 동일 안내 문구("해당 이메일이 등록되어 있다면 재설정 메일이 발송됩니다")
// - 네트워크/형식 오류만 별도 에러 SnackBar 로 사용자에게 재시도 유도
class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMessage = await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_emailController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 네트워크·형식 에러만 빨간 SnackBar 로 안내.
    // 계정 존재 여부는 노출하지 않고 항상 "발송됨" 메시지로 통일.
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('해당 이메일이 등록되어 있다면 재설정 메일이 발송됩니다'),
        backgroundColor: Color(0xFF3A3A3A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 키보드에 덮이지 않도록 viewInsets 반영
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '비밀번호 재설정',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '가입한 이메일을 입력하면 재설정 링크를 보내드려요.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              validator: EmailValidator.validate,
              enabled: !_isLoading,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: '이메일',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppTheme.primary,
                ),
                filled: true,
                fillColor: context.colors.cardColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.surface),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('재설정 메일 발송'),
            ),
          ],
        ),
      ),
    );
  }
}
