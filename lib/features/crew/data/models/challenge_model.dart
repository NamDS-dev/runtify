import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/challenge_entity.dart';

// ChallengeEntity를 상속하여 Firestore 직렬화/역직렬화 기능 추가
class ChallengeModel extends ChallengeEntity {
  const ChallengeModel({
    required super.id,
    required super.type,
    required super.targetValue,
    required super.currentValue,
    required super.startDate,
    required super.endDate,
    required super.bonusPoints,
    required super.status,
    required super.participantCount,
  });

  // Firestore 문서 → ChallengeModel 변환
  factory ChallengeModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    // type 문자열 → enum 변환
    final typeStr = data['type'] as String? ?? 'distance';
    final ChallengeType type;
    switch (typeStr) {
      case 'participation':
        type = ChallengeType.participation;
        break;
      case 'streak':
        type = ChallengeType.streak;
        break;
      default:
        type = ChallengeType.distance;
    }

    // status 문자열 → enum 변환
    final statusStr = data['status'] as String? ?? 'active';
    final ChallengeStatus status;
    switch (statusStr) {
      case 'completed':
        status = ChallengeStatus.completed;
        break;
      case 'failed':
        status = ChallengeStatus.failed;
        break;
      default:
        status = ChallengeStatus.active;
    }

    // Timestamp 또는 ISO 문자열 모두 처리
    DateTime parseDate(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return ChallengeModel(
      id: id,
      type: type,
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 0.0,
      currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0.0,
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      bonusPoints: (data['bonusPoints'] as num?)?.toInt() ?? 0,
      status: status,
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ChallengeModel → Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    // enum → 문자열 변환
    final String typeStr;
    switch (type) {
      case ChallengeType.participation:
        typeStr = 'participation';
        break;
      case ChallengeType.streak:
        typeStr = 'streak';
        break;
      default:
        typeStr = 'distance';
    }

    final String statusStr;
    switch (status) {
      case ChallengeStatus.completed:
        statusStr = 'completed';
        break;
      case ChallengeStatus.failed:
        statusStr = 'failed';
        break;
      default:
        statusStr = 'active';
    }

    return {
      'type': typeStr,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'bonusPoints': bonusPoints,
      'status': statusStr,
      'participantCount': participantCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 기존 엔티티에서 ChallengeModel 생성 (상태 변경 등에 사용)
  factory ChallengeModel.fromEntity(ChallengeEntity entity) {
    return ChallengeModel(
      id: entity.id,
      type: entity.type,
      targetValue: entity.targetValue,
      currentValue: entity.currentValue,
      startDate: entity.startDate,
      endDate: entity.endDate,
      bonusPoints: entity.bonusPoints,
      status: entity.status,
      participantCount: entity.participantCount,
    );
  }
}
