import 'package:equatable/equatable.dart';

// 크루(길드) 데이터 객체
class CrewEntity extends Equatable {
  final String id;
  final String name;
  final String region;           // 대표 지역 (예: "서울시 강남구")
  final int crewPoints;          // 크루 누적 총 포인트
  final int monthlyPoints;       // 이번 달 크루 포인트 (멤버 포인트 합산)
  final List<String> memberIds;  // 멤버 userId 목록
  final String leaderId;         // 크루장 userId
  final String? description;
  final int maxMembers;          // 최대 인원

  const CrewEntity({
    required this.id,
    required this.name,
    required this.region,
    this.crewPoints = 0,
    this.monthlyPoints = 0,
    this.memberIds = const [],
    required this.leaderId,
    this.description,
    this.maxMembers = 20,
  });

  int get memberCount => memberIds.length;

  @override
  List<Object?> get props => [id, name, region, crewPoints, monthlyPoints];
}
