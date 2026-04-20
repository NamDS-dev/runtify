import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/email_validator.dart';
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
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUpMode = false; // true면 회원가입 모드
  bool _isLoading = false;
  String _password = ''; // 실시간 강도 표시용

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
        _nameController.text.trim(),
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
                    validator: (v) =>
                        v!.isEmpty ? '닉네임을 입력해주세요' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _emailController,
                  label: '이메일',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: EmailValidator.validate,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _passwordController,
                  label: '비밀번호',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: _isSignUpMode
                      ? PasswordValidator.validateForSignUp
                      : PasswordValidator.validateForSignIn,
                ),
                if (_isSignUpMode)
                  PasswordStrengthBar(password: _password),
                const SizedBox(height: 32),

                // 로그인/회원가입 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
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
              ],
            ),
          ),
        ),
      ),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
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
