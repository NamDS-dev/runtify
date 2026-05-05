import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/running_backup.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/running_session_model.dart';
import '../../domain/entities/running_session_entity.dart';
import '../providers/running_provider.dart';

/// 앱 시작 시 진행 중이던 러닝 백업이 있으면 복구 다이얼로그를 띄우는 헬퍼 위젯.
///
/// 보이지 않는 widget — 첫 build 후 한 번만 검사. 백업이 없거나 너무 짧으면 즉시 스킵.
/// 사용자 선택:
///   - 저장: 백업 데이터로 RunningSessionModel 구성 → `saveSession` → 토스트 + 백업 삭제
///   - 버리기: 백업 삭제만
class RunningRecoveryHandler extends ConsumerStatefulWidget {
  final String userId;

  const RunningRecoveryHandler({super.key, required this.userId});

  @override
  ConsumerState<RunningRecoveryHandler> createState() =>
      _RunningRecoveryHandlerState();
}

class _RunningRecoveryHandlerState
    extends ConsumerState<RunningRecoveryHandler> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checked) return;
      _checked = true;
      _checkRecovery();
    });
  }

  Future<void> _checkRecovery() async {
    final backup = RunningBackup();
    final snapshot = await backup.load();
    if (!mounted || snapshot == null) return;

    // 너무 짧은 세션은 노이즈 — 조용히 정리
    if (!snapshot.isRecoverable) {
      await backup.clear();
      return;
    }

    if (!mounted) return;
    final result = await showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecoveryDialog(snapshot: snapshot),
    );

    if (!mounted) return;
    switch (result) {
      case _RecoveryChoice.save:
        await _saveRecoveredSession(snapshot);
        await backup.clear();
        break;
      case _RecoveryChoice.discard:
      case null:
        // dismiss/취소도 버리기로 간주 — 다이얼로그를 매번 띄우지 않게
        await backup.clear();
        break;
    }
  }

  Future<void> _saveRecoveredSession(RunningBackupSnapshot snap) async {
    final dataSource = ref.read(runningDataSourceProvider);
    final earned = (snap.distanceKm * 10).round();
    final pace = snap.distanceKm > 0
        ? (snap.durationSeconds / 60) / snap.distanceKm
        : 0.0;
    final endTime =
        snap.startTime.add(Duration(seconds: snap.durationSeconds));

    final model = RunningSessionModel(
      id: '${widget.userId}_${snap.startTime.millisecondsSinceEpoch}',
      userId: widget.userId,
      startTime: snap.startTime,
      endTime: endTime,
      distanceKm: snap.distanceKm,
      durationSeconds: snap.durationSeconds,
      avgPaceMinPerKm: pace,
      avgHeartRate: snap.avgHeartRate,
      calories: snap.distanceKm * 60,
      expEarned: earned,
      pointsEarned: earned,
      region: '',
      routePoints: snap.routePoints
          .map((p) => LatLngPoint(lat: p[0], lng: p[1]))
          .toList(),
      splitPaces: snap.splitPaces
          .map((p) => SplitPace(km: p[0].toInt(), pace: p[1]))
          .toList(),
    );

    try {
      await dataSource.saveSession(model);
      ref.invalidate(recentRunsProvider(widget.userId));
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '이전 러닝을 복구했어요 — ${snap.distanceKm.toStringAsFixed(2)}km',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이전 러닝 복구에 실패했어요. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Color(0xFFFF3333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

enum _RecoveryChoice { save, discard }

class _RecoveryDialog extends StatelessWidget {
  final RunningBackupSnapshot snapshot;

  const _RecoveryDialog({required this.snapshot});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(
        '이전 러닝 복구',
        style: TextStyle(color: context.colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '저장되지 않은 러닝 기록이 있어요.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RecoveryStat(
                  label: '거리',
                  value: '${snapshot.distanceKm.toStringAsFixed(2)} km',
                ),
                _RecoveryStat(
                  label: '시간',
                  value: _formatDuration(snapshot.durationSeconds),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecoveryChoice.discard),
          child: Text(
            '버리기',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_RecoveryChoice.save),
          child: const Text(
            '저장',
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

class _RecoveryStat extends StatelessWidget {
  final String label;
  final String value;

  const _RecoveryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
