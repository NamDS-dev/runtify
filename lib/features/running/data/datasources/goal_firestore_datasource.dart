import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_model.dart';

// 목표(Goals) Firestore 데이터소스 — users/{userId}/goals 서브컬렉션 관리
class GoalFirestoreDataSource {
  final FirebaseFirestore _firestore;

  GoalFirestoreDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  // 특정 유저의 goals 서브컬렉션 참조
  CollectionReference<Map<String, dynamic>> _goalsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('goals');

  // 목표 목록 실시간 스트림 — 현재 주/월 기준 필터링 없이 전체 반환
  Stream<List<GoalModel>> getGoals(String userId) {
    return _goalsRef(userId).snapshots().map((snapshot) => snapshot.docs
        .map((doc) => GoalModel.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  // 새 목표 추가 — period와 currentValue 포함
  Future<String> addGoal(String userId, GoalModel goal) async {
    final docRef = await _goalsRef(userId).add(goal.toFirestore());
    return docRef.id;
  }

  // 목표 삭제
  Future<void> deleteGoal(String userId, String goalId) async {
    await _goalsRef(userId).doc(goalId).delete();
  }

  // 목표 진행값(currentValue) 및 달성 여부(isCompleted) 업데이트
  Future<void> updateGoalProgress(
      String userId, String goalId, double currentValue, double targetValue) async {
    final isCompleted = currentValue >= targetValue;
    await _goalsRef(userId).doc(goalId).update({
      'currentValue': currentValue,
      'isCompleted': isCompleted,
    });
  }
}
