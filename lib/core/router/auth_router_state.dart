import 'package:flutter/foundation.dart';
import '../../features/auth/domain/entities/user_entity.dart';

// GoRouter 의 refreshListenable/redirect 가 인증 상태 변화에 반응할 수 있도록
// 보관하는 글로벌 ValueNotifier.
//
// - Riverpod ProviderScope 내의 AuthNotifier 가 상태가 바뀔 때마다 이 notifier 의 value 를 갱신.
// - appRouter 는 이 notifier 를 구독해 redirect 재평가.
final authRouterStateNotifier = ValueNotifier<UserEntity?>(null);
