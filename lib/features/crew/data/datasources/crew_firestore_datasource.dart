import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/challenge_entity.dart';
import '../../domain/entities/crew_entity.dart';
import '../models/challenge_model.dart';

// 크루 멤버 표시용 간단 데이터 (이름 + 포인트)
class CrewMemberInfo {
  final String id;
  final String name;
  final int points;

  const CrewMemberInfo({
    required this.id,
    required this.name,
    required this.points,
  });
}

// Firestore에서 크루 데이터를 읽고 쓰는 데이터소스
class CrewFirestoreDataSource {
  final FirebaseFirestore _firestore;

  CrewFirestoreDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _crewsRef =>
      _firestore.collection('crews');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  // Firestore 문서 → CrewEntity 변환
  CrewEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CrewEntity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      region: data['region'] as String? ?? '',
      crewPoints: (data['crewPoints'] as num?)?.toInt() ?? 0,
      monthlyPoints: (data['monthlyPoints'] as num?)?.toInt() ?? 0,
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      leaderId: data['leaderId'] as String? ?? '',
      description: data['description'] as String?,
      maxMembers: (data['maxMembers'] as num?)?.toInt() ?? 20,
    );
  }

  // ── 전체 크루 목록 조회 (포인트 내림차순) ────────────────────────────────
  Future<List<CrewEntity>> getCrews() async {
    final snapshot = await _crewsRef
        .orderBy('crewPoints', descending: true)
        .get();

    return snapshot.docs.map(_fromDoc).toList();
  }

  // ── 크루 단건 조회 ────────────────────────────────────────────────────────
  Future<CrewEntity?> getCrewById(String crewId) async {
    final doc = await _crewsRef.doc(crewId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  // ── 크루 멤버 정보 조회 (이름 + 포인트) ──────────────────────────────────
  // 크루 상세 화면에서 멤버 목록 표시 시 사용
  Future<List<CrewMemberInfo>> getCrewMembersInfo(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    // Firestore 'in' 쿼리는 최대 10개 제한 → 청크로 나눠서 조회
    final chunks = <List<String>>[];
    for (var i = 0; i < memberIds.length; i += 10) {
      chunks.add(memberIds.sublist(i, i + 10 > memberIds.length ? memberIds.length : i + 10));
    }

    final members = <CrewMemberInfo>[];
    for (final chunk in chunks) {
      final snapshot = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        members.add(CrewMemberInfo(
          id: doc.id,
          name: data['name'] as String? ?? '알 수 없음',
          points: (data['points'] as num?)?.toInt() ?? 0,
        ));
      }
    }

    // memberIds 순서 기준으로 포인트 내림차순 정렬
    members.sort((a, b) => b.points.compareTo(a.points));
    return members;
  }

  // ── 크루명 중복 체크 ───────────────────────────────────────────────────────
  Future<bool> isCrewNameTaken(String name) async {
    final snapshot = await _crewsRef
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ── 크루 생성 ─────────────────────────────────────────────────────────────
  // 생성자가 자동으로 첫 번째 멤버이자 리더가 됨
  Future<CrewEntity> createCrew({
    required String name,
    required String region,
    required String description,
    required int maxMembers,
    required String leaderId,
  }) async {
    return _firestore.runTransaction((transaction) async {
      // 크루 문서 생성
      final crewRef = _crewsRef.doc();
      final userRef = _usersRef.doc(leaderId);

      final crewData = {
        'name': name,
        'region': region,
        'description': description,
        'maxMembers': maxMembers,
        'leaderId': leaderId,
        'memberIds': [leaderId], // 생성자가 첫 멤버
        'crewPoints': 0,
        'monthlyPoints': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(crewRef, crewData);

      // 유저의 crewId 업데이트
      transaction.update(userRef, {'crewId': crewRef.id});

      return CrewEntity(
        id: crewRef.id,
        name: name,
        region: region,
        description: description,
        maxMembers: maxMembers,
        leaderId: leaderId,
        memberIds: [leaderId],
        crewPoints: 0,
        monthlyPoints: 0,
      );
    });
  }

  // ── 크루 가입 ─────────────────────────────────────────────────────────────
  // 1인 1크루 제한: 유저의 crewId 필드와 memberIds 양쪽 모두 트랜잭션 내에서 검증
  Future<void> joinCrew({
    required String crewId,
    required String userId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final crewRef = _crewsRef.doc(crewId);
      final userRef = _usersRef.doc(userId);

      // 크루 문서와 유저 문서 동시 조회 (트랜잭션 내)
      final crewDoc = await transaction.get(crewRef);
      final userDoc = await transaction.get(userRef);

      if (!crewDoc.exists) throw Exception('크루를 찾을 수 없습니다');

      // 유저가 이미 다른 크루에 가입 중인지 확인 (1인 1크루 제한)
      final existingCrewId = userDoc.data()?['crewId'] as String?;
      if (existingCrewId != null && existingCrewId.isNotEmpty && existingCrewId != crewId) {
        throw Exception('이미 다른 크루에 가입되어 있습니다. 먼저 탈퇴해주세요.');
      }

      final memberIds = List<String>.from(
        crewDoc.data()!['memberIds'] as List? ?? [],
      );
      final maxMembers = (crewDoc.data()!['maxMembers'] as num?)?.toInt() ?? 20;

      if (memberIds.contains(userId)) throw Exception('이미 가입된 크루입니다');
      if (memberIds.length >= maxMembers) throw Exception('크루 인원이 가득 찼습니다');

      // 멤버 추가 + 유저 crewId 업데이트
      transaction.update(crewRef, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });
      transaction.update(userRef, {'crewId': crewId});
    });
  }

  // ── 크루 탈퇴 (리더 탈퇴 방지 — Firestore 레벨 검증) ─────────────────────
  Future<void> leaveCrew({
    required String crewId,
    required String userId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final crewRef = _crewsRef.doc(crewId);
      final userRef = _usersRef.doc(userId);

      // 리더 검증: 크루장은 탈퇴 불가
      final crewDoc = await transaction.get(crewRef);
      final leaderId = crewDoc.data()?['leaderId'] as String?;
      if (leaderId == userId) {
        throw Exception('크루장은 탈퇴할 수 없습니다. 크루를 해산하거나 리더를 위임해주세요.');
      }

      // 멤버 제거 + 유저 crewId 초기화
      transaction.update(crewRef, {
        'memberIds': FieldValue.arrayRemove([userId]),
      });
      transaction.update(userRef, {'crewId': FieldValue.delete()});
    });
  }

  // ── 크루 정보 수정 (리더 전용) ──────────────────────────────────────────
  Future<void> updateCrew({
    required String crewId,
    required String name,
    required String region,
    required String description,
    required int maxMembers,
  }) async {
    await _crewsRef.doc(crewId).update({
      'name': name,
      'region': region,
      'description': description,
      'maxMembers': maxMembers,
    });
  }

  // ── 멤버 강제 퇴출 (리더 전용) ──────────────────────────────────────────
  Future<void> kickMember({
    required String crewId,
    required String memberId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final crewRef = _crewsRef.doc(crewId);
      final userRef = _usersRef.doc(memberId);

      transaction.update(crewRef, {
        'memberIds': FieldValue.arrayRemove([memberId]),
      });
      transaction.update(userRef, {'crewId': FieldValue.delete()});
    });
  }

  // ── 챌린지 서브컬렉션 참조 헬퍼 ──────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _challengesRef(String crewId) =>
      _crewsRef.doc(crewId).collection('challenges');

  // ── 챌린지 목록 실시간 조회 (Stream) ─────────────────────────────────────
  // crews/{crewId}/challenges 서브컬렉션 구독
  Stream<List<ChallengeEntity>> getChallenges(String crewId) {
    return _challengesRef(crewId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ── 챌린지 생성 (크루장만 가능) ──────────────────────────────────────────
  Future<void> createChallenge(
    String crewId,
    ChallengeModel challenge,
  ) async {
    await _challengesRef(crewId).add(challenge.toFirestore());
  }

  // ── 챌린지 진행률 업데이트 ────────────────────────────────────────────────
  // 러닝 세션 저장 시 호출됨 (트랜잭션 외부에서 별도 업데이트)
  Future<void> updateChallengeProgress({
    required String crewId,
    required String challengeId,
    required double currentValue,
    required int participantCount,
  }) async {
    await _challengesRef(crewId).doc(challengeId).update({
      'currentValue': currentValue,
      'participantCount': participantCount,
    });
  }

  // ── 만료된 active 챌린지 처리 ─────────────────────────────────────────────
  // endDate가 지났으나 아직 active 상태인 챌린지를 completed/failed로 변경
  // 달성 조건: currentValue >= targetValue → completed, 미달 → failed
  Future<void> completeChallenges(String crewId) async {
    final now = DateTime.now();
    final snapshot = await _challengesRef(crewId)
        .where('status', isEqualTo: 'active')
        .get();

    // 배치 쓰기로 여러 챌린지 상태를 한 번에 업데이트
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final challenge = ChallengeModel.fromFirestore(doc.data(), doc.id);

      // 종료일이 지난 챌린지만 처리
      if (now.isAfter(challenge.endDate)) {
        final isAchieved = challenge.currentValue >= challenge.targetValue;
        batch.update(doc.reference, {
          'status': isAchieved ? 'completed' : 'failed',
        });
      }
    }
    await batch.commit();
  }

  // ── 챌린지 달성 시 크루원 전원 보너스 포인트 지급 ────────────────────────
  // completed 상태 변경 + users 컬렉션 일괄 업데이트
  Future<void> distributeChallengeBonus({
    required String crewId,
    required String challengeId,
    required int bonusPoints,
    required List<String> memberIds,
  }) async {
    final batch = _firestore.batch();

    // 챌린지 상태를 completed로 변경
    batch.update(
      _challengesRef(crewId).doc(challengeId),
      {'status': 'completed'},
    );

    // 크루원 전원에게 보너스 포인트 지급
    for (final memberId in memberIds) {
      batch.update(_usersRef.doc(memberId), {
        'points': FieldValue.increment(bonusPoints),
      });
    }

    await batch.commit();
  }
}
