import '../../domain/entities/user_entity.dart';

// Firebase Firestore와 주고받는 데이터 모델
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.profileImageUrl,
    super.experience,
    super.points,
    super.level,
    super.totalDistance,
    super.crewId,
    super.streak,
    super.lastRunDate,
    super.homeRegionSi,
    super.homeRegionGu,
    super.homeRegionDong,
    super.emailVerified,
    super.appleHiddenEmail,
    super.marketingConsent,
    super.marketingConsentAt,
    super.nameNormalized,
    super.nameChangedAt,
  });

  // Firestore 문서에서 UserModel 생성
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    // lastRunDate: Firestore Timestamp 또는 ISO 문자열 모두 처리
    DateTime? lastRunDate;
    final rawDate = data['lastRunDate'];
    if (rawDate != null) {
      if (rawDate is String) {
        lastRunDate = DateTime.tryParse(rawDate);
      } else {
        // Firestore Timestamp → DateTime
        lastRunDate = (rawDate as dynamic).toDate() as DateTime?;
      }
    }

    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      experience: data['experience'] ?? 0,
      points: data['points'] ?? 0,
      level: data['level'] ?? 1,
      totalDistance: (data['totalDistance'] ?? 0.0).toDouble(),
      crewId: data['crewId'],
      streak: data['streak'] ?? 0,
      lastRunDate: lastRunDate,
      // 홈 지역 (Phase 4)
      homeRegionSi: data['homeRegionSi'] as String?,
      homeRegionGu: data['homeRegionGu'] as String?,
      homeRegionDong: data['homeRegionDong'] as String?,
      // 기존 사용자는 필드 부재 → false (미인증)로 취급하고 UI에서 재발송 유도
      emailVerified: data['emailVerified'] == true,
      appleHiddenEmail: data['appleHiddenEmail'] == true,
      marketingConsent: data['marketingConsent'] == true,
      marketingConsentAt: _parseDate(data['marketingConsentAt']),
      nameNormalized: data['nameNormalized'] as String?,
      nameChangedAt: _parseDate(data['nameChangedAt']),
    );
  }

  // Firestore 의 Timestamp / ISO 문자열 양쪽 모두 안전하게 파싱
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      return (raw as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  // UserModel을 Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'experience': experience,
      'points': points,
      'level': level,
      'totalDistance': totalDistance,
      'crewId': crewId,
      'streak': streak,
      'lastRunDate': lastRunDate?.toIso8601String(),
      // 홈 지역 (Phase 4)
      'homeRegionSi': homeRegionSi,
      'homeRegionGu': homeRegionGu,
      'homeRegionDong': homeRegionDong,
      // 이메일 인증 상태 (Phase 7: 정책 § 1)
      'emailVerified': emailVerified,
      // Apple Hide My Email 사용자 식별 (마케팅 발송 시 도달성 분기)
      'appleHiddenEmail': appleHiddenEmail,
      // 마케팅 수신 동의 (한국 정보통신망법 § 50 대비)
      'marketingConsent': marketingConsent,
      'marketingConsentAt': marketingConsentAt?.toIso8601String(),
      // 닉네임 중복 검사용 정규화 키
      'nameNormalized': nameNormalized,
      // 마지막 닉네임 변경 시각 (30일 1회 정책)
      'nameChangedAt': nameChangedAt?.toIso8601String(),
    };
  }
}
