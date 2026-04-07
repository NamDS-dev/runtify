import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/goal_entity.dart';

// Firestore ↔ GoalEntity 변환 모델
class GoalModel extends GoalEntity {
  const GoalModel({
    required super.id,
    required super.type,
    required super.targetValue,
    required super.currentValue,
    required super.period,
    required super.isCompleted,
    required super.createdAt,
  });

  // Firestore 문서 → GoalModel 변환
  factory GoalModel.fromFirestore(Map<String, dynamic> data, String id) {
    // type 문자열 → GoalType 열거형 파싱 (알 수 없는 값은 weeklyDistance 기본값)
    final typeStr = data['type'] as String? ?? 'weeklyDistance';
    final GoalType goalType = GoalType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => GoalType.weeklyDistance,
    );

    // createdAt: Firestore Timestamp 또는 null 처리
    DateTime createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return GoalModel(
      id: id,
      type: goalType,
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 0.0,
      currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? '',
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  // GoalModel → Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'period': period,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
