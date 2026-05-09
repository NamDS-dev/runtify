import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/auth/data/models/user_model.dart';
import 'package:runtify/features/auth/domain/entities/user_entity.dart';

void main() {
  group('UserEntity.isPendingDeletion', () {
    test('deletedAt null → false', () {
      const user = UserEntity(id: 'u1', name: 'Run', email: 'a@b.c');
      expect(user.isPendingDeletion, false);
    });

    test('deletedAt 있으면 true', () {
      final user = UserEntity(
        id: 'u1',
        name: 'Run',
        email: 'a@b.c',
        deletedAt: DateTime(2026, 5, 9),
        scheduledHardDeleteAt: DateTime(2026, 6, 8),
      );
      expect(user.isPendingDeletion, true);
    });
  });

  group('UserModel — deletedAt/scheduledHardDeleteAt 직렬화', () {
    test('toFirestore → fromFirestore 라운드트립', () {
      final user = UserModel(
        id: 'u1',
        name: 'Runner',
        email: 'r@runtify.dev',
        deletedAt: DateTime.utc(2026, 5, 9, 12),
        scheduledHardDeleteAt: DateTime.utc(2026, 6, 8, 12),
      );
      final restored = UserModel.fromFirestore(user.toFirestore(), user.id);
      expect(restored.deletedAt, DateTime.utc(2026, 5, 9, 12));
      expect(restored.scheduledHardDeleteAt, DateTime.utc(2026, 6, 8, 12));
      expect(restored.isPendingDeletion, true);
    });

    test('필드 부재 시 null', () {
      final user = UserModel(id: 'u1', name: 'A', email: 'a@b.c');
      final restored = UserModel.fromFirestore(user.toFirestore(), user.id);
      expect(restored.deletedAt, null);
      expect(restored.scheduledHardDeleteAt, null);
      expect(restored.isPendingDeletion, false);
    });
  });
}
