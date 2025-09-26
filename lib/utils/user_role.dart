// lib/utils/user_role.dart
enum UserRole { unknown, member, trainer }

String userRoleToString(UserRole r) {
  switch (r) {
    case UserRole.member:
      return 'member';
    case UserRole.trainer:
      return 'trainer';
    default:
      return 'unknown';
  }
}

UserRole userRoleFromString(String s) {
  switch (s) {
    case 'member':
      return UserRole.member;
    case 'trainer':
      return UserRole.trainer;
    default:
      return UserRole.unknown;
  }
}
