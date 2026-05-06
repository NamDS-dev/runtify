import 'package:equatable/equatable.dart';
import '../../../../core/services/level_calculator.dart';
import '../../../../core/services/level_title.dart';

// 앱 내에서 사용하는 순수 유저 데이터 객체
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final int experience;       // 경험치 - 레벨업 기준, 소비 불가
  final int points;           // 포인트 - 리워드 스토어에서 사용하는 재화
  final int level;            // 현재 레벨 (experience 기반 자동 계산)
  final double totalDistance; // 총 러닝 거리 (km)
  final String? crewId;       // 소속 크루 ID (없으면 null)
  final int streak;           // 연속 러닝 일수 (스트릭 보너스 계산용)
  final DateTime? lastRunDate; // 마지막 러닝 날짜 (스트릭 갱신 기준)

  // ── 홈 지역 (Phase 4: GPS 기반 지역 설정) ──────────────────────
  final String? homeRegionSi;   // 시·도 (예: "서울특별시")
  final String? homeRegionGu;   // 구·군 (예: "강남구")
  final String? homeRegionDong; // 동 (예: "역삼동")

  // ── 이메일 인증 상태 ──────────────────────────────────────────
  // 정책: [POLICY.md § 1] — 이메일 가입자는 false로 시작, OAuth 가입자는 true
  // 기존 사용자는 Firestore에 필드가 없어 fromFirestore에서 false 기본값 부여
  final bool emailVerified;

  // Apple "Hide My Email" 활성으로 가입한 경우 true
  // (@privaterelay.appleid.com 도메인). 마케팅 발송 시 도달성 안내 등에 사용
  final bool appleHiddenEmail;

  // [선택] 마케팅 정보 수신 동의 (한국 정보통신망법 § 50 대비)
  // - 가입 시 사용자가 명시적으로 체크해야 true. 언제든지 Profile에서 변경 가능
  // - 변경 시점은 marketingConsentAt 에 ISO-8601 문자열로 기록
  final bool marketingConsent;
  final DateTime? marketingConsentAt;

  // 닉네임 중복 검사용 정규화 키 — `NameValidator.normalize` + `.toLowerCase()`
  // 필드는 Firestore 단일 필드 인덱스 대상. 가입/닉네임 변경 시 함께 갱신.
  // 기존 사용자 문서에는 부재할 수 있어 nullable.
  final String? nameNormalized;

  // 마지막 닉네임 변경 시각 — 30일 1회 정책 (NicknameChangePolicy, 2026-05-06)
  // null = 한 번도 변경 안 함 (가입 직후 항상 변경 가능)
  final DateTime? nameChangedAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.experience = 0,
    this.points = 0,
    this.level = 1,
    this.totalDistance = 0.0,
    this.crewId,
    this.streak = 0,
    this.lastRunDate,
    this.homeRegionSi,
    this.homeRegionGu,
    this.homeRegionDong,
    this.emailVerified = false,
    this.appleHiddenEmail = false,
    this.marketingConsent = false,
    this.marketingConsentAt,
    this.nameNormalized,
    this.nameChangedAt,
  });

  // 다음 레벨업까지 필요한 경험치 (지수 공식 — 2026-05-06 전환)
  int get expForNextLevel => LevelCalculator.expRequiredForLevelUp(level);

  // 현재 레벨 내 진행도 (0.0 ~ 1.0)
  double get levelProgress =>
      LevelCalculator.progressToNextLevel(experience, level);

  // 다음 레벨까지 남은 경험치
  int get expToNextLevel {
    final into = LevelCalculator.expIntoCurrentLevel(experience, level);
    final required = LevelCalculator.expRequiredForLevelUp(level);
    final remaining = required - into;
    return remaining < 0 ? 0 : remaining;
  }

  // 레벨별 칭호 (가설 2 — 2026-05-06)
  String get levelTitle => LevelTitle.forLevel(level);

  // 스트릭 보너스 배율 (3일 연속 ×1.2, 7일 연속 ×1.5)
  double get streakMultiplier {
    if (streak >= 7) return 1.5;
    if (streak >= 3) return 1.2;
    return 1.0;
  }

  // 홈 지역 표시용 문자열 (예: "강남구 역삼동" / 미설정 시 null)
  String? get homeRegionLabel {
    if (homeRegionGu == null && homeRegionDong == null) return null;
    final parts = [homeRegionGu, homeRegionDong].where((s) => s != null && s.isNotEmpty).toList();
    return parts.join(' ');
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        experience,
        points,
        level,
        streak,
        homeRegionSi,
        homeRegionGu,
        homeRegionDong,
        emailVerified,
      ];
}
