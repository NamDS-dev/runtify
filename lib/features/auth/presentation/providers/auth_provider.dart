import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/datasources/auth_firebase_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

// 데모 모드 OFF - Firebase 실제 연동
const bool kDemoMode = false;

// 의존성 주입 - DataSource (Firebase 실구현체 사용)
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthFirebaseDataSource(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

// 의존성 주입 - Repository
final authRepositoryProvider = Provider((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.read(authRemoteDataSourceProvider),
  );
});

// 의존성 주입 - UseCases
final signInUseCaseProvider = Provider((ref) {
  return SignInUseCase(ref.read(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider((ref) {
  return SignUpUseCase(ref.read(authRepositoryProvider));
});

// 현재 로그인된 유저 상태
class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRemoteDataSource _dataSource;
  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;

  AuthNotifier({
    required AuthRemoteDataSource dataSource,
    required SignInUseCase signInUseCase,
    required SignUpUseCase signUpUseCase,
  })  : _dataSource = dataSource,
        _signInUseCase = signInUseCase,
        _signUpUseCase = signUpUseCase,
        super(const AsyncValue.loading()) {
    _checkCurrentUser();
  }

  // 앱 시작 시 Firebase Auth 로그인 상태 확인
  Future<void> _checkCurrentUser() async {
    final user = await _dataSource.getCurrentUser();
    state = AsyncValue.data(user);
  }

  // 로그인
  Future<String?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final result = await _signInUseCase(
      SignInParams(email: email, password: password),
    );

    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        state = AsyncValue.data(user);
        return null; // null = 성공
      },
    );
  }

  // 회원가입
  Future<String?> signUp(String email, String password, String name) async {
    state = const AsyncValue.loading();
    final result = await _signUpUseCase(
      SignUpParams(email: email, password: password, name: name),
    );

    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (user) {
        state = AsyncValue.data(user);
        return null;
      },
    );
  }

  // Firestore에서 최신 유저 데이터로 갱신 (러닝 후 포인트/레벨 업데이트)
  Future<void> refreshUser() async {
    final user = await _dataSource.getCurrentUser();
    state = AsyncValue.data(user);
  }

  // Google 로그인
  Future<String?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _dataSource.signInWithGoogle();
      state = AsyncValue.data(user);
      return null; // null = 성공
    } catch (e) {
      state = const AsyncValue.data(null);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // Apple 로그인
  Future<String?> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _dataSource.signInWithApple();
      state = AsyncValue.data(user);
      return null; // null = 성공
    } catch (e) {
      state = const AsyncValue.data(null);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _dataSource.signOut();
    state = const AsyncValue.data(null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>(
  (ref) => AuthNotifier(
    dataSource: ref.read(authRemoteDataSourceProvider),
    signInUseCase: ref.read(signInUseCaseProvider),
    signUpUseCase: ref.read(signUpUseCaseProvider),
  ),
);

// ── Phase 4: 홈 지역 설정 ─────────────────────────────────────────

// 감지된 지역 데이터를 담는 레코드 타입
typedef DetectedRegion = ({String si, String gu, String dong});

// GPS → 역지오코딩으로 현재 지역만 감지 (저장하지 않음)
// 반환: (region, null) = 성공, (null, errorMsg) = 실패
final detectCurrentRegionProvider =
    Provider<Future<(DetectedRegion?, String?)> Function()>(
  (ref) {
    return () async {
      // 1. 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (null, '위치 서비스가 꺼져 있습니다. 설정에서 활성화해주세요.');
      }

      // 2. 위치 권한 확인 및 요청
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return (null, '위치 권한이 거부되었습니다.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return (null, '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.');
      }

      // 3. 현재 위치 좌표 가져오기
      final Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return (null, 'GPS 위치를 가져올 수 없습니다. 잠시 후 다시 시도해주세요.');
      }

      // 4. 역지오코딩 (좌표 → 주소)
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final si = p.administrativeArea ?? '';
          final gu = p.locality ?? '';
          final dong = p.subLocality ?? '';

          if (si.isEmpty && gu.isEmpty && dong.isEmpty) {
            return (null, '현재 위치의 주소를 가져올 수 없습니다.');
          }
          return ((si: si, gu: gu, dong: dong), null);
        }
        return (null, '현재 위치의 주소를 가져올 수 없습니다.');
      } catch (_) {
        return (null, '주소 변환에 실패했습니다. 잠시 후 다시 시도해주세요.');
      }
    };
  },
);

// 감지된 지역을 Firestore에 저장하는 Provider
final saveHomeRegionProvider =
    Provider<Future<void> Function(String userId, DetectedRegion region)>(
  (ref) {
    return (userId, region) async {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'homeRegionSi': region.si,
        'homeRegionGu': region.gu,
        'homeRegionDong': region.dong,
      });
      // 로컬 상태 갱신
      ref.read(authProvider.notifier).refreshUser();
    };
  },
);

// 하위 호환성 유지 — 기존 코드에서 참조하는 경우 대비
final updateHomeRegionProvider = Provider<Future<String?> Function(String userId)>(
  (ref) {
    return (userId) async {
      final detect = ref.read(detectCurrentRegionProvider);
      final (region, error) = await detect();
      if (error != null) return error;

      final save = ref.read(saveHomeRegionProvider);
      await save(userId, region!);
      return null;
    };
  },
);
