import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/korea_regions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/crew_provider.dart';

// 크루 생성 화면
class CrewCreatePage extends ConsumerStatefulWidget {
  const CrewCreatePage({super.key});

  @override
  ConsumerState<CrewCreatePage> createState() => _CrewCreatePageState();
}

class _CrewCreatePageState extends ConsumerState<CrewCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _maxMembers = 20; // 기본값 20명

  // 지역 선택 상태 (휠 피커에서 선택)
  String? _selectedSi; // 시·도
  String? _selectedGu; // 구·군

  // 선택된 지역 표시 문자열
  String get _regionDisplay {
    if (_selectedSi == null) return '';
    if (_selectedGu == null) return _selectedSi!;
    return '$_selectedSi $_selectedGu';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 최대 인원 증가/감소 (5~50명 범위)
  void _changeMaxMembers(int delta) {
    setState(() {
      _maxMembers = (_maxMembers + delta).clamp(5, 50);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final crew = await ref.read(crewActionsProvider.notifier).createCrew(
          name: _nameController.text.trim(),
          region: _regionDisplay,
          description: _descriptionController.text.trim(),
          maxMembers: _maxMembers,
          leaderId: user.id,
        );

    if (!mounted) return;

    if (crew != null) {
      // 유저 정보 갱신 (crewId 업데이트 반영)
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${crew.name} 크루를 만들었어요!'),
          backgroundColor: AppTheme.primary,
        ),
      );
      // 크루 목록으로 이동
      context.go('/crew');
    } else {
      final error = ref.read(crewActionsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('크루 생성 실패: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 시·도 / 구·군 2단계 휠 피커 BottomSheet
  void _showRegionPicker() {
    int siIndex = _selectedSi != null ? koreaProvinces.indexOf(_selectedSi!) : 0;
    if (siIndex < 0) siIndex = 0;

    List<String> currentGuList = koreaRegions[koreaProvinces[siIndex]]!;
    int guIndex = _selectedGu != null ? currentGuList.indexOf(_selectedGu!) : 0;
    if (guIndex < 0) guIndex = 0;

    String tempSi = koreaProvinces[siIndex];
    String tempGu = currentGuList[guIndex];
    final guScrollController = FixedExtentScrollController(initialItem: guIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: 440,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.centerLeft, child: Text('📍 활동 지역 선택', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: Text('시·도', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600))),
                  Expanded(child: Text('구·군', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 4),
              // 2단계 CupertinoPicker
              Expanded(
                child: Row(children: [
                  // 시·도
                  Expanded(child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: siIndex),
                    itemExtent: 40,
                    selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                    onSelectedItemChanged: (index) {
                      setSheetState(() {
                        tempSi = koreaProvinces[index];
                        currentGuList = koreaRegions[tempSi]!;
                        tempGu = currentGuList[0];
                        guScrollController.jumpToItem(0);
                      });
                    },
                    children: koreaProvinces.map((si) => Center(child: Text(si,
                      style: TextStyle(color: si == tempSi ? AppTheme.primary : Colors.white70, fontSize: si == tempSi ? 17 : 15, fontWeight: si == tempSi ? FontWeight.bold : FontWeight.normal),
                    ))).toList(),
                  )),
                  // 구·군
                  Expanded(child: CupertinoPicker(
                    scrollController: guScrollController,
                    itemExtent: 40,
                    selectionOverlay: Container(decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
                    onSelectedItemChanged: (index) {
                      setSheetState(() { if (index < currentGuList.length) tempGu = currentGuList[index]; });
                    },
                    children: currentGuList.map((gu) => Center(child: Text(gu,
                      style: TextStyle(color: gu == tempGu ? AppTheme.primary : Colors.white70, fontSize: gu == tempGu ? 17 : 15, fontWeight: gu == tempGu ? FontWeight.bold : FontWeight.normal),
                    ))).toList(),
                  )),
                ]),
              ),
              // 미리보기
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$tempSi $tempGu', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
              // 확인 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                  onPressed: () { setState(() { _selectedSi = tempSi; _selectedGu = tempGu; }); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  child: const Text('선택 완료'),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(crewActionsProvider);
    final isLoading = actionsState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('크루 만들기'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 크루 이름 ─────────────────────────────────────────────
              _FieldLabel(text: '크루 이름 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  context,
                  hintText: '예) 강남 러너스',
                ),
                maxLength: 20,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '크루 이름을 입력해주세요';
                  if (v.trim().length < 2) return '2글자 이상 입력해주세요';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── 활동 지역 (휠 피커) ──────────────────────────────────
              _FieldLabel(text: '활동 지역 *'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showRegionPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.colors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: _selectedSi == null && _formKey.currentState?.validate() == false
                        ? Border.all(color: Colors.red)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _regionDisplay.isNotEmpty
                              ? _regionDisplay
                              : '시·도 / 구·군 선택',
                          style: TextStyle(
                            color: _regionDisplay.isNotEmpty
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.location_on,
                        color: _regionDisplay.isNotEmpty
                            ? AppTheme.primary
                            : context.colors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedSi == null)
                // 폼 검증 시 에러 메시지 표시용 숨겨진 FormField
                FormField<String>(
                  validator: (_) => _selectedSi == null ? '활동 지역을 선택해주세요' : null,
                  builder: (state) {
                    if (state.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          state.errorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              const SizedBox(height: 20),

              // ── 크루 소개 ─────────────────────────────────────────────
              _FieldLabel(text: '크루 소개'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration(
                  context,
                  hintText: '예) 매주 토요일 한강 러닝! 초보 환영 🏃',
                ),
                maxLines: 3,
                maxLength: 100,
              ),
              const SizedBox(height: 20),

              // ── 최대 인원 ─────────────────────────────────────────────
              _FieldLabel(text: '최대 인원 (5~50명)'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 감소 버튼
                  _CounterButton(
                    icon: Icons.remove,
                    onPressed: _maxMembers > 5
                        ? () => _changeMaxMembers(-1)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  // 현재 인원수
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: context.colors.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_maxMembers명',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 증가 버튼
                  _CounterButton(
                    icon: Icons.add,
                    onPressed: _maxMembers < 50
                        ? () => _changeMaxMembers(1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── 크루 만들기 버튼 ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '크루 만들기',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 입력 필드 스타일
  InputDecoration _inputDecoration(BuildContext context,
      {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: context.colors.textSecondary),
      filled: true,
      fillColor: context.colors.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

// 필드 라벨
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// +/- 카운터 버튼
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _CounterButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed != null
          ? AppTheme.primary.withValues(alpha: 0.15)
          : context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: onPressed != null
                ? AppTheme.primary
                : context.colors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
